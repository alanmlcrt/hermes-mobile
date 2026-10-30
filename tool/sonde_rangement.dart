// Standalone investigation tool. No mobile repositories or private databases.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:web_socket_channel/io.dart';

class ProbeFailure implements Exception {
  const ProbeFailure(this.kind);
  final String kind;
}

class ProbeConfig {
  ProbeConfig({
    required this.origin,
    required this.profile,
    required this.sessions,
    this.token,
    this.ticket,
    this.authorizedProfile,
    this.authorizedSessions = const {},
    this.authorizedLineages = const {},
    this.timeout = const Duration(seconds: 10),
  }) {
    if (!['http', 'https'].contains(origin.scheme) ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        !['', '/'].contains(origin.path) ||
        profile.isEmpty ||
        sessions.isEmpty ||
        sessions.any((s) => s.isEmpty) ||
        timeout <= Duration.zero ||
        timeout > const Duration(seconds: 60) ||
        (token == null && ticket == null) ||
        token == '' ||
        ticket == '') {
      throw const ProbeFailure('invalid_configuration');
    }
  }

  final Uri origin;
  final String profile;
  final Set<String> sessions;
  final String? token, ticket, authorizedProfile;
  final Set<String> authorizedSessions, authorizedLineages;
  final Duration timeout;

  factory ProbeConfig.environment(Map<String, String> env) {
    Set<String> ids(String key) =>
        (env[key] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
    return ProbeConfig(
      origin: Uri.parse(env['HERMES_ORIGIN'] ?? ''),
      profile: env['HERMES_PROFILE'] ?? '',
      sessions: ids('HERMES_SESSIONS'),
      token: env['HERMES_TOKEN'],
      ticket: env['HERMES_TICKET'],
      authorizedProfile: env['HERMES_AUTHORIZE_PROFILE'],
      authorizedSessions: ids('HERMES_AUTHORIZE_SESSIONS'),
      authorizedLineages: ids('HERMES_AUTHORIZE_LINEAGES'),
    );
  }
}

abstract class ProbeTransport {
  Future<Object?> profiles();
  Future<void> connect();
  Stream<Object?> get replies;
  void send(Map<String, Object?> request);
  Future<void> close();
}

// WebSocket.connect otherwise follows HTTP redirects, including credentials.
class NoRedirectClient implements HttpClient {
  NoRedirectClient(this.delegate);
  final HttpClient delegate;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await delegate.openUrl(method, url);
    request.followRedirects = false;
    return request;
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NetworkProbeTransport implements ProbeTransport {
  NetworkProbeTransport(this.config) {
    _http = IOClient(_restClient);
  }
  final ProbeConfig config;
  final HttpClient _restClient = HttpClient();
  final NoRedirectClient _wsClient = NoRedirectClient(HttpClient());
  late final http.Client _http;
  WebSocket? _socket;
  IOWebSocketChannel? _channel;
  bool _closed = false;

  @override
  Future<Object?> profiles() async {
    final request = http.Request('GET', config.origin.resolve('/api/profiles'))
      ..followRedirects = false;
    if (config.token != null) {
      request.headers['Authorization'] = 'Bearer ${config.token}';
    }
    final response = await _http.send(request);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const ProbeFailure('redirect_refused');
    }
    if ([401, 403].contains(response.statusCode)) {
      throw const ProbeFailure('authentication_refused');
    }
    if (response.statusCode != 200) throw const ProbeFailure('http_failure');
    // Bound the response as well as its deadline.
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        throw const ProbeFailure('response_too_large');
      }
    }
    return jsonDecode(utf8.decode(bytes));
  }

  @override
  Future<void> connect() async {
    final uri = config.origin
        .resolve('/api/ws')
        .replace(
          scheme: config.origin.scheme == 'https' ? 'wss' : 'ws',
          queryParameters: config.ticket == null
              ? {'token': config.token!}
              : {'ticket': config.ticket!},
        );
    try {
      final socket = await WebSocket.connect(
        uri.toString(),
        maxPayloadLength: 1024 * 1024,
        customClient: _wsClient,
        headers: config.token == null
            ? null
            : {'Authorization': 'Bearer ${config.token}'},
      );
      if (_closed) {
        await socket.close();
        throw const ProbeFailure('transport_closed');
      }
      _socket = socket;
      _channel = IOWebSocketChannel(socket);
    } on WebSocketException catch (error) {
      if ([401, 403].contains(error.httpStatusCode)) {
        throw const ProbeFailure('authentication_refused');
      }
      if (error.httpStatusCode != null &&
          error.httpStatusCode! >= 300 &&
          error.httpStatusCode! < 400) {
        throw const ProbeFailure('redirect_refused');
      }
      throw const ProbeFailure('connection_failure');
    }
  }

  @override
  Stream<Object?> get replies async* {
    await for (final frame in _channel!.stream) {
      if (frame is! String || frame.length > 1024 * 1024) {
        throw const ProbeFailure('invalid_frame');
      }
      yield jsonDecode(frame);
    }
    if (_socket?.closeCode == 4401) {
      throw const ProbeFailure('authentication_refused');
    }
    if (_socket?.closeCode == 4403) {
      throw const ProbeFailure('access_refused');
    }
  }

  @override
  void send(Map<String, Object?> request) =>
      _channel!.sink.add(jsonEncode(request));
  @override
  Future<void> close() async {
    _closed = true;
    _http.close();
    _wsClient.close(force: true);
    // Do not wait indefinitely for a peer's close handshake.
    unawaited(_socket?.close());
  }
}

