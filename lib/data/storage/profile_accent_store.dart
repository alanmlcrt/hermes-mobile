import 'package:sqflite/sqflite.dart';

import '../../models/profile_accent.dart';

class SqliteProfileAccentStore implements ProfileAccentStore {
  SqliteProfileAccentStore(this.database);
  final Database database;
  static const _where = 'origin = ? AND connection_key = ? AND profile_key = ?';
  List<Object?> _args(ProfileIdentity identity) => [
    identity.origin,
    identity.connection.value,
    identity.profile.value,
  ];
  @override
  Future<ProfileAccent?> read(ProfileIdentity identity) async {
    final rows = await database.query(
      'profile_accents',
      columns: ['accent_id'],
      where: _where,
      whereArgs: _args(identity),
    );
    return ProfileAccent.fromId(rows.firstOrNull?['accent_id'] as String?);
  }

  @override
  Future<void> save(ProfileIdentity identity, ProfileAccent accent) async {
    await database.insert('profile_accents', {
      'origin': identity.origin,
      'connection_key': identity.connection.value,
      'profile_key': identity.profile.value,
      'accent_id': accent.id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
