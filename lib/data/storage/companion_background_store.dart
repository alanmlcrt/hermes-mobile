import 'package:sqflite/sqflite.dart';

import '../../models/companion_background.dart';

class SqliteCompanionBackgroundStore implements CompanionBackgroundStore {
  SqliteCompanionBackgroundStore(this.database);
  final Database database;
  static const _where = 'origin = ? AND connection_key = ? AND profile_key = ?';
  List<Object?> _args(CompanionBackgroundIdentity identity) => [
    identity.origin,
    identity.connection.value,
    identity.profile.value,
  ];
  @override
  Future<CompanionPalette> read(CompanionBackgroundIdentity identity) async {
    final rows = await database.query(
      'companion_backgrounds',
      columns: ['palette_id'],
      where: _where,
      whereArgs: _args(identity),
    );
    return CompanionPalette.fromId(rows.firstOrNull?['palette_id'] as String?);
  }

  @override
  Future<void> save(
    CompanionBackgroundIdentity identity,
    CompanionPalette palette,
  ) async {
    await database.insert('companion_backgrounds', {
      'origin': identity.origin,
      'connection_key': identity.connection.value,
      'profile_key': identity.profile.value,
      'palette_id': palette.id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
