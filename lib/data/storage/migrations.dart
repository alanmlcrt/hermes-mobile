import 'package:sqflite/sqflite.dart';

/// Registre en ajout seul : l'indice + 1 est la version SQLite.
final List<Future<void> Function(DatabaseExecutor)> connectionMigrations = [
  (db) async {
    await db.execute(
      'CREATE TABLE connection_entries ('
      'connection_key TEXT PRIMARY KEY, origin TEXT NOT NULL)',
    );
  },
  (db) async {
    await db.execute(
      'ALTER TABLE connection_entries ADD COLUMN selected_profile TEXT',
    );
  },
  (db) async {
    await db.execute(
      'CREATE TABLE outbox_drafts ('
      'draft_key TEXT PRIMARY KEY, connection_key TEXT NOT NULL, '
      'profile_key TEXT NOT NULL, body TEXT NOT NULL, '
      'updated_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX outbox_drafts_target '
      'ON outbox_drafts (connection_key, profile_key)',
    );
  },
  (db) async {
    await db.execute(
      'ALTER TABLE outbox_drafts ADD COLUMN revision INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE outbox_drafts ADD COLUMN stored_session_id TEXT',
    );
    await db.execute('ALTER TABLE outbox_drafts ADD COLUMN idempotency_key TEXT');
    // Une fois la session créée, le brouillon quitte l'unicité « nouveau ».
    await db.execute('DROP INDEX outbox_drafts_target');
    await db.execute(
      'CREATE UNIQUE INDEX outbox_drafts_new ON outbox_drafts '
      '(connection_key, profile_key) WHERE stored_session_id IS NULL',
    );
    await db.execute(
      'CREATE TABLE outbox_operations ('
      'operation_key TEXT PRIMARY KEY, draft_key TEXT NOT NULL, '
      'connection_key TEXT NOT NULL, profile_key TEXT NOT NULL, '
      'body TEXT NOT NULL, revision INTEGER NOT NULL, state TEXT NOT NULL, '
      'user_row_id INTEGER, error_code TEXT, '
      'created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX outbox_operations_draft ON outbox_operations (draft_key)',
    );
  },
  (db) async {
    // Projection et curseur dans la même ligne : une seule écriture atomique.
    await db.execute(
      'CREATE TABLE conversation_timelines ('
      'connection_key TEXT NOT NULL, profile_key TEXT NOT NULL, '
      'stored_session_id TEXT NOT NULL, projection TEXT NOT NULL, '
      'replay_epoch TEXT, seq INTEGER, updated_at TEXT NOT NULL, '
      'PRIMARY KEY (connection_key, profile_key, stored_session_id))',
    );
  },
];
