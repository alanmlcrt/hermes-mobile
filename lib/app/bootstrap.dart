import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/connection_repository.dart';
import '../data/conversation_repository.dart';
import '../data/event_mapping.dart';
import '../data/hermes_adapter.dart';
import '../data/outbox_repository.dart';
import '../data/storage/connection_store.dart';
import '../data/storage/database.dart';
import '../data/storage/companion_background_store.dart';
import '../data/storage/profile_accent_store.dart';
import '../models/companion_background.dart';
import '../data/storage/secret_store.dart';
import '../models/connection_gateway.dart';
import '../models/draft.dart';
import '../models/profile_accent.dart';
import '../models/timeline.dart';

Future<
  ({
    ConnectionGateway gateway,
    CompanionBackgroundStore backgrounds,
    ProfileAccentStore accents,
    OutboxGateway outbox,
    ConversationGateway conversation,
  })
>
bootstrap() async {
  final database = await openConnectionDatabase();
  final repository = ConnectionRepository(
    adapter: HermesAdapter(IoHermesTransport()),
    store: SqliteConnectionStore(database),
    secrets: SecureSecretStore(const FlutterSecureStorage()),
    closeStorage: database.close,
  );
  // La restauration réseau ne bloque pas le premier écran.
  final conversation = ConversationRepository(
    database,
    gateway: repository,
    mapping: await EventMapping.load(),
  );
  return (
    gateway: repository,
    backgrounds: SqliteCompanionBackgroundStore(database),
    accents: SqliteProfileAccentStore(database),
    outbox: OutboxRepository(
      database,
      gateway: repository,
      conversation: conversation,
    ),
    conversation: conversation,
  );
}