// Only a fixed projection leaves memory. Unknown keys, diagnostics and messages
// are never copied. Pseudonyms remain stable only within this capture.
class CaptureProjection {
  final Map<String, String> _ids = {}, _texts = {};
  String _alias(Map<String, String> table, String value, String prefix) =>
      table.putIfAbsent(value, () => '$prefix-${table.length + 1}');
  Object? project(Object? value, [String key = '']) {
    if (key == 'role') {
      return const {'user', 'assistant', 'system', 'tool'}.contains(value)
          ? value
          : null;
    }
    if (value is List) return value.map((v) => project(v, key)).toList();
    if (value is Map) {
      return <String, Object?>{
        for (final field in value.entries)
          if (_allowed.contains(field.key))
            field.key as String: project(field.value, field.key as String),
      };
    }
    if (_identity.contains(key) && value is String) {
      return _alias(_ids, value, 'id');
    }
    if (key == 'row_id' && (value is String || value is int)) {
      return _alias(_ids, 'row:$value', 'id');
    }
    if (_text.contains(key) && value is String) {
      return _alias(_texts, value, 'text');
    }
    if (_flags.contains(key) && value is bool) return value;
    if (_counts.contains(key) && value is int && value >= 0) return value;
    return null;
  }

  static const _identity = {
    'id',
    'session_id',
    'session_key',
    'resolved_id',
    '_lineage_root_id',
    'profile',
    'deleted',
    'name',
  };
  static const _text = {
    'title',
    'text',
    'preview',
    'content',
    'version',
    'build',
    'commit',
  };
  static const _flags = {
    'hidden',
    'archived',
    'pending',
    'include_hidden',
    'per_session_exclusive_submit',
  };
  static const _counts = {
    'count',
    'message_count',
    'live_message_count',
    'limit',
  };
  static final _allowed = {
    ..._identity,
    ..._text,
    ..._flags,
    ..._counts,
    'sessions',
    'profiles',
    'messages',
    'row_id',
    'role',
  };
}

