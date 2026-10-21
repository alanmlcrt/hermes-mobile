import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/connection_repository.dart';
import '../data/hermes_adapter.dart';
import '../data/outbox_repository.dart';
import '../data/storage/connection_store.dart';
import '../data/storage/database.dart';
import '../data/storage/secret_store.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';

Future<({ConnectionGateway gateway, OutboxGateway outbox})> bootstrap() async {
  final database = await openConnectionDatabase();
  final repository = ConnectionRepository(
    adapter: HermesAdapter(IoHermesTransport()),
    store: SqliteConnectionStore(database),
    secrets: SecureSecretStore(const FlutterSecureStorage()),
    closeStorage: database.close,
  );
  // La restauration réseau ne bloque pas le premier écran.
  return (
    gateway: repository,
    outbox: OutboxRepository(database, gateway: repository),
  );
}
