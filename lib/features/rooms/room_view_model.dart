import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/room.dart';
import '../../models/timeline.dart';

class RoomViewModel extends ChangeNotifier {
  RoomViewModel(this.rooms, this.outbox, this.key, {this.interventions});
  final RoomInterventions? interventions;
  final decisions = <String, RoomDecision>{};
  final _knownApprovals = <String, RoomApproval>{};
  Iterable<RoomApproval> get approvals => _knownApprovals.values;
  final RoomGateway rooms;
  final RoomOutbox outbox;
  final RoomKey key;
  RoomSnapshot? snapshot;
  Set<RoomFeature> available = const {};
  List<RoomSend> sends = const [];
  String text = '';
  String? error;
  bool busy = false;
  String? stopState;
  bool loading = false;
  bool _disposed = false;
  bool _foreground = true;
  Timer? _timer;
  Future<void> _writes = Future.value();
  bool get canSend =>
      !busy &&
      text.trim().isNotEmpty &&
      available.contains(RoomFeature.send) &&
      !sends.any((s) => s.state == 'unknown' || s.state == 'sending');
  List<RoomMention> get mentions =>
      snapshot == null ? const [] : rooms.mentions(snapshot!.room);
  String displayText(RoomEntry entry) => snapshot == null
      ? entry.text
      : rooms.displayText(snapshot!.room, entry.text);

  Future<void> open() async {
    try {
      text = await outbox.roomText(key);
      sends = await outbox.roomSends(key);
      snapshot = await rooms.cached(key);
    } catch (_) {
      error = 'storage.unavailable';
    }
    await refresh();
  }

  void foreground(bool value) {
    _foreground = value;
    _timer?.cancel();
    if (value) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (loading || _disposed) return;
    loading = true;
    _timer?.cancel();
    _notify();
    try {
      final caps = await rooms.capabilities(key.connection, key.profile);
      if (!caps.driver) throw const AppError('room.driver_missing');
      final result = await rooms.load(key);
      await rooms.markSeen(
        key,
        result.latestSeq,
        approvals: {for (final a in result.approvals) a.commandKey},
      );
      for (final a in result.approvals) {
        _knownApprovals[a.commandKey] = a;
      }
      for (final a in approvals) {
        var decision =
            await interventions?.roomDecision(key, a) ??
            (state: QuestionState.open, blocked: null);
        if (decision.state == QuestionState.open &&
            !result.approvals.any(a.sameRequest)) {
          decision = (state: QuestionState.closed, blocked: null);
        }
        decisions[a.commandKey] = decision;
      }
      await outbox.reconcileRoom(key, {
        for (final e in result.entries)
          if (e.fromUser) e.id,
      });
      final operations = await outbox.roomSends(key);
      final stopped = await rooms.commandState(key, 'stop');
      if (_disposed) return;
      available = caps.available;
      snapshot = result;
      stopState = stopped == 'unknown'
          ? 'unknown'
          : stopped == 'confirmed'
          ? 'requested'
          : stopped == 'settled' && !result.working
          ? 'confirmed'
          : null;
      sends = operations;
      error = null;
    } catch (e) {
      error = e is AppError ? e.code : 'room.failed';
    } finally {
      loading = false;
      _notify();
      if (!_disposed && _foreground && !roomUnavailable(error)) {
        _timer = Timer(roomPollInterval, refresh);
      }
    }
  }

  void edit(String value) {
    text = value;
    _writes = _writes.then((_) => outbox.saveRoomText(key, value)).catchError((
      Object _,
    ) {
      error = 'storage.unavailable';
      _notify();
    });
    _notify();
  }

  Future<void> decide(RoomApproval approval, String choice) async {
    if (busy ||
        interventions == null ||
        !available.contains(RoomFeature.approve)) {
      return;
    }
    busy = true;
    decisions[approval.commandKey] = (
      state: QuestionState.sending,
      blocked: null,
    );
    _notify();
    try {
      await interventions!.approveRoom(key, approval, choice);
      decisions[approval.commandKey] = await interventions!.roomDecision(
        key,
        approval,
      );
      await refresh();
    } catch (e) {
      error = e is AppError ? e.code : 'room.failed';
      decisions[approval.commandKey] = error == 'room.stale'
          ? (state: QuestionState.closed, blocked: null)
          : await interventions!.roomDecision(key, approval);
      if (error == 'room.missing') {
        available = {...available}..remove(RoomFeature.approve);
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> stop() async {
    if (busy || !available.contains(RoomFeature.stop)) return;
    busy = true;
    stopState = 'requested';
    _notify();
    try {
      await rooms.stop(key);
      await refresh();
    } catch (e) {
      error = e is AppError ? e.code : 'room.failed';
      stopState = error == 'rpc.uncertain' ? 'unknown' : null;
      if (error == 'room.missing') {
        available = {...available}..remove(RoomFeature.stop);
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> taskAction(RoomTask task, {required bool discard}) async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      discard ? await rooms.discard(key, task) : await rooms.retry(key, task);
      await refresh();
    } catch (e) {
      error = e is AppError ? e.code : 'room.failed';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> send() async {
    if (!canSend) return;
    busy = true;
    final sending = text;
    _notify();
    try {
      await _writes;
      await outbox.sendRoom(key, sending);
      if (text == sending) text = '';
      await refresh();
    } catch (e) {
      error = e is AppError ? e.code : 'room.failed';
      sends = await outbox.roomSends(key);
      if (error == 'room.missing') {
        available = {...available}..remove(RoomFeature.send);
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
