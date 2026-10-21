import 'connection.dart';
import 'profile.dart';

const rpcTimeout = Duration(seconds: 15);

/// Erreur JSON-RPC reçue : refus certain du serveur.
class RpcError implements Exception {
  const RpcError(this.code);
  final int code;
  @override
  String toString() => 'rpc.$code';
}

/// Notification `event` reçue pour une session (identifiant runtime).
class GatewayEvent {
  const GatewayEvent({
    required this.sessionId,
    required this.type,
    required this.payload,
    required this.generation,
    this.seq,
  });
  final String sessionId;
  final String type;
  final Map<String, dynamic> payload;
  final int? seq;

  /// Génération de socket qui a porté l'événement.
  final int generation;
}

abstract interface class ConnectionGateway {
  ConnectionSnapshot get snapshot;
  Stream<ConnectionSnapshot> get snapshots;
  Stream<GatewayEvent> get events;

  /// Change à chaque nouvelle socket : les identifiants runtime n'y survivent pas.
  int get socketGeneration;

  /// Appel JSON-RPC sur l'unique socket. Lève [RpcError] (refus reçu),
  /// `transport.offline` (rien écrit) ou `rpc.uncertain` (trame écrite, sans
  /// réponse : résultat incertain).
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = rpcTimeout,
  });
  Future<void> restore();
  Future<void> confirmOrigin(Uri origin);
  Future<void> authenticate(String password);
  Future<void> refreshProfiles();
  Future<void> selectProfile(ProfileKey key);
  Future<void> reconnect();
  Future<void> dispose();
}