class ArrangementProbe {
  ArrangementProbe(this.config, this.transport);
  final ProbeConfig config;
  final ProbeTransport transport;
  final CaptureProjection _projection = CaptureProjection();
  final List<Map<String, Object?>> records = [];
  final Map<int, Completer<Map>> _pending = {};
  StreamSubscription<Object?>? _subscription;
  int _sequence = 0;
  bool _mutationAttempted = false;
  bool _mutationAnswered = false;
  bool _used = false;

  Future<Map<String, Object?>> run({
    String? mutation,
    String? session,
    String? title,
    bool? value,
  }) async {
    String? failureCategory;
    var stage = 'before';
    try {
      if (_used) throw const ProbeFailure('probe_already_used');
      _used = true;
      _validate(mutation, session, title, value);
      final profiles = await transport.profiles().timeout(config.timeout);
      records.add({
        'surface': 'GET /api/profiles',
        'outcome': 'observed',
        'response': _projection.project(profiles),
      });
      await transport.connect().timeout(config.timeout);
      _subscription = transport.replies.listen(
        (frame) {
          if (frame is Map && frame['jsonrpc'] == '2.0' && frame['id'] is int) {
            final pending = _pending.remove(frame['id']);
            pending?.complete(frame);
          }
        },
        onError: (Object error) => _failPending(error),
        onDone: _failPending,
      );
      await _rpc('gateway.capabilities', {});
      final baseline = await _snapshot('before');
      if (mutation != null) {
        if (!baseline) throw const ProbeFailure('baseline_read_failed');
        stage = 'mutation';
        _mutationAttempted = true;
        await _rpc(mutation, {
          'profile': config.profile,
          'session_id': session,
          if (mutation == 'session.title') 'title': title,
          if (mutation == 'session.set_hidden') 'hidden': value,
          if (mutation == 'session.archive') 'archived': value,
        }, mutation: true);
        _mutationAnswered = true;
        stage = 'after';
        if (!await _snapshot('after')) {
          throw const ProbeFailure('postcheck_failed');
        }
      } else if (!baseline) {
        failureCategory = 'baseline_read_failed';
      }
    } catch (error) {
      final cause = error is ProbeFailure
          ? error.kind
          : error is TimeoutException
          ? 'timeout'
          : 'transport_failure';
      failureCategory = stage == 'after' ? 'postcheck_failed' : cause;
      records.add({
        'outcome': failureCategory,
        'cause': cause,
        'mutation_result': _mutationAnswered
            ? 'response_received'
            : _mutationAttempted
            ? 'uncertain_do_not_replay'
            : 'not_sent',
      });
    } finally {
      try {
        await _subscription?.cancel().timeout(config.timeout);
      } catch (_) {
        records.add({'outcome': 'subscription_close_failure'});
        failureCategory ??= 'subscription_close_failure';
      }
      try {
        await transport.close().timeout(config.timeout);
      } catch (_) {
        records.add({'outcome': 'transport_close_failure'});
        failureCategory ??= 'transport_close_failure';
      }
    }
    return {
      'schema_version': 1,
      'evidence': 'observed_transport',
      'installed_build': 'unverified',
      'other_client': 'unverified',
      'search_coverage': 'unverified',
      'validated': false,
      'protocol_complete': failureCategory == null,
      'failure_category': ?failureCategory,
      'records': records,
    };
  }

  void _validate(
    String? mutation,
    String? session,
    String? title,
    bool? value,
  ) {
    if (mutation == null) return;
    if (!{
          'session.title',
          'session.set_hidden',
          'session.archive',
          'session.delete',
        }.contains(mutation) ||
        config.authorizedProfile != config.profile ||
        !config.sessions.contains(session) ||
        !config.authorizedSessions.contains(session) ||
        ({'session.set_hidden', 'session.archive'}.contains(mutation) &&
            !config.authorizedLineages.contains(session)) ||
        (mutation == 'session.title' && (title == null || title.isEmpty)) ||
        ({'session.set_hidden', 'session.archive'}.contains(mutation) &&
            value == null)) {
      throw const ProbeFailure('local_authorization_refused');
    }
  }

