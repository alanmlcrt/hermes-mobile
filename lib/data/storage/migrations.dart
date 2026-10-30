import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/connection.dart';
import 'secret_store.dart';

/// Efface le bearer hérité de l'observateur (5.7) ; remplaçable en test.
/// Un échec du stockage sécurisé n'empêche jamais la migration d'aboutir.
Future<void> Function(List<ConnectionKey> keys) purgeObserverBearer =
    (keys) async {
      final secrets = SecureSecretStore(const FlutterSecureStorage());
      for (final key in keys) {
        try {
          await secrets
              .delete(key, SecretUsage.observerBearer)
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          /* Secret hérité : sa purge reste facultative. */
        }
      }
    };

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
    await db.execute(
      'ALTER TABLE outbox_drafts ADD COLUMN idempotency_key TEXT',
    );
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
  (db) async {
    // Plus grand row_id utilisateur connu avant la soumission (rapprochement).
    await db.execute(
      'ALTER TABLE outbox_operations ADD COLUMN row_watermark INTEGER',
    );
  },
  (db) async {
    // Doublons éventuels : on garde un brouillon par conversation (texte non
    // vide, puis le plus récent) et on lui rattache les opérations des autres.
    final rows = await db.rawQuery(
      'SELECT draft_key, connection_key, profile_key, stored_session_id '
      'FROM outbox_drafts WHERE stored_session_id IS NOT NULL '
      "ORDER BY (body <> '') DESC, updated_at DESC, rowid",
    );
    final kept = <(String, String, String), String>{};
    for (final r in rows) {
      final triple = (
        r['connection_key'] as String,
        r['profile_key'] as String,
        r['stored_session_id'] as String,
      );
      final draft = r['draft_key'] as String;
      final keeper = kept.putIfAbsent(triple, () => draft);
      if (keeper == draft) continue;
      await db.update(
        'outbox_operations',
        {'draft_key': keeper},
        where: 'draft_key = ?',
        whereArgs: [draft],
      );
      await db.delete(
        'outbox_drafts',
        where: 'draft_key = ?',
        whereArgs: [draft],
      );
    }
    // Un seul brouillon de suite par conversation (casse respectée : collation BINARY).
    await db.execute(
      'CREATE UNIQUE INDEX outbox_drafts_session ON outbox_drafts '
      '(connection_key, profile_key, stored_session_id) '
      'WHERE stored_session_id IS NOT NULL',
    );
  },
  (db) async {
    await db.execute(
      'CREATE TABLE companion_backgrounds ('
      'origin TEXT NOT NULL COLLATE BINARY, '
      'connection_key TEXT NOT NULL COLLATE BINARY, '
      'profile_key TEXT NOT NULL COLLATE BINARY, palette_id TEXT NOT NULL, '
      'PRIMARY KEY (origin, connection_key, profile_key))',
    );
  },
  (db) async {
    await db.execute(
      'CREATE TABLE profile_accents ('
      'origin TEXT NOT NULL COLLATE BINARY, '
      'connection_key TEXT NOT NULL COLLATE BINARY, '
      'profile_key TEXT NOT NULL COLLATE BINARY, accent_id TEXT NOT NULL, '
      'PRIMARY KEY (origin, connection_key, profile_key))',
    );
  },
  (db) async {
    await db.execute(
      'CREATE TABLE outbox_stops ('
      'operation_key TEXT PRIMARY KEY, draft_key TEXT NOT NULL, '
      'connection_key TEXT NOT NULL, profile_key TEXT NOT NULL, '
      'stored_session_id TEXT NOT NULL, runtime TEXT NOT NULL, '
      'generation INTEGER NOT NULL, observed_turn INTEGER NOT NULL, '
      'state TEXT NOT NULL, error_code TEXT, created_at TEXT NOT NULL)',
    );
  },
  (db) async {
    await db.execute(
      'CREATE TABLE outbox_attachments ('
      'attachment_key TEXT PRIMARY KEY COLLATE BINARY, '
      'draft_key TEXT NOT NULL COLLATE BINARY, '
      'name TEXT NOT NULL, media_type TEXT NOT NULL, bytes INTEGER NOT NULL, '
      'state TEXT NOT NULL, position INTEGER NOT NULL, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX outbox_attachments_draft '
      'ON outbox_attachments (draft_key, position)',
    );
  },
  (db) async {
    await db.execute(
      'ALTER TABLE outbox_operations ADD COLUMN stored_session_id TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN operation_key TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN connection_key TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN profile_key TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN stored_session_id TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN reference TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN error_code TEXT',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN sent INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'CREATE TABLE outbox_operation_attachments ('
      'operation_key TEXT NOT NULL, attachment_key TEXT NOT NULL, '
      'position INTEGER NOT NULL, connection_key TEXT NOT NULL, '
      'profile_key TEXT NOT NULL, stored_session_id TEXT, '
      'state TEXT NOT NULL, reference TEXT, error_code TEXT, '
      'PRIMARY KEY (operation_key, attachment_key))',
    );
  },
  (db) async {
    await db.execute(
      'ALTER TABLE outbox_attachments ADD COLUMN cleaned INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE outbox_operation_attachments ADD COLUMN receipt_row_id INTEGER',
    );
  },
  (db) async {
    await db.execute(
      'CREATE TABLE notification_settings ('
      'connection_key TEXT PRIMARY KEY COLLATE BINARY, origin TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE notification_subscriptions ('
      'subscription_id TEXT PRIMARY KEY COLLATE BINARY, operation_key TEXT NOT NULL UNIQUE, '
      'connection_key TEXT NOT NULL, profile_key TEXT NOT NULL, session_id TEXT, stored_session_id TEXT, '
      'execution_id TEXT, state TEXT NOT NULL, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'ALTER TABLE outbox_operations ADD COLUMN notification_unfollowed INTEGER NOT NULL DEFAULT 0',
    );
  },
  (db) async {
    await db.execute(
      'ALTER TABLE notification_subscriptions ADD COLUMN attached_at TEXT',
    );
    await db.execute(
      "UPDATE notification_subscriptions SET attached_at = created_at WHERE state IN ('attached', 'notified')",
    );
  },
  (db) async {
    // 5.7 : le plugin Hermes remplace l'observateur ; abonnements, réglages
    // et bearer par connexion disparaissent.
    final rows = await db.query(
      'notification_settings',
      columns: ['connection_key'],
    );
    await db.execute('DROP TABLE notification_subscriptions');
    await db.execute('DROP TABLE notification_settings');
    try {
      await purgeObserverBearer([
        for (final row in rows) ConnectionKey(row['connection_key'] as String),
      ]);
    } catch (_) {
      /* Échec du stockage sécurisé ignoré : la migration aboutit. */
    }
  },
];
