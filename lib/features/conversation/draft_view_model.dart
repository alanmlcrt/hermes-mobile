import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/attachment.dart';
import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/draft.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/content.dart';

class DraftViewModel extends ChangeNotifier {
  DraftViewModel({
    required this.outbox,
    required this.gateway,
    required this.conversation,
    required this.key,
    this.picker,
  }) {
    _subscription = gateway.snapshots.listen((_) => _notify());
    _outboxChanges = outbox.changes.listen(_onOutbox);
    _timelineChanges = conversation.changes.listen((changed) {
      if (changed == _timelineKey) _notify();
    });
    unawaited(_load());
  }
  final OutboxGateway outbox;
  final ConnectionGateway gateway;
  final ConversationGateway conversation;
  final DraftKey key;
  final AttachmentPicker? picker;
  List<Attachment> attachments = const [];
  List<AttachmentLimit> attachmentLimits = const [];
  bool attachmentBusy = false;
  String? attachmentError;

  Future<void> loadAttachmentLimits() async {
    try {
      attachmentLimits = await outbox.attachmentLimits();
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  Future<void> pickAttachments(AttachmentSource source) async {
    if (attachmentBusy || picker == null || sendStatus.busy) return;
    attachmentBusy = true;
    attachmentError = null;
    _notify();
    try {
      final picked = await picker!.pick(source);
      for (final file in picked) {
        try {
          await outbox.addAttachment(key, file);
        } on AppError catch (e) {
          final limit = attachmentLimits
              .where(
                (l) =>
                    l.mediaTypes.contains(file.mediaType) ||
                    file.mediaType == 'image/jpeg' &&
                        l.category == AttachmentCategory.image,
              )
              .firstOrNull;
          attachmentError = e.code == 'attachment.type'
              ? Content.attachmentTypeRefused(file.mediaType)
              : e.code == 'attachment.size' && limit != null
              ? Content.attachmentSizeRefused(limit.maxBytes)
              : Content.error(e.code);
        }
      }
    } on AppError catch (e) {
      attachmentError = Content.error(e.code);
    } catch (_) {
      attachmentError = Content.error('attachment.selection');
    } finally {
      try {
        attachments = await outbox.attachments(key);
      } catch (_) {
        error = const AppError('storage.unavailable');
      }
      attachmentBusy = false;
      _notify();
    }
  }

  Future<void> removeAttachment(Attachment attachment) async {
    if (attachmentBusy || sendStatus.busy) return;
    attachmentBusy = true;
    attachmentError = null;
    _notify();
    try {
      await outbox.removeAttachment(key, attachment.key);
      attachments = await outbox.attachments(key);
    } on AppError catch (e) {
      attachmentError = Content.error(e.code);
    } catch (_) {
      attachmentError = Content.error('storage.unavailable');
    } finally {
      attachmentBusy = false;
      _notify();
    }
  }

  late final StreamSubscription<ConnectionSnapshot> _subscription;
  late final StreamSubscription<DraftKey> _outboxChanges;
  late final StreamSubscription<TimelineKey> _timelineChanges;
  String _text = '';
  String? _sentText;

  /// Incrémenté quand la saisie envoyée doit être retirée de l'écran.
  int clearTick = 0;
  Draft? draft;
  AppError? error;
  bool _disposed = false;

  Profile? get profile => gateway.snapshot.profiles
      .where((p) => p.key == draft?.profile)
      .firstOrNull;

  /// Brouillon neuf : le profil peut encore changer ; sinon lecture seule.
  bool get canChooseProfile => draft != null && draft!.storedSessionId == null;

  bool _selecting = false;

  /// Rattache le brouillon au profil choisi, puis seulement l'enregistre
  /// comme choix local ; sans déplacement effectif, l'erreur est affichée.
  Future<void> selectProfile(ProfileKey profile) async {
    if (!canChooseProfile || sendStatus.busy || _selecting) return;
    _selecting = true;
    try {
      await outbox.reassignNewDraft(key, profile);
      draft = await outbox.draft(key) ?? draft;
      if (draft?.profile != profile) {
        throw const AppError('storage.unavailable');
      }
      error = null;
      _notify();
      await gateway.selectProfile(profile);
    } on AppError catch (e) {
      error = e;
    } catch (_) {
      error = const AppError('storage.unavailable');
    } finally {
      _selecting = false;
    }
    _notify();
  }

  Future<void> _load() async {
    try {
      draft = await outbox.draft(key);
      attachments = await outbox.attachments(key);
      _text = draft?.body ?? '';
      if (draft == null) error = const AppError('draft.not_found');
      await _loadTimeline();
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  /// Chaque modification est écrite ; en cas d'échec le texte reste à l'écran.
  Future<void> update(String body) async {
    final wasEmpty = _text.trim().isEmpty;
    _text = body;
    if (wasEmpty != body.trim().isEmpty) _notify();
    try {
      await outbox.saveText(key, body);
      if (error == null) return;
      error = null;
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  SendStatus get sendStatus => outbox.status(key);
  StopStatus? get stopStatus =>
      outbox is StopGateway ? (outbox as StopGateway).stopStatus(key) : null;
  bool get showStop =>
      outbox is StopGateway && timeline.workState == WorkState.running;
  bool get canStop =>
      showStop &&
      !resyncing &&
      !resumeFailed &&
      gateway.snapshot.link == LinkState.connected &&
      outbox is StopGateway &&
      (outbox as StopGateway).canStop(key);
  Future<void> stop() async {
    if (canStop) await (outbox as StopGateway).stop(key);
  }

  String? get stopText {
    // Le terminal courant prévaut toujours sur une intention locale.
    if (timeline.workState == WorkState.stopped) return Content.workStopped;
    if (timeline.workState == WorkState.failed ||
        timeline.workState == WorkState.succeeded) {
      return null;
    }
    final status = stopStatus;
    if (status == null) return null;
    return switch (status.state) {
      StopState.preparing => Content.stopPreparing,
      StopState.requested => Content.stopRequested,
      StopState.unknown => Content.stopUnknown,
      StopState.failed ||
      StopState.stale => Content.error(status.errorCode ?? 'stop.unknown'),
    };
  }

  /// Raison pour laquelle « Envoyer » est désactivé, ou null s'il est actif.
  String? get blockedReason {
    if (attachments.isNotEmpty) return Content.attachmentSendBlocked;
    if (attachmentBusy) return Content.attachmentLoading;
    final snapshot = gateway.snapshot;
    final status = sendStatus;
    if (status.busy) return Content.sending;
    if (status.turnActive) return Content.turnActive;
    if (snapshot.link != LinkState.connected) {
      return Content.sendLink(switch (snapshot.link) {
        LinkState.resyncing => ConnectionLabels.resyncing,
        _ => ConnectionLabels.offline,
      });
    }
    final conversation = snapshot.capabilities
        .where((c) => c.name == 'conversation')
        .firstOrNull;
    if (conversation?.state == CapabilityState.absent) {
      return Content.sendCapabilityMissing;
    }
    if (conversation?.state != CapabilityState.present) {
      return Content.sendCapabilityPending;
    }
    if (_text.trim().isEmpty) return Content.sendEmpty;
    return null;
  }

  /// Texte d'état annoncé par la région live ; null si rien à signaler.
  String? get statusText {
    final status = sendStatus;
    if (status.busy) return Content.sending;
    if (status.turnActive) return Content.turnActive;
    return switch (status.state) {
      OperationState.accepted => Content.sendAccepted,
      OperationState.unknown || OperationState.failed => Content.error(
        status.errorCode ?? 'send.unavailable',
      ),
      _ => null,
    };
  }

  Future<void> send() {
    if (attachments.isNotEmpty || attachmentBusy) {
      attachmentError = Content.attachmentSendBlocked;
      _notify();
      return Future<void>.value();
    }
    _sentText = _text;
    return outbox.send(key);
  }

  /// Fil de la session du brouillon, une fois la session créée.
  TimelineKey? get _timelineKey {
    final d = draft;
    final session = d?.storedSessionId;
    return d == null || session == null
        ? null
        : TimelineKey(d.connection, d.profile, session);
  }

  TimelineProjection get timeline {
    final k = _timelineKey;
    return k == null ? const TimelineProjection() : conversation.projection(k);
  }

  CompanionPhase get companionPhase => resyncing || resumeFailed
      ? CompanionPhase.neutral
      : timeline.companionPhase;

  /// Le fil est en cours de resynchronisation (distinct de l'état du travail).
  bool get resyncing {
    final k = _timelineKey;
    return k != null && conversation.resyncing(k);
  }

  /// La reprise a échoué : le fil affiché peut être ancien, le brouillon reste.
  bool get resumeFailed {
    final k = _timelineKey;
    return k != null &&
        !conversation.resyncing(k) &&
        conversation.resumeFailed(k);
  }

  Future<void> _loadTimeline() async {
    final k = _timelineKey;
    if (k == null) return;
    try {
      await conversation.load(k);
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
  }

  Future<void> _onOutbox(DraftKey changed) async {
    if (changed != key) return;
    try {
      attachments = await outbox.attachments(key);
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    if (draft != null && draft!.storedSessionId == null) {
      try {
        final fresh = await outbox.draft(key);
        final created = fresh?.storedSessionId != null;
        draft = fresh ?? draft;
        if (created) await _loadTimeline();
      } catch (_) {
        error = const AppError('storage.unavailable');
      }
    }
    if (sendStatus.state == OperationState.accepted && _sentText != null) {
      final sent = _sentText;
      _sentText = null;
      try {
        final fresh = await outbox.draft(key);
        // Brouillon vidé côté stockage et aucune frappe depuis : on efface.
        if (fresh != null && fresh.body.isEmpty && _text == sent) {
          _text = '';
          clearTick++;
        }
        draft = fresh ?? draft;
      } catch (_) {
        error = const AppError('storage.unavailable');
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(_outboxChanges.cancel());
    unawaited(_timelineChanges.cancel());
    super.dispose();
  }
}