  void _failPending([Object? error]) {
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(
        error is ProbeFailure ? error : const ProbeFailure('connection_closed'),
      );
    }
  }

  Future<bool> _snapshot(String phase) async {
    var complete = true;
    for (final hidden in [false, true]) {
      final success = await _rpc('session.list', {
        'profile': config.profile,
        'include_hidden': hidden,
        'limit': 100,
      }, phase: phase);
      complete = success && complete;
    }
    for (final id in config.sessions) {
      try {
        await _rpc('session.title', {
          'profile': config.profile,
          'session_id': id,
        }, phase: phase);
      } catch (_) {
        // Runtime-only title inspection is optional. Its failed read is already
        // captured; the necessary history read below must still succeed.
      }
      final success = await _rpc('session.history', {
        'profile': config.profile,
        'session_id': id,
      }, phase: phase);
      complete = success && complete;
    }
    return complete;
  }

  Future<bool> _rpc(
    String method,
    Map<String, Object?> params, {
    bool mutation = false,
    String? phase,
  }) async {
    final id = ++_sequence;
    final completer = Completer<Map>();
    _pending[id] = completer;
    final record = <String, Object?>{
      'request_id': id,
      'method': method,
      'params': _projection.project(params),
      'mutation': mutation,
      'phase': ?phase,
    };
    records.add(
      record,
    ); // Never serialize raw frames, including error messages.
    try {
      transport.send({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      });
      final reply = await completer.future.timeout(config.timeout);
      if (reply.containsKey('result') == reply.containsKey('error')) {
        throw const ProbeFailure('invalid_rpc_response');
      }
      if (reply.containsKey('error')) {
        final error = reply['error'];
        final code = error is Map ? error['code'] : null;
        if (code is! int) throw const ProbeFailure('invalid_rpc_response');
        record['outcome'] = code == -32601
            ? 'method_absent'
            : code == -32602
            ? 'invalid_parameters'
            : 'rpc_error';
        record['error_code'] = code;
        return false;
      } else if (reply.containsKey('result')) {
        if (reply['result'] is! Map) {
          throw const ProbeFailure('invalid_rpc_response');
        }
        record['outcome'] = 'observed_response';
        record['response'] = _projection.project(reply['result']);
        return true;
      } else {
        throw const ProbeFailure('invalid_rpc_response');
      }
    } catch (_) {
      record['outcome'] = mutation ? 'uncertain_do_not_replay' : 'read_failed';
      rethrow;
    } finally {
      _pending.remove(id);
    }
  }
}

Future<void> main(List<String> args) async {
  // No arguments carry secrets; values and authorizations come from environment.
  try {
    if (args.length > 1) throw const ProbeFailure('invalid_configuration');
    final env = Platform.environment;
    final output = env['HERMES_CAPTURE'];
    if (output == null || output.isEmpty || await File(output).exists()) {
      throw const ProbeFailure('new_capture_path_required');
    }
    final config = ProbeConfig.environment(env);
    // Reserve the destination before any network activity/mutation. An empty
    // exclusive file contains no raw response and prevents evidence overwrite.
    final file = File(output);
    await file.create(exclusive: true);
    final report = await ArrangementProbe(config, NetworkProbeTransport(config))
        .run(
          mutation: args.isEmpty ? null : args.single,
          session: env['HERMES_TARGET_SESSION'],
          title: env['HERMES_NEW_TITLE'],
          value: switch (env['HERMES_VALUE']) {
            'true' => true,
            'false' => false,
            _ => null,
          },
        );
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    if (report['protocol_complete'] != true) {
      throw ProbeFailure(report['failure_category'] as String);
    }
    stdout.writeln(
      'Anonymized capture written; installation validation remains open.',
    );
  } catch (error) {
    stderr.writeln(error is ProbeFailure ? error.kind : 'probe_failed');
    exitCode = 1;
  }
}
