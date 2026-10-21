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
];
