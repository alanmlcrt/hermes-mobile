import 'connection.dart';
import 'profile.dart';

const rpcTimeout = Duration(seconds: 15);

/// Sonde de la socket au retour au premier plan.
const pingTimeout = Duration(seconds: 3);

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
    this.replayEpoch,
  });
  final String sessionId;
  final String type;
  final Map<String, dynamic> payload;
  final int? seq;

  /// Génération de socket qui a porté l'événement.
  final int generation;

  /// `replay_epoch` annoncé par `gateway.ready` sur cette socket, si présent.
  final String? replayEpoch;
}

abstract interface class ConnectionGateway {
  ConnectionSnapshot get snapshot;
  Stream<ConnectionSnapshot> get snapshots;
  Stream<GatewayEvent> get events;

  /// Change à chaque nouvelle socket : les identifiants runtime n'y survivent pas.
  int get socketGeneration;

  /// `replay_epoch` du dernier `gateway.ready` de la socket ouverte.
  String? get replayEpoch;

  /// Appel JSON-RPC sur l'unique socket. Lève [RpcError] (refus reçu),
  /// `transport.offline` (rien écrit) ou `rpc.uncertain` (trame écrite, sans
  /// réponse : résultat incertain).
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = rpcTimeout,
  });

  /// Réponse à une requête serveur → client ([id] `srq-…`) : une seule trame
  /// `{id, result}` ou `{id, error}`, sans attente. Lève `transport.offline`
  /// (rien écrit) ou `rpc.uncertain` (écriture peut-être partielle).
  void respond(
    String id, {
    Map<String, dynamic>? result,
    Map<String, dynamic>? error,
  });
  Future<void> restore();
  Future<void> confirmOrigin(Uri origin);
  Future<void> authenticate(String password);
  Future<void> refreshProfiles();
  Future<void> selectProfile(ProfileKey key);
  Future<void> reconnect();
  Future<void> dispose();
}
