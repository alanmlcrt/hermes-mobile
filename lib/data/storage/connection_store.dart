import 'package:sqflite/sqflite.dart';

import '../../models/connection.dart';
import '../../models/profile.dart';

abstract interface class ConnectionStore {
  Future<Connection?> read();
  Future<void> save(Connection connection);
}

class SqliteConnectionStore implements ConnectionStore {
  SqliteConnectionStore(this.database);
  final Database database;
  @override
  Future<Connection?> read() async {
    final rows = await database.query('connection_entries', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    final selected = row['selected_profile'] as String?;
    return Connection(
      key: ConnectionKey(row['connection_key'] as String),
      origin: parseOrigin(row['origin'] as String),
      selectedProfile: selected == null ? null : ProfileKey(selected),
    );
  }

  @override
  Future<void> save(Connection connection) async {
    await database.insert('connection_entries', {
      'connection_key': connection.key.value,
      'origin': connection.origin.toString(),
      'selected_profile': connection.selectedProfile?.value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
