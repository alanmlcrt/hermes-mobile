import 'dart:convert';
import 'dart:io';

import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/models/app_error.dart';

class DiagnosticTransport extends IoHermesTransport {
  @override
  Future<TransportResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    // Seulement les routes fixes connues ; jamais origine, corps ou secrets.
    final result = await super.request(uri, method: method, body: body, bearer: bearer);
    stdout.writeln('$method ${uri.path}: HTTP ${result.status}');
    return result;
  }
}

Future<void> main() async {
  final transport = DiagnosticTransport();
  try {
    final origin = Uri.parse(Platform.environment['HERMES_URL']!);
    final port = origin.hasPort ? origin.port : origin.scheme == 'https' ? 443 : 80;
    final tcp = await Socket.connect(origin.host, port, timeout: networkTimeout);
    tcp.destroy();
    stdout.writeln('TCP: joignable');
    if (origin.scheme == 'https') {
      final tls = await SecureSocket.connect(origin.host, port, timeout: networkTimeout);
      tls.destroy();
      stdout.writeln('TLS: certificat accepte');
    }
    final adapter = HermesAdapter(transport);
    final tokens = await adapter.login(origin, Platform.environment['HERMES_PASSWORD']!);
    final profiles = await adapter.profiles(origin, tokens.access);
    stdout.writeln('Profil dedie present et non-defaut: ${profiles.any((p) => p.key.value == 'mesure-pieces-jointes' && !p.isDefault)}');
    await transport.request(origin.resolve('/api/health'), bearer: tokens.access);
    final socket = await adapter.socket(origin, tokens.access);
    stdout.writeln('WebSocket: upgrade authentifie accepte');
    final first = await socket.messages.first.timeout(const Duration(seconds: 20));
    final message = first is String ? jsonDecode(first) : first;
    stdout.writeln('WebSocket: gateway.ready recu: ${message is Map && message['params'] is Map && message['params']['type'] == 'gateway.ready'}');
    await socket.close();
  } on AppError catch (error) {
    stdout.writeln('Diagnostic bloque: ${error.code}');
    exitCode = 2;
  } catch (error) {
    stdout.writeln('Diagnostic bloque: ${error.runtimeType}');
    exitCode = 2;
  } finally {
    transport.close();
  }
}
