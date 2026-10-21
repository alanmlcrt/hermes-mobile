import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/draft.dart';
import '../models/profile.dart';

/// Seul auteur des brouillons (`outbox_*`). Ne ferme pas la base partagée.
class OutboxRepository implements OutboxGateway {
  OutboxRepository(this.database, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());
  final Database database;
  final DateTime Function() _now;
  final _writes = <DraftKey, Future<void>>{};

  @override
  Future<Draft> openNewDraft(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    // L'index unique départage deux ouvertures concurrentes.
    await database.insert('outbox_drafts', {
      'draft_key': DraftKey.create().value,
      'connection_key': connection.value,
      'profile_key': profile.value,
      'body': '',
      'updated_at': _now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await database.query(
      'outbox_drafts',
      where: 'connection_key = ? AND profile_key = ?',
      whereArgs: [connection.value, profile.value],
    );
    return _draft(rows.single);
  }

  @override
  Future<Draft?> draft(DraftKey key) async {
    final rows = await database.query(
      'outbox_drafts',
      where: 'draft_key = ?',
      whereArgs: [key.value],
    );
    return rows.isEmpty ? null : _draft(rows.single);
  }

  @override
  Future<void> saveText(DraftKey key, String body) {
    final previous = _writes[key] ?? Future.value();
    final next = previous.catchError((_) {}).then((_) async {
      final count = await database.update(
        'outbox_drafts',
        {'body': body, 'updated_at': _now().toIso8601String()},
        where: 'draft_key = ?',
        whereArgs: [key.value],
      );
      if (count != 1) throw const AppError('storage.unavailable');
    });
    _writes[key] = next;
    return next.catchError(
      (Object _) => throw const AppError('storage.unavailable'),
      test: (error) => error is! AppError,
    );
  }

  @override
  Future<void> dispose() async {
    await Future.wait(_writes.values.map((w) => w.catchError((_) {})));
  }

  static Draft _draft(Map<String, Object?> row) => Draft(
    key: DraftKey(row['draft_key'] as String),
    connection: ConnectionKey(row['connection_key'] as String),
    profile: ProfileKey(row['profile_key'] as String),
    body: row['body'] as String,
  );
}
