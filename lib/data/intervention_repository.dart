import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/profile.dart';
import '../models/timeline.dart';
import 'conversation_repository.dart';
import 'hermes_adapter.dart';

/// État persisté d'une réponse (`intervention_answers.state`).
enum AnswerState { sending, sent, confirmed, unknown, closed }

/// Seul auteur de `intervention_answers` : la réponse à une question de
/// Hermes ou la décision sur une autorisation (`{"choice": …}`) est
/// enregistrée avant la trame, puis envoyée une seule fois. Une issue
/// incertaine reste `unknown` ; rien n'est jamais renvoyé automatiquement.
/// Ne ferme pas la base partagée.
class InterventionRepository implements InterventionGateway, QuestionLedger {
  InterventionRepository(
    this.database, {
    required this.gateway,
    required this.conversation,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc()) {
    conversation.questions = this;
    _recovered = _recover();
  }
  final Database database;
  final ConnectionGateway gateway;
  final ConversationRepository conversation;
  final DateTime Function() _now;
  final _inFlight = <String>{};
  late final Future<void> _recovered;

  /// Aucun texte de question, de réponse ni de commande dans les journaux.
  static void _log(String code) =>
      developer.log(code, name: 'hermes.intervention');

  /// Relance de l'app : un envoi interrompu (`sending`) devient `unknown`,
  /// jamais renvoyé.
  Future<void> _recover() async {
    try {
      final rows = await database.query(
        'intervention_answers',
        where: 'state = ?',
        whereArgs: [AnswerState.sending.name],
      );
      if (rows.isEmpty) return;
      await database.update(
        'intervention_answers',
        {'state': AnswerState.unknown.name},
        where: 'state = ?',
        whereArgs: [AnswerState.sending.name],
      );
      for (final row in rows) {
        await conversation.markQuestion(
          _key(row),
          row['request_id'] as String,
          QuestionState.unknown,
        );
      }
    } catch (_) {
      _log('intervention.recover_failed');
    }
  }

  /// Fin de la reprise des envois interrompus (tests).
  Future<void> get recovered => _recovered;

  static TimelineKey _key(Map<String, Object?> row) => TimelineKey(
    ConnectionKey(row['connection_key'] as String),
    ProfileKey(row['profile_key'] as String),
    row['stored_session_id'] as String,
  );

  /// État enregistré pour [requestId], `null` sans réponse locale.
  Future<AnswerState?> state(String requestId) async {
    final rows = await database.query(
      'intervention_answers',
      columns: ['state'],
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
    return rows.isEmpty
        ? null
        : AnswerState.values.asNameMap()[rows.single['state']];
  }

  @override
  Future<void> answer(
    TimelineKey key,
    String requestId,
    Map<String, String> answers,
  ) => _guarded(requestId, () async {
    final item = _open<QuestionItem>(key, requestId, 'question.closed');
    final cleaned = {
      for (final q in item.questions)
        if (answers[q.qid]?.trim().isNotEmpty == true)
          q.qid: answers[q.qid]!.trim(),
    };
    if (cleaned.length != item.questions.length) {
      throw const AppError('question.empty');
    }
    await _send(
      key,
      requestId,
      stored: cleaned,
      result: HermesRpc.clarifyAnswer(cleaned),
    );
  });

  @override
  Future<void> decide(TimelineKey key, String requestId, String choice) =>
      _guarded(requestId, () async {
        _open<ApprovalItem>(key, requestId, 'approval.closed');
        // Seuls « Autoriser » (once) et « Refuser » (deny) partent.
        if (!ApprovalChoice.offered.contains(choice)) {
          throw const AppError('approval.choice');
        }
        await _send(
          key,
          requestId,
          stored: {'choice': choice},
          result: HermesRpc.approvalAnswer(choice),
          choice: choice,
        );
      });

  /// Garde synchrone : un double appui n'écrit et n'envoie qu'une fois.
  Future<void> _guarded(String requestId, Future<void> Function() body) async {
    await _recovered;
    if (!_inFlight.add(requestId)) return;
    try {
      await body();
    } on AppError {
      rethrow;
    } on DatabaseException {
      throw const AppError('storage.unavailable');
    } finally {
      _inFlight.remove(requestId);
    }
  }

  /// Seule une carte ouverte (ou rouverte par le serveur) accepte une
  /// réponse, saisie à la main.
  T _open<T extends InterventionItem>(
    TimelineKey key,
    String requestId,
    String closed,
  ) {
    final item = conversation
        .projection(key)
        .items
        .whereType<T>()
        .where((i) => i.requestId == requestId)
        .firstOrNull;
    if (item == null || item.state != QuestionState.open) {
      throw AppError(closed);
    }
    return item;
  }

  /// Ligne `sending` en base, trame unique, puis `sent` ou `unknown`. Si rien
  /// n'est parti (`transport.offline`), la ligne est retirée et la carte
  /// rouverte.
  Future<void> _send(
    TimelineKey key,
    String requestId, {
    required Map<String, Object?> stored,
    required Map<String, dynamic> result,
    String? choice,
  }) async {
    if (gateway.snapshot.link != LinkState.connected ||
        gateway.snapshot.connection?.key != key.connection) {
      throw const AppError('transport.offline', retryable: true);
    }
    // Enregistrée avant la trame ; une réponse rouverte remplace l'ancienne.
    await database.insert('intervention_answers', {
      'request_id': requestId,
      'connection_key': key.connection.value,
      'profile_key': key.profile.value,
      'stored_session_id': key.session,
      'answers': jsonEncode(stored),
      'state': AnswerState.sending.name,
      'created_at': _now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await conversation.markQuestion(
      key,
      requestId,
      QuestionState.sending,
      choice: choice,
    );
    AnswerState outcome;
    try {
      gateway.respond(requestId, result: result);
      outcome = AnswerState.sent;
    } on AppError catch (error) {
      if (error.code != 'transport.offline') {
        // Trame peut-être partie : issue inconnue, jamais renvoyée.
        outcome = AnswerState.unknown;
        _log('intervention.answer_unknown');
      } else {
        // Rien n'est parti : la carte reste ouverte, sans trace locale.
        await database.delete(
          'intervention_answers',
          where: 'request_id = ? AND state = ?',
          whereArgs: [requestId, AnswerState.sending.name],
        );
        await conversation.markQuestion(key, requestId, QuestionState.open);
        rethrow;
      }
    } catch (_) {
      // Trame peut-être partie : issue inconnue, jamais renvoyée.
      outcome = AnswerState.unknown;
      _log('intervention.answer_unknown');
    }
    await _write(requestId, outcome, from: AnswerState.sending);
    await conversation.markQuestion(
      key,
      requestId,
      outcome == AnswerState.sent ? QuestionState.sent : QuestionState.unknown,
    );
  }

  Future<void> _write(
    String requestId,
    AnswerState state, {
    AnswerState? from,
  }) async {
    try {
      await database.update(
        'intervention_answers',
        {'state': state.name},
        where: from == null ? 'request_id = ?' : 'request_id = ? AND state = ?',
        whereArgs: [requestId, ?from?.name],
      );
    } catch (_) {
      _log('intervention.write_failed');
    }
  }

  @override
  Future<Set<String>> answered(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const {};
    final rows = await database.query(
      'intervention_answers',
      columns: ['request_id'],
      where: 'request_id IN (${List.filled(list.length, '?').join(', ')})',
      whereArgs: list,
    );
    return {for (final r in rows) r['request_id'] as String};
  }

  @override
  Future<void> settle(String requestId, QuestionState state) => _write(
    requestId,
    state == QuestionState.confirmed
        ? AnswerState.confirmed
        : AnswerState.closed,
  );
}

/// Mode d'autorisation d'un profil sur Hermes : `config.set` puis relecture
/// par `config.get`, toujours avec `profile`. Aucun mode n'est écrit sans
/// demande, ni gardé localement.
class HermesApprovalModes implements ApprovalModes {
  HermesApprovalModes(this.gateway);
  final ConnectionGateway gateway;

  @override
  Future<String> read(ProfileKey profile) async {
    final value = HermesRpc.configValue(
      await gateway.call(
        HermesRpc.configGet,
        HermesRpc.approvalModeGet(profile.value),
      ),
    );
    if (value == null || !ApprovalMode.values.contains(value)) {
      throw const AppError('approval_mode.unreadable');
    }
    return value;
  }

  @override
  Future<String> write(ProfileKey profile, String mode) async {
    if (!ApprovalMode.values.contains(mode)) {
      throw const AppError('approval_mode.invalid');
    }
    await gateway.call(
      HermesRpc.configSet,
      HermesRpc.approvalModeSet(profile.value, mode),
    );
    return read(profile);
  }
}
