import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

Future<Database> openConnectionDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  final engine = factory ?? databaseFactory;
  final location =
      path ?? '${await engine.getDatabasesPath()}/hermes_mobile.sqlite';
  return engine.openDatabase(
    location,
    options: OpenDatabaseOptions(
      version: connectionMigrations.length,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (var index = 0; index < version; index++) {
          await connectionMigrations[index](db);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var index = oldVersion; index < newVersion; index++) {
          await connectionMigrations[index](db);
        }
      },
    ),
  );
}
