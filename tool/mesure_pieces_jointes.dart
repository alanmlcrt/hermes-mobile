import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hermes_mobile/data/hermes_adapter.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/profile.dart';

const _categories = ['text', 'image', 'pdf', 'office'];
const _surfaces = ['file.attach', 'rest.image-upload', 'image.attach_bytes'];
const _profileRole = 'dedicated-test-profile';
const _probeTimeout = Duration(seconds: 30);
const _readyTimeout = Duration(seconds: 20);
const _turnTimeout = Duration(seconds: 120);
const _receiptAttempts = 10;
const _receiptDelay = Duration(milliseconds: 500);
const _maxRepetitions = 20;

const _corpusLocation =
    '_bmad-output/implementation-artifacts/corpus-pieces-jointes/';

const _descriptions = {
  'text': 'long texte',
  'image': 'photo ou capture',
  'pdf': 'PDF',
  'office': 'document bureautique',
};

const _transportSources = {
  'file.attach': {
    'contract': 'pinned',
    'source': 'contracts/openrpc.json, méthode file.attach',
    'parameters': ['data_url'],
  },
  'rest.image-upload': {
    'contract': 'outside-pinned',
    'source':
        'source du build, route POST /api/chat/image-upload '
        '(hors extrait épinglé)',
    'parameters': ['data_url'],
  },
  'image.attach_bytes': {
    'contract': 'outside-pinned',
    'source': 'contrat amont image.attach_bytes, absent de l’extrait épinglé',
    'parameters': ['content_base64'],
  },
};

const _mimeTypes = {
  '.txt': 'text/plain',
  '.md': 'text/markdown',
  '.csv': 'text/csv',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.bmp': 'image/bmp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
  '.tif': 'image/tiff',
  '.tiff': 'image/tiff',
  '.pdf': 'application/pdf',
  '.doc': 'application/msword',
  '.docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.ppt': 'application/vnd.ms-powerpoint',
  '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  '.odt': 'application/vnd.oasis.opendocument.text',
  '.ods': 'application/vnd.oasis.opendocument.spreadsheet',
  '.odp': 'application/vnd.oasis.opendocument.presentation',
  '.json': 'application/json',
  '.xml': 'application/xml',
};

const _officeExtensions = {
  '.doc',
  '.docx',
  '.xls',
  '.xlsx',
  '.ppt',
  '.pptx',
  '.odt',
  '.ods',
  '.odp',
};

Future<void> main(List<String> args) async {
  final parsed = _parse(args);
  if (parsed.help) {
    stdout.writeln(_usage);
    return;
  }
  if (parsed.error != null) {
    stderr.writeln(parsed.error);
    stderr.writeln('');
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  final options = parsed.options!;
  final transport = IoHermesTransport();
  try {
    final contract = await _measure(options, transport);
    final text = const JsonEncoder.withIndent('  ').convert(contract);
    if (options.output == null) {
      stdout.writeln(text);
    } else {
      try {
        await File(options.output!).writeAsString(text, flush: true);
      } catch (_) {
        throw const _Blocked('écriture de la sortie impossible');
      }
    }
    if (!hasUsableTransport(contract)) {
      stderr.writeln(incompleteMeasurementMessage());
      exitCode = 2;
    }
  } on _Blocked catch (error) {
    stderr.writeln('Mesure bloquée : ${error.reason}');
    exitCode = 2;
  } on AppError catch (error) {
    stderr.writeln('Mesure bloquée : ${error.code}');
    exitCode = 2;
  } catch (_) {
    // Aucun chemin, identifiant, contenu ou message serveur dans la sortie.
    stderr.writeln('Mesure bloquée : erreur inattendue.');
    exitCode = 2;
  } finally {
    transport.close();
  }
}

Future<Map<String, dynamic>> _measure(
  _Options options,
  IoHermesTransport transport,
) async {
  final origin = _origin();
  final pieces = await _loadPieces(options.pieces);
  final applicable = <(String, _Piece)>[];
  for (final piece in pieces) {
    for (final surface in options.surfaces) {
      if (_applies(surface, piece.category)) {
        applicable.add((surface, piece));
      }
    }
  }
  if (applicable.isEmpty) {
    throw const _Blocked('aucune surface ne s’applique aux pièces fournies');
  }
  final session = await _Session.open(transport, origin, options.profile);
  stderr.writeln('Profil de test dédié connecté ; gateway.ready reçu.');
  try {
    final observations = <_Observation>[];
    for (final (surface, piece) in applicable) {
      stderr.writeln(
        'Observation ${observations.length + 1}/${applicable.length} : '
        '$surface, ${piece.mediaType}, ${piece.bytes.length} octets.',
      );
      observations.add(
        await _probePiece(
          session,
          surface,
          piece,
          options.repetitions,
          options.visionMarker,
        ),
      );
      final observation = observations.last;
      stderr.writeln(
        'Observation terminée : ${observation.outcome.name}, '
        '${observation.receivedCount} reçus confirmés.',
      );
    }
    final finishedAt = DateTime.now().toUtc().toIso8601String();
    return _contract(
      observations,
      pieces,
      session.build,
      session.measuredAt,
      finishedAt,
      options.repetitions,
    );
  } finally {
    try {
      await session.close();
    } catch (_) {
      // La fermeture ne doit pas masquer le résultat de la mesure.
    }
  }
}

Uri _origin() {
  final value = Platform.environment['HERMES_URL']?.trim();
  if (value == null || value.isEmpty) {
    throw const _Blocked('HERMES_URL est requis dans l’environnement');
  }
  try {
    return parseOrigin(value);
  } on AppError {
    throw const _Blocked(
      'HERMES_URL n’est pas une origine acceptée par l’app '
      '(https, ou http .ts.net)',
    );
  }
}

Future<List<_Piece>> _loadPieces(List<_PieceRef> refs) async {
  final pieces = <_Piece>[];
  for (final ref in refs) {
    final file = File(ref.path);
    if (!await file.exists()) {
      throw _Blocked('pièce de catégorie ${ref.category} introuvable');
    }
    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw _Blocked('pièce de catégorie ${ref.category} illisible');
    }
    if (bytes.isEmpty) {
      throw _Blocked('pièce de catégorie ${ref.category} vide');
    }
    final name = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last;
    final extension = _extension(name);
    if (!_matchesCategory(ref.category, extension)) {
      throw _Blocked(
        'pièce de catégorie ${ref.category} avec une extension incohérente',
      );
    }
    pieces.add(
      _Piece(
        category: ref.category,
        name: name,
        bytes: bytes,
        extension: extension,
        mediaType: _mimeTypes[extension] ?? 'application/octet-stream',
      ),
    );
  }
  return pieces;
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot).toLowerCase();
}

bool _matchesCategory(String category, String extension) {
  return switch (category) {
    'text' =>
      _mimeTypes[extension]?.startsWith('text/') == true ||
          extension == '.json' ||
          extension == '.xml',
    'image' => _mimeTypes[extension]?.startsWith('image/') == true,
    'pdf' => extension == '.pdf',
    'office' => _officeExtensions.contains(extension),
    _ => false,
  };
}

class _Session {
  _Session._(
    this._auth, {
    required this.adapter,
    required this.transport,
    required this.origin,
    required this.profile,
    required this.build,
    required this.measuredAt,
    required this.rpc,
  });

  final IoHermesTransport transport;
  final HermesAdapter adapter;
  final Uri origin;
  final Profile profile;
  final String build;
  final String measuredAt;
  final _Rpc rpc;
  final _Auth _auth;

  String get access => _auth.access;

  Future<bool> renewAccess() async {
    final refresh = _auth.refresh;
    if (refresh == null) return false;
    try {
      final tokens = await adapter.refresh(origin, refresh);
      _auth
        ..access = tokens.access
        ..refresh = tokens.refresh;
      return true;
    } on AppError {
      return false;
    }
  }

  static Future<_Session> open(
    IoHermesTransport transport,
    Uri origin,
    String profileKey,
  ) async {
    final adapter = HermesAdapter(transport);
    final auth = await _authenticate(adapter, origin);
    final profiles = await _authorized(
      adapter,
      origin,
      auth,
      (bearer) => adapter.profiles(origin, bearer),
    );
    final matches = profiles
        .where((profile) => profile.key.value == profileKey)
        .toList();
    if (matches.isEmpty) {
      throw const _Blocked('profil de test introuvable sur l’installation');
    }
    final profile = matches.first;
    if (profile.isDefault) {
      throw const _Blocked(
        'le profil cible est le profil par défaut ; utiliser un profil de '
        'test dédié',
      );
    }
    final measuredAt = DateTime.now().toUtc().toIso8601String();
    final build = await _build(transport, origin, auth.access);
    GatewaySocket socket;
    try {
      socket = await _authorized(
        adapter,
        origin,
        auth,
        (bearer) => adapter.socket(origin, bearer),
      );
    } on AppError catch (error) {
      throw _Blocked('transport WebSocket indisponible (${error.code})');
    }
    final rpc = _Rpc(socket);
    try {
      await rpc.ready.timeout(_readyTimeout);
    } catch (_) {
      await rpc.close();
      throw const _Blocked('gateway.ready absent');
    }
    if (!HermesRpc.conversationSupported(rpc.readyPayload!)) {
      await rpc.close();
      throw const _Blocked('autorité de session non prise en charge');
    }
    return _Session._(
      auth,
      adapter: adapter,
      transport: transport,
      origin: origin,
      profile: profile,
      build: build,
      measuredAt: measuredAt,
      rpc: rpc,
    );
  }

  Future<void> close() => rpc.close();
}

class _Auth {
  _Auth(this.access, this.refresh);
  String access;
  String? refresh;
}

Future<_Auth> _authenticate(HermesAdapter adapter, Uri origin) async {
  final environment = Platform.environment;
  final token = environment['HERMES_TOKEN']?.trim();
  if (token != null && token.isNotEmpty) return _Auth(token, null);
  final password = environment['HERMES_PASSWORD'];
  if (password == null || password.isEmpty) {
    throw const _Blocked(
      'HERMES_TOKEN ou HERMES_PASSWORD est requis dans l’environnement',
    );
  }
  try {
    final tokens = await adapter.login(origin, password);
    return _Auth(tokens.access, tokens.refresh);
  } on AppError catch (error) {
    throw _Blocked('authentification refusée (${error.code})');
  }
}

Future<T> _authorized<T>(
  HermesAdapter adapter,
  Uri origin,
  _Auth auth,
  Future<T> Function(String bearer) operation,
) async {
  try {
    return await operation(auth.access);
  } on AppError catch (error) {
    if (error.code != 'auth.refused' || auth.refresh == null) rethrow;
    final tokens = await adapter.refresh(origin, auth.refresh!);
    auth
      ..access = tokens.access
      ..refresh = tokens.refresh;
    return operation(auth.access);
  }
}

Future<String> _build(
  IoHermesTransport transport,
  Uri origin,
  String access,
) async {
  TransportResponse response;
  try {
    response = await transport.request(
      origin.resolve('/api/health'),
      bearer: access,
    );
  } catch (_) {
    throw const _Blocked('build non observé (/api/health)');
  }
  if (response.status != 200) {
    throw const _Blocked('build non observé (/api/health)');
  }
  final build = _sanitizeBuild(
    response.body['displayVersion'] ?? response.body['version'],
  );
  if (build == null) {
    throw const _Blocked('build non observé (/api/health)');
  }
  return build;
}

String? _sanitizeBuild(Object? value) {
  if (value is! String) return null;
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty || text.length > 120) return null;
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._+()\-]*$').hasMatch(text)) {
    return null;
  }
  return text;
}

/// Classe le résultat d'une pièce sans effet de bord.
Outcome classifyOutcome({
  required bool present,
  required String? error,
  required bool uncertain,
  required int acceptedCount,
  required bool receiptConfirmed,
}) {
  if (acceptedCount == 0) {
    if (uncertain) return Outcome.unverified;
    if (!present && error == 'method_missing') return Outcome.absent;
    if (present) return Outcome.refused;
    return Outcome.unverified;
  }
  return receiptConfirmed ? Outcome.accepted : Outcome.unverified;
}

Future<_Observation> _probePiece(
  _Session session,
  String surface,
  _Piece piece,
  int repetitions,
  String? visionMarker,
) async {
  final created = await _createSession(session);
  final runtime = created.runtime;
  var present = false;
  var acceptedCount = 0;
  var uncertain = false;
  var attempts = 0;
  var countAmbiguous = false;
  String? error;
  final attachments = <_Attachment>[];

  for (var index = 1; index <= repetitions; index++) {
    attempts = index;
    final result = await _attach(session, surface, runtime, piece);
    stderr.writeln(
      'Copie $index/$repetitions : '
      '${result.accepted
          ? 'upload accepté'
          : result.uncertain
          ? 'incertaine'
          : 'refusée'}'
      '${result.error == null ? '' : ' (${result.error})'}.',
    );
    if (result.present) present = true;
    if (result.accepted) {
      acceptedCount = index;
      attachments.add(
        _Attachment(references: result.references, promptRef: result.promptRef),
      );
      continue;
    }
    error = result.error;
    if (result.uncertain) {
      uncertain = true;
      break;
    }
    if (index > 1) {
      // Un refus après plusieurs acceptations peut être un plafond de nombre
      // ou un plafond de volume cumulé : aucune des deux limites n'est déduite.
      countAmbiguous = true;
    }
    break;
  }
  attempts = acceptedCount == repetitions ? repetitions : attempts;

  if (acceptedCount == 0) {
    final outcome = classifyOutcome(
      present: present,
      error: error,
      uncertain: uncertain,
      acceptedCount: acceptedCount,
      receiptConfirmed: false,
    );
    return _Observation(
      surface: surface,
      piece: piece,
      outcome: outcome,
      present: present,
      error: error,
      attempts: attempts,
      countAmbiguous: countAmbiguous,
    );
  }

  final token = _token();
  final prompt = _prompt(surface, attachments, token);
  stderr.writeln(
    'Références upload distinctes : '
    '${attachments.map((attachment) => attachment.promptRef).toSet().length}'
    '/${attachments.length}.',
  );
  Map<String, dynamic> submitted;
  try {
    submitted = await session.rpc.call(
      'prompt.submit',
      HermesRpc.submitParams(runtime, prompt),
    );
  } on RpcError catch (rpcError) {
    return _Observation(
      surface: surface,
      piece: piece,
      outcome: Outcome.unverified,
      present: present,
      acceptedCount: acceptedCount,
      error: 'rpc.${rpcError.code}',
      attempts: attempts,
      countAmbiguous: countAmbiguous,
    );
  } on AppError catch (appError) {
    return _Observation(
      surface: surface,
      piece: piece,
      outcome: Outcome.unverified,
      present: present,
      acceptedCount: acceptedCount,
      error: appError.code,
      attempts: attempts,
      countAmbiguous: countAmbiguous,
    );
  }
  if (HermesRpc.submitted(submitted) == null) {
    return _Observation(
      surface: surface,
      piece: piece,
      outcome: Outcome.unverified,
      present: present,
      acceptedCount: acceptedCount,
      error: 'prompt.refused',
      attempts: attempts,
      countAmbiguous: countAmbiguous,
    );
  }

  stderr.writeln('Prompt de test accepté ; attente du tour puis relecture.');

  // Sans marqueur de vision, seule la réception est mesurée. La preuve
  // d'historique ne dépend pas de la fin d'une analyse par le modèle.
  if (visionMarker == null) {
    final receipt = await _readReceipt(
      session,
      surface,
      runtime,
      token,
      attachments,
    );
    await _interrupt(session, runtime);
    return _Observation(
      surface: surface,
      piece: piece,
      outcome: classifyOutcome(
        present: present,
        error: error,
        uncertain: uncertain,
        acceptedCount: acceptedCount,
        receiptConfirmed:
            receipt.confirmed && receipt.received == attachments.length,
      ),
      present: present,
      acceptedCount: acceptedCount,
      error: error,
      receipt: receipt.receipt,
      attempts: attempts,
      receivedCount: receipt.confirmed ? receipt.received : 0,
      countAmbiguous: countAmbiguous,
    );
  }

  var turnFinished = false;
  try {
    await session.rpc.waitFor(runtime, const {
      'message.complete',
      'error',
    }, _turnTimeout);
    turnFinished = true;
  } on TimeoutException {
    // Le tour reste incertain : on l'arrête sans conclure à un refus.
  }
  if (!turnFinished) {
    await _interrupt(session, runtime);
  }

  final receipt = await _readReceipt(
    session,
    surface,
    runtime,
    token,
    attachments,
  );
  final isImage = piece.category == 'image';
  final vision = isImage && receipt.confirmed
      ? _vision(session.rpc, runtime, receipt.text, visionMarker)
      : null;
  return _Observation(
    surface: surface,
    piece: piece,
    outcome: classifyOutcome(
      present: present,
      error: error,
      uncertain: uncertain,
      acceptedCount: acceptedCount,
      receiptConfirmed: receipt.confirmed,
    ),
    present: present,
    acceptedCount: acceptedCount,
    error: error,
    receipt: receipt.receipt,
    vision: vision,
    model: vision?.model,
    attempts: attempts,
    receivedCount: receipt.confirmed ? receipt.received : 0,
    countAmbiguous: countAmbiguous,
  );
}

Future<({String runtime, String stored})> _createSession(
  _Session session,
) async {
  try {
    final result = await session.rpc.call(
      'session.create',
      HermesRpc.createParams(session.profile.key, randomUuid()),
    );
    return HermesRpc.created(result);
  } on RpcError catch (error) {
    throw _Blocked('session.create refusé (rpc.${error.code})');
  } on AppError catch (error) {
    throw _Blocked('session.create invalide (${error.code})');
  }
}

Future<void> _interrupt(_Session session, String runtime) async {
  try {
    await session.rpc.call(
      'session.interrupt',
      HermesRpc.interruptParams(runtime, session.profile.key),
    );
  } catch (_) {
    // L'arrêt n'est pas une preuve de réception : son échec reste silencieux.
  }
}

Future<_AttachResult> _attach(
  _Session session,
  String surface,
  String runtime,
  _Piece piece,
) {
  return switch (surface) {
    'file.attach' => _attachFile(session, runtime, piece),
    'rest.image-upload' => _attachImageRest(session, runtime, piece),
    'image.attach_bytes' => _attachImageBytes(session, runtime, piece),
    _ => Future.value(
      const _AttachResult(
        present: false,
        accepted: false,
        error: 'surface.inconnue',
      ),
    ),
  };
}

Future<_AttachResult> _attachFile(
  _Session session,
  String runtime,
  _Piece piece,
) async {
  try {
    final result = await session.rpc.call('file.attach', {
      'session_id': runtime,
      'profile': session.profile.key.value,
      'data_url': 'data:${piece.mediaType};base64,${base64Encode(piece.bytes)}',
      'name': piece.name,
    });
    final attached = result['attached'];
    if (attached is! bool) {
      return const _AttachResult(
        present: false,
        accepted: false,
        error: 'invalid_response',
      );
    }
    if (!attached) {
      return const _AttachResult(
        present: true,
        accepted: false,
        error: 'not-attached',
      );
    }
    final references = _strings([
      result['ref_text'],
      result['ref_path'],
      result['name'],
    ]);
    final promptRef = _firstNonEmpty([
      result['ref_text'],
      result['ref_path'],
      result['name'],
    ]);
    if (promptRef == null) {
      return const _AttachResult(
        present: true,
        accepted: false,
        error: 'missing-reference',
      );
    }
    return _AttachResult(
      present: true,
      accepted: true,
      references: references,
      promptRef: promptRef,
    );
  } on RpcError catch (error) {
    final missing = error.code == -32601;
    return _AttachResult(
      present: !missing,
      accepted: false,
      uncertain: !missing,
      error: missing ? 'method_missing' : 'rpc.${error.code}',
    );
  } on AppError catch (error) {
    return _AttachResult(
      present: false,
      accepted: false,
      uncertain: true,
      error: error.code,
    );
  }
}

Future<_AttachResult> _attachImageBytes(
  _Session session,
  String runtime,
  _Piece piece,
) async {
  try {
    final result = await session.rpc.call('image.attach_bytes', {
      'session_id': runtime,
      'profile': session.profile.key.value,
      'content_base64': base64Encode(piece.bytes),
      'filename': piece.name,
      'ext': piece.extension,
    });
    final attached = result['attached'];
    if (attached is! bool) {
      return const _AttachResult(
        present: false,
        accepted: false,
        error: 'invalid_response',
      );
    }
    if (!attached) {
      return const _AttachResult(
        present: true,
        accepted: false,
        error: 'not-attached',
      );
    }
    final references = _strings([
      result['text'],
      result['name'],
      result['path'],
    ]);
    if (references.isEmpty) {
      return const _AttachResult(
        present: true,
        accepted: false,
        error: 'missing-reference',
      );
    }
    return _AttachResult(
      present: true,
      accepted: true,
      references: references,
      promptRef:
          _firstNonEmpty([result['text'], result['name'], result['path']]) ??
          '',
    );
  } on RpcError catch (error) {
    final missing = error.code == -32601;
    return _AttachResult(
      present: !missing,
      accepted: false,
      uncertain: !missing,
      error: missing ? 'method_missing' : 'rpc.${error.code}',
    );
  } on AppError catch (error) {
    return _AttachResult(
      present: false,
      accepted: false,
      uncertain: true,
      error: error.code,
    );
  }
}

Future<_AttachResult> _attachImageRest(
  _Session session,
  String runtime,
  _Piece piece,
) async {
  final query = Uri(queryParameters: {'profile': session.profile.key.value})
      .query;
  final uri = session.origin.resolve('/api/chat/image-upload?$query');
  final body = {
    'data_url': 'data:${piece.mediaType};base64,${base64Encode(piece.bytes)}',
    'filename': piece.name,
  };
  TransportResponse upload;
  try {
    upload = await session.transport.request(
      uri,
      method: 'POST',
      body: body,
      bearer: session.access,
    );
    if ((upload.status == 401 || upload.status == 403) &&
        await session.renewAccess()) {
      upload = await session.transport.request(
        uri,
        method: 'POST',
        body: body,
        bearer: session.access,
      );
    }
  } catch (_) {
    return const _AttachResult(
      present: false,
      accepted: false,
      uncertain: true,
      error: 'upload.unreachable',
    );
  }
  if (const {404, 405, 501}.contains(upload.status)) {
    return const _AttachResult(
      present: false,
      accepted: false,
      error: 'method_missing',
    );
  }
  if (upload.status != 200) {
    final fileRefusal = upload.status == 413;
    return _AttachResult(
      present: true,
      accepted: false,
      uncertain: !fileRefusal,
      error: 'http.${upload.status}',
    );
  }
  final path = upload.body['path'];
  final name = upload.body['name'];
  if (upload.body['ok'] != true || path is! String || path.isEmpty) {
    return const _AttachResult(
      present: true,
      accepted: false,
      uncertain: true,
      error: 'invalid_response',
    );
  }
  try {
    final attached = await session.rpc.call('image.attach', {
      'session_id': runtime,
      'profile': session.profile.key.value,
      'path': path,
    });
    if (attached['attached'] != true) {
      return _AttachResult(
        present: true,
        accepted: false,
        uncertain: attached['attached'] != false,
        error: 'attach.not-attached',
        references: _strings([path, name]),
      );
    }
    final references = _strings([
      path,
      name,
      attached['text'],
      attached['name'],
      attached['path'],
    ]);
    return _AttachResult(
      present: true,
      accepted: true,
      references: references,
      promptRef:
          _firstNonEmpty([attached['text'], attached['name'], name, path]) ??
          path,
    );
  } on RpcError catch (error) {
    final missing = error.code == -32601;
    return _AttachResult(
      present: !missing,
      accepted: false,
      uncertain: !missing,
      error: missing ? 'method_missing' : 'rpc.${error.code}',
      references: _strings([path, name]),
    );
  } on AppError catch (error) {
    return _AttachResult(
      present: true,
      accepted: false,
      uncertain: true,
      error: error.code,
      references: _strings([path, name]),
    );
  }
}

String _prompt(String surface, List<_Attachment> attachments, String token) {
  if (surface == 'rest.image-upload' || surface == 'image.attach_bytes') {
    return 'Décris cette image en un seul mot. [mesure:$token]';
  }
  final refs = attachments
      .map((attachment) => attachment.promptRef)
      .where((reference) => reference.isNotEmpty)
      .toSet();
  final prefix = refs.isEmpty ? '' : '${refs.join(' ')}\n';
  return '${prefix}Mesure technique, réponse courte. [mesure:$token]';
}

String _token() {
  final random = Random.secure();
  final bytes = List<int>.generate(8, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

Future<_Receipt> _readReceipt(
  _Session session,
  String surface,
  String runtime,
  String token,
  List<_Attachment> attachments,
) async {
  for (var attempt = 0; attempt < _receiptAttempts; attempt++) {
    try {
      final result = await session.rpc.call(
        'session.history',
        HermesRpc.historyParams(runtime),
      );
      final messages = result['messages'];
      if (messages is List) {
        for (final message in messages) {
          if (message is! Map || message['role'] != 'user') continue;
          final content = _messageText(message);
          if (content == null || !content.contains(token)) continue;
          final verdict = receiptVerdict(
            surface: surface,
            content: content,
            submittedPrompt: _prompt(surface, attachments, token),
            attachments: [
              for (final attachment in attachments) attachment.references,
            ],
          );
          if (!verdict.confirmed) continue;
          return _Receipt(
            confirmed: true,
            receipt: verdict.receipt,
            received: verdict.received,
            text: _assistantText(messages),
            status: session.rpc.turnStatus(runtime),
          );
        }
      }
    } catch (_) {
      // Relecture impossible pour l'instant ; nouvel essai borné.
    }
    await Future<void>.delayed(_receiptDelay);
  }
  return const _Receipt();
}

String? _messageText(Map message) {
  final content = message['content'];
  if (content is String) return content;
  final text = message['text'];
  return text is String ? text : null;
}

/// Décide si un message utilisateur porte une preuve rédigée par le serveur.
///
/// L'écho de la référence dans le prompt soumis ne compte jamais : seule la
/// section d'attachement ajoutée par Hermes, ou ses lignes `@image:`, prouve la
/// réception. Un message dont aucune pièce n'apparaît reste non confirmé.
({bool confirmed, String? receipt, int received}) receiptVerdict({
  required String surface,
  required String content,
  required List<List<String>> attachments,
  String? submittedPrompt,
}) {
  final none = (confirmed: false, receipt: null, received: 0);
  if (attachments.isEmpty) return none;
  final imageSurface =
      surface == 'rest.image-upload' || surface == 'image.attach_bytes';
  final serverContent = submittedPrompt == null || submittedPrompt.isEmpty
      ? content
      : content.replaceAll(submittedPrompt, '');
  final String haystack;
  if (imageSurface) {
    final images = RegExp(r'@image:[^\s]+')
        .allMatches(serverContent)
        .map((match) => match.group(0)!)
        .toList();
    if (images.isEmpty) return none;
    var received = 0;
    for (final references in attachments) {
      final index = images.indexWhere(
        (image) => references.any(
          (reference) =>
              reference.isNotEmpty &&
              image ==
                  (reference.startsWith('@image:')
                      ? reference
                      : '@image:$reference'),
        ),
      );
      if (index >= 0) {
        // Une occurrence exacte ne peut prouver qu'une seule copie.
        images.removeAt(index);
        received++;
      }
    }
    return received == 0
        ? none
        : (
            confirmed: true,
            receipt: 'history-image-reference',
            received: received,
          );
  } else {
    const marker = '--- Attached Context ---';
    final index = serverContent.indexOf(marker);
    if (index < 0) return none;
    haystack = serverContent.substring(index);
  }
  var received = 0;
  for (final references in attachments) {
    if (references.any(
      (reference) => reference.isNotEmpty && haystack.contains(reference),
    )) {
      received++;
    }
  }
  if (received == 0) return none;
  return (
    confirmed: true,
    receipt: imageSurface
        ? 'history-image-reference'
        : 'history-attached-context',
    received: received,
  );
}

String? _assistantText(List<dynamic> messages) {
  final parts = <String>[];
  for (final message in messages) {
    if (message is! Map || message['role'] != 'assistant') continue;
    final text = message['text'];
    final content = message['content'];
    if (text is String && text.isNotEmpty) {
      parts.add(text);
    } else if (content is String && content.isNotEmpty) {
      parts.add(content);
    }
  }
  return parts.isEmpty ? null : parts.join('\n');
}

/// Interprète la réponse du modèle : refus explicite, marqueur observé,
/// réponse contradictoire ou rien.
({bool? analyzes, String evidence}) visionVerdict({
  required String answer,
  required String? marker,
}) {
  final normalized = answer.toLowerCase().replaceAll('’', "'");
  final expected = marker?.trim().toLowerCase();
  final hasMarker =
      expected != null && expected.isNotEmpty && normalized.contains(expected);
  final denies = _deniesVision(normalized);
  if (hasMarker && denies) {
    return (analyzes: null, evidence: 'ambiguous');
  }
  if (denies) {
    return (analyzes: false, evidence: 'denial');
  }
  if (hasMarker) {
    return (analyzes: true, evidence: 'marker');
  }
  return (analyzes: null, evidence: 'unobserved');
}

_Vision? _vision(_Rpc rpc, String runtime, String? text, String? marker) {
  final model = rpc.modelFor(runtime);
  if (rpc.turnStatus(runtime) != 'complete' || text == null || text.isEmpty) {
    return _Vision(model: model);
  }
  final verdict = visionVerdict(answer: text, marker: marker);
  return _Vision(
    model: model,
    analyzes: verdict.analyzes,
    evidence: verdict.analyzes == null ? null : verdict.evidence,
  );
}

bool _deniesVision(String answer) {
  const patterns = [
    'je ne peux pas voir',
    'je ne vois pas',
    "je ne vois pas d'image",
    "je ne peux pas voir l'image",
    'aucune image',
    "pas d'image",
    'image non disponible',
    'impossible de voir',
    'cannot see',
    "can't see",
    'can not see',
    'not able to view',
    'no image',
  ];
  return patterns.any(answer.contains);
}

Map<String, dynamic> _corpusCategory(String category, List<_Piece> pieces) {
  final matching = pieces.where((piece) => piece.category == category).toList();
  return {
    'category': category,
    'description': _descriptions[category],
    'pieces': matching.isEmpty ? null : matching.length,
    'totalBytes': matching.isEmpty
        ? null
        : matching.fold<int>(0, (total, piece) => total + piece.bytes.length),
    'mediaTypes': _sortedStrings(matching.map((piece) => piece.mediaType)),
  };
}

Map<String, dynamic> _contract(
  List<_Observation> observations,
  List<_Piece> pieces,
  String build,
  String measuredAt,
  String finishedAt,
  int repetitions,
) {
  final measured = observations.isNotEmpty;
  final evidence = measured ? 'install-measured' : 'unmeasured';
  final complete = _categories.every(
    (category) => pieces.any((piece) => piece.category == category),
  );
  final install = {
    'build': measured ? build : null,
    'measuredAt': measured ? measuredAt : null,
    'finishedAt': measured ? finishedAt : null,
    'profile': _profileRole,
  };
  final corpus = {
    'location': _corpusLocation,
    'tracked': false,
    'complete': complete,
    'categories': [
      for (final category in _categories) _corpusCategory(category, pieces),
    ],
  };
  final transports = {
    for (final surface in _surfaces)
      surface: {
        ..._transportSources[surface]!,
        ..._transport(
          surface,
          observations.where((observation) => observation.surface == surface),
          measuredAt,
          repetitions,
        ),
      },
  };
  final limits = {
    for (final category in _categories)
      category: _limit(
        observations.where(
          (observation) => observation.piece.category == category,
        ),
        measuredAt,
      ),
  };
  final vision = _visionContract(observations);
  final unverified = <String>[];
  if (evidence != 'install-measured') unverified.add('install.evidence');
  if (install['build'] == null) unverified.add('install.build');
  if (install['measuredAt'] == null) unverified.add('install.measuredAt');
  if (install['finishedAt'] == null) unverified.add('install.finishedAt');
  if (!complete) unverified.add('corpus.complete');
  for (final surface in _surfaces) {
    if (transports[surface]!['status'] != 'present') {
      unverified.add('transports.$surface');
    }
  }
  for (final category in _categories) {
    final limit = limits[category]!;
    if (limit['maxBytesVerified'] != true) {
      unverified.add('limits.$category.maxBytes');
    }
    if (limit['maxCountVerified'] != true) {
      unverified.add('limits.$category.maxCount');
    }
  }
  if (vision['analyzesImages'] == null) {
    unverified.add('vision.analyzesImages');
  }
  if (vision['model'] == null) unverified.add('vision.model');
  return {
    'schemaVersion': 1,
    'evidence': evidence,
    'install': install,
    'corpus': corpus,
    'transports': transports,
    'limits': limits,
    'vision': vision,
    'unverified': unverified,
  };
}

Map<String, dynamic> _transport(
  String surface,
  Iterable<_Observation> observations,
  String measuredAt,
  int repetitions,
) {
  final group = observations.toList();
  final present = group.any((observation) => observation.present);
  final absent =
      group.isNotEmpty &&
      group.every(
        (observation) =>
            !observation.present && observation.error == 'method_missing',
      );
  final accepted = group
      .where(
        (observation) =>
            observation.outcome == Outcome.accepted &&
            observation.receipt != null,
      )
      .length;
  final status = absent
      ? 'absent'
      : present && accepted > 0
      ? 'present'
      : 'unverified';
  String? error;
  for (final observation in group) {
    if (observation.error != null) {
      error = observation.error;
      break;
    }
  }
  return {
    'status': status,
    'proof': group.isEmpty
        ? null
        : {
            'at': measuredAt,
            'pieces': group.length,
            'repetitions': repetitions,
            'attempts': group.fold<int>(
              0,
              (total, observation) => total + observation.attempts,
            ),
            'accepted': accepted,
            'refused': group
                .where((observation) => observation.outcome == Outcome.refused)
                .length,
            'unverified': group
                .where(
                  (observation) => observation.outcome == Outcome.unverified,
                )
                .length,
            'absent': group
                .where((observation) => observation.outcome == Outcome.absent)
                .length,
            'partial': group
                .where((observation) => observation.countAmbiguous)
                .length,
            'received': group.fold<int>(
              0,
              (total, observation) => total + observation.receivedCount,
            ),
            'receipts': _sortedStrings(
              group
                  .map((observation) => observation.receipt)
                  .whereType<String>(),
            ),
            'error': error,
          },
  };
}

/// Résume les observations d'une catégorie en limite vérifiée ou nulle.
///
/// `refusedCounts` n'est alimenté que par une sonde de comptage explicite.
/// La sonde actuelle ne l'utilise pas : un refus à la répétition suivante peut
/// être un plafond de nombre ou un plafond de volume cumulé.
Map<String, dynamic> summarizeLimit({
  required List<int> acceptedBytes,
  required List<int> refusedBytes,
  required List<int> acceptedCounts,
  required List<int> refusedCounts,
  required List<int> unverifiedBytes,
  required List<int> unverifiedCounts,
  required List<String> mediaTypes,
  required List<String> receipts,
  required List<Map<String, dynamic>> evidence,
  required String measuredAt,
}) {
  final byteCeiling = refusedBytes.isEmpty
      ? null
      : refusedBytes.reduce((a, b) => a < b ? a : b);
  final acceptable = acceptedBytes
      .where((bytes) => byteCeiling == null || bytes < byteCeiling)
      .toList();
  final maxBytes = acceptable.isEmpty
      ? null
      : acceptable.reduce((a, b) => a > b ? a : b);
  final maxBytesVerified = maxBytes != null;

  final countCeiling = refusedCounts.isEmpty
      ? null
      : refusedCounts.reduce((a, b) => a < b ? a : b);
  final maxCount =
      countCeiling != null &&
          countCeiling > 1 &&
          acceptedCounts.contains(countCeiling - 1)
      ? countCeiling - 1
      : null;
  final maxCountVerified = maxCount != null;

  final uniqueEvidence = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final entry in evidence) {
    final key =
        '${entry['surface']}|${entry['receipt']}|${entry['bytes']}|'
        '${entry['count']}';
    if (seen.add(key)) uniqueEvidence.add(entry);
  }

  return {
    'maxBytes': maxBytes,
    'maxBytesVerified': maxBytesVerified,
    'maxCount': maxCount,
    'maxCountVerified': maxCountVerified,
    'verified': maxBytesVerified || maxCountVerified,
    'threshold': {
      'bytes': maxBytes == null
          ? 'not-measured'
          : refusedBytes.isEmpty
          ? 'lower-bound'
          : 'between',
      'count': maxCount == null
          ? acceptedCounts.any((count) => count > 0)
                ? 'lower-bound'
                : 'not-measured'
          : 'between',
    },
    'observed': {
      'acceptedBytes': _sortedInts(acceptedBytes),
      'refusedBytes': _sortedInts(refusedBytes),
      'acceptedCounts': _sortedInts(acceptedCounts),
      'refusedCounts': _sortedInts(refusedCounts),
      'unverifiedBytes': _sortedInts(unverifiedBytes),
      'unverifiedCounts': _sortedInts(unverifiedCounts),
      'mediaTypes': _sortedStrings(mediaTypes),
      'receipts': _sortedStrings(receipts),
    },
    'evidence': uniqueEvidence,
  };
}

Map<String, dynamic> _limit(
  Iterable<_Observation> observations,
  String measuredAt,
) {
  final group = observations.toList();
  final acceptedBytes = <int>[];
  final refusedBytes = <int>[];
  final acceptedCounts = <int>[];
  final refusedCounts = <int>[];
  final unverifiedBytes = <int>[];
  final unverifiedCounts = <int>[];
  final mediaTypes = <String>{};
  final receipts = <String>{};
  final evidence = <Map<String, dynamic>>[];

  for (final surface in _surfaces) {
    final bySurface = group
        .where((observation) => observation.surface == surface)
        .toList();
    if (bySurface.isEmpty) continue;
    final baseline = bySurface.any(
      (observation) =>
          observation.outcome == Outcome.accepted &&
          observation.receipt != null &&
          observation.receivedCount > 0,
    );
    for (final observation in bySurface) {
      final acceptedHere =
          observation.outcome == Outcome.accepted &&
          observation.receipt != null &&
          observation.receivedCount > 0;
      if (acceptedHere) {
        acceptedBytes.add(observation.piece.bytes.length);
        acceptedCounts.add(observation.receivedCount);
        mediaTypes.add(observation.piece.mediaType);
        receipts.add('${observation.surface}:${observation.receipt}');
        evidence.add({
          'surface': observation.surface,
          'receipt': observation.receipt,
          'bytes': observation.piece.bytes.length,
          'count': observation.receivedCount,
          'at': measuredAt,
        });
      } else if (observation.acceptedCount > 0) {
        unverifiedBytes.add(observation.piece.bytes.length);
        unverifiedCounts.add(observation.acceptedCount);
      }

      if (observation.countAmbiguous && observation.acceptedCount > 0) {
        // Un refus à la répétition suivante ne distingue pas un plafond de
        // nombre d'un plafond de volume cumulé : il n'alimente pas maxCount.
        unverifiedCounts.add(observation.acceptedCount);
      }

      if (observation.outcome == Outcome.refused) {
        if (acceptedHere || baseline) {
          refusedBytes.add(observation.piece.bytes.length);
        } else {
          unverifiedBytes.add(observation.piece.bytes.length);
        }
      } else if (observation.outcome == Outcome.unverified ||
          observation.outcome == Outcome.absent) {
        if (observation.acceptedCount == 0) {
          unverifiedBytes.add(observation.piece.bytes.length);
        }
      }
    }
  }

  return summarizeLimit(
    acceptedBytes: acceptedBytes,
    refusedBytes: refusedBytes,
    acceptedCounts: acceptedCounts,
    refusedCounts: refusedCounts,
    unverifiedBytes: unverifiedBytes,
    unverifiedCounts: unverifiedCounts,
    mediaTypes: mediaTypes.toList(),
    receipts: receipts.toList(),
    evidence: evidence,
    measuredAt: measuredAt,
  );
}

Map<String, dynamic> _visionContract(List<_Observation> observations) {
  final measured = observations
      .where((observation) => observation.vision != null)
      .toList();
  if (measured.isEmpty) {
    return {
      'profile': null,
      'model': null,
      'analyzesImages': null,
      'evidence': null,
    };
  }
  final positive = measured
      .where((observation) => observation.vision!.analyzes == true)
      .toList();
  final negative = measured
      .where((observation) => observation.vision!.analyzes == false)
      .toList();
  final chosen = positive.isNotEmpty
      ? positive.first
      : negative.isNotEmpty
      ? negative.first
      : measured.first;
  final analyzes = positive.isNotEmpty
      ? true
      : negative.isNotEmpty
      ? false
      : null;
  String? model = chosen.vision!.model;
  if (model == null) {
    for (final observation in measured) {
      if (observation.vision!.model != null) {
        model = observation.vision!.model;
        break;
      }
    }
  }
  return {
    'profile': _profileRole,
    'model': model,
    'analyzesImages': analyzes,
    'evidence': analyzes == null ? null : chosen.vision!.evidence,
  };
}

bool hasUsableTransport(Map<String, dynamic> contract) {
  final transports = contract['transports'];
  if (transports is! Map) return false;
  final pinned = transports['file.attach'];
  if (pinned is! Map || pinned['status'] != 'present') return false;
  final proof = pinned['proof'];
  return proof is Map &&
      proof['accepted'] is int &&
      (proof['accepted'] as int) > 0;
}

String incompleteMeasurementMessage() =>
    'Mesure partielle : file.attach reste non confirmé ; le code 2 indique '
    'que le contrat global est incomplet. Les preuves des autres surfaces '
    'figurent dans le résultat.';

List<int> _sortedInts(Iterable<int> values) => values.toSet().toList()..sort();

List<String> _sortedStrings(Iterable<String> values) =>
    values.toSet().toList()..sort();

List<String> _strings(List<Object?> values) => _sortedStrings(
  values.whereType<String>().where((value) => value.isNotEmpty),
);

String? _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

bool _applies(String surface, String category) {
  if (surface == 'file.attach') return category != 'image';
  return category == 'image';
}

String? _category(String value) {
  return switch (value.toLowerCase()) {
    'text' || 'texte' || 'long-text' || 'long_texte' => 'text',
    'image' || 'photo' || 'capture' => 'image',
    'pdf' => 'pdf',
    'office' || 'bureau' || 'document' => 'office',
    _ => null,
  };
}

String? _surface(String value) {
  return switch (value) {
    'file.attach' || 'file' || 'attach' => 'file.attach',
    'rest.image-upload' ||
    'image.upload-rest' ||
    'image.rest' ||
    'upload-rest' => 'rest.image-upload',
    'image.attach_bytes' ||
    'image.rpc' ||
    'attach_bytes' => 'image.attach_bytes',
    _ => null,
  };
}

_Parsed _parse(List<String> args) {
  var help = false;
  String? profile;
  String? output;
  String? visionMarker;
  var repetitions = 1;
  final pieces = <_PieceRef>[];
  final paths = <String>{};
  final surfaces = <String>{};
  String? error;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--aide' || arg == '--help' || arg == '-h') {
      help = true;
      continue;
    }
    if (arg == '--profil-de-test') {
      final value = index + 1 < args.length ? args[++index] : null;
      if (value == null || value.isEmpty) {
        error = '--profil-de-test attend une valeur.';
        break;
      }
      profile = value;
      continue;
    }
    if (arg == '--piece') {
      final value = index + 1 < args.length ? args[++index] : null;
      if (value == null) {
        error = '--piece attend categorie=chemin.';
        break;
      }
      final separator = value.indexOf('=');
      if (separator <= 0 || separator == value.length - 1) {
        error = '--piece attend categorie=chemin.';
        break;
      }
      final category = _category(value.substring(0, separator));
      if (category == null) {
        error = 'Catégorie de pièce inconnue (text, image, pdf, office).';
        break;
      }
      final path = value.substring(separator + 1);
      if (paths.add('$category\u0000$path')) {
        pieces.add(_PieceRef(category: category, path: path));
      }
      continue;
    }
    if (arg == '--surface') {
      final value = index + 1 < args.length ? args[++index] : null;
      final surface = value == null ? null : _surface(value);
      if (surface == null) {
        error =
            'Surface inconnue (file.attach, rest.image-upload, '
            'image.attach_bytes).';
        break;
      }
      surfaces.add(surface);
      continue;
    }
    if (arg == '--repetitions') {
      final value = index + 1 < args.length ? args[++index] : null;
      final count = value == null ? null : int.tryParse(value);
      if (count == null || count < 1 || count > _maxRepetitions) {
        error = '--repetitions attend un entier entre 1 et $_maxRepetitions.';
        break;
      }
      repetitions = count;
      continue;
    }
    if (arg == '--vision-marqueur') {
      final value = index + 1 < args.length ? args[++index] : null;
      if (value == null || value.trim().isEmpty) {
        error = '--vision-marqueur attend un texte non vide.';
        break;
      }
      visionMarker = value;
      continue;
    }
    if (arg == '--sortie') {
      final value = index + 1 < args.length ? args[++index] : null;
      if (value == null || value.isEmpty) {
        error = '--sortie attend un chemin.';
        break;
      }
      output = value;
      continue;
    }
    error = 'Argument inconnu.';
    break;
  }

  if (help) return const _Parsed(help: true);
  if (error != null) return _Parsed(error: error);
  if (profile == null) {
    return const _Parsed(error: '--profil-de-test est requis.');
  }
  if (pieces.isEmpty) {
    return const _Parsed(error: 'Au moins une --piece est requise.');
  }
  if (surfaces.isEmpty) surfaces.addAll(_surfaces);
  return _Parsed(
    options: _Options(
      profile: profile,
      pieces: pieces,
      surfaces: surfaces,
      repetitions: repetitions,
      output: output,
      visionMarker: visionMarker,
    ),
  );
}

const _usage =
    '''
Usage : dart run tool/mesure_pieces_jointes.dart [options]

Mesure les limites de fichiers sur une installation Hermes avec un profil de
test dédié. Aucun chemin, identifiant, nom de fichier ou contenu de fichier
n'est écrit dans la sortie.

Options :
  --aide                       Affiche cette aide, sans accès réseau.
  --profil-de-test <clé>       Profil de test dédié (jamais le profil personnel).
  --piece <catégorie>=<chemin> Pièce du corpus. Répétable.
                               Catégories : text, image, pdf, office.
  --surface <nom>              Surface à éprouver. Répétable.
                               file.attach, rest.image-upload, image.attach_bytes.
  --repetitions <n>            Pièces jointes par session et par pièce (1-$_maxRepetitions).
  --vision-marqueur <texte>    Mot attendu dans la réponse du modèle à l'image.
  --sortie <chemin>            Écrit le JSON dans ce fichier au lieu de stdout.

Environnement (valeurs jamais journalisées) :
  HERMES_URL                   Origine de l'installation.
  HERMES_PASSWORD              Mot de passe (ou HERMES_TOKEN).
  HERMES_TOKEN                 Jeton d'accès existant, optionnel.

Sortie : contrat JSON au format de contracts/file-limits.json.
Codes : 0 mesure consignée, 2 blocage, 64 arguments invalides.
''';

class _Parsed {
  const _Parsed({this.options, this.error, this.help = false});
  final _Options? options;
  final String? error;
  final bool help;
}

class _Options {
  const _Options({
    required this.profile,
    required this.pieces,
    required this.surfaces,
    required this.repetitions,
    required this.output,
    required this.visionMarker,
  });
  final String profile;
  final List<_PieceRef> pieces;
  final Set<String> surfaces;
  final int repetitions;
  final String? output;
  final String? visionMarker;
}

class _PieceRef {
  const _PieceRef({required this.category, required this.path});
  final String category;
  final String path;
}

class _Piece {
  const _Piece({
    required this.category,
    required this.name,
    required this.bytes,
    required this.extension,
    required this.mediaType,
  });
  final String category;
  final String name;
  final List<int> bytes;
  final String extension;
  final String mediaType;
}

class _Attachment {
  const _Attachment({required this.references, required this.promptRef});
  final List<String> references;
  final String promptRef;
}

class _AttachResult {
  const _AttachResult({
    required this.present,
    required this.accepted,
    this.uncertain = false,
    this.error,
    this.references = const [],
    this.promptRef = '',
  });
  final bool present;
  final bool accepted;
  final bool uncertain;
  final String? error;
  final List<String> references;
  final String promptRef;
}

enum Outcome { accepted, refused, absent, unverified }

class _Observation {
  const _Observation({
    required this.surface,
    required this.piece,
    required this.outcome,
    required this.present,
    this.acceptedCount = 0,
    this.error,
    this.receipt,
    this.vision,
    this.model,
    this.attempts = 0,
    this.receivedCount = 0,
    this.countAmbiguous = false,
  });
  final String surface;
  final _Piece piece;
  final Outcome outcome;
  final bool present;
  final int acceptedCount;
  final String? error;
  final String? receipt;
  final _Vision? vision;
  final String? model;
  final int attempts;
  final int receivedCount;
  final bool countAmbiguous;
}

class _Receipt {
  const _Receipt({
    this.confirmed = false,
    this.receipt,
    this.text,
    this.status,
    this.received = 0,
  });
  final bool confirmed;
  final String? receipt;
  final String? text;
  final String? status;
  final int received;
}

class _Vision {
  const _Vision({this.model, this.analyzes, this.evidence});
  final String? model;
  final bool? analyzes;
  final String? evidence;
}

class _Rpc {
  _Rpc(this.socket) {
    _subscription = socket.messages.listen(
      _onMessage,
      onError: (Object _) => _socketClosed(),
      onDone: _socketClosed,
    );
  }

  final GatewaySocket socket;
  final _ready = Completer<Map<String, dynamic>>();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _events = <_RpcEvent>[];
  StreamSubscription<Object?>? _subscription;
  Map<String, dynamic>? _readyPayload;
  bool _closed = false;
  int _sequence = 0;

  Future<Map<String, dynamic>> get ready => _ready.future;
  Map<String, dynamic>? get readyPayload => _readyPayload;

  void _onMessage(Object? raw) {
    try {
      final message = raw is String ? jsonDecode(raw) : raw;
      if (message is! Map) return;
      final params = message['params'];
      if (message['method'] == 'event' && params is Map) {
        final type = params['type'];
        if (type == 'gateway.ready') {
          final payload = params['payload'];
          if (payload is Map) {
            _readyPayload = Map<String, dynamic>.from(payload);
            if (!_ready.isCompleted) _ready.complete(_readyPayload!);
          }
          return;
        }
        final session = params['session_id'];
        if (session is String && type is String) {
          final payload = params['payload'];
          _events.add(
            _RpcEvent(
              session: session,
              type: type,
              payload: payload is Map
                  ? Map<String, dynamic>.from(payload)
                  : const {},
            ),
          );
        }
        return;
      }
      final id = message['id'];
      if (id is String && _pending.containsKey(id)) {
        final done = _pending.remove(id)!;
        final rpcError = message['error'];
        final result = message['result'];
        if (rpcError is Map) {
          final code = rpcError['code'];
          done.completeError(RpcError(code is int ? code : -1));
        } else if (result is Map) {
          done.complete(Map<String, dynamic>.from(result));
        } else {
          done.completeError(const AppError('contract.invalid_response'));
        }
      }
    } catch (_) {
      // Trame illisible : ignorée, jamais journalisée.
    }
  }

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = _probeTimeout,
  }) async {
    if (_closed) throw const AppError('transport.websocket');
    final id = 'mesure-${++_sequence}';
    final done = Completer<Map<String, dynamic>>();
    _pending[id] = done;
    try {
      socket.send({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      });
    } catch (_) {
      _pending.remove(id);
      throw const AppError('rpc.uncertain');
    }
    try {
      return await done.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      throw const AppError('rpc.uncertain');
    }
  }

  Future<void> waitFor(
    String session,
    Set<String> types,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_closed) throw const AppError('transport.websocket');
      if (_events.any(
        (event) => event.session == session && types.contains(event.type),
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw TimeoutException('measure.turn');
  }

  String? turnStatus(String session) {
    for (final event in _events.reversed) {
      if (event.session != session || event.type != 'message.complete') {
        continue;
      }
      final status = event.payload['status'];
      return status is String ? status : null;
    }
    return null;
  }

  String? modelFor(String session) {
    for (final event in _events.reversed) {
      if (event.session != session || event.type != 'message.complete') {
        continue;
      }
      final usage = event.payload['usage'];
      if (usage is Map) {
        final model = usage['model'];
        if (model is String && model.isNotEmpty) return model;
      }
    }
    return null;
  }

  void _socketClosed() {
    _closed = true;
    if (!_ready.isCompleted) {
      _ready.completeError(const AppError('transport.websocket'));
    }
    for (final done in _pending.values) {
      if (!done.isCompleted) {
        done.completeError(const AppError('transport.websocket'));
      }
    }
    _pending.clear();
  }

  Future<void> close() async {
    _closed = true;
    try {
      await _subscription?.cancel();
    } catch (_) {}
    try {
      await socket.close();
    } catch (_) {}
  }
}

class _RpcEvent {
  const _RpcEvent({
    required this.session,
    required this.type,
    required this.payload,
  });
  final String session;
  final String type;
  final Map<String, dynamic> payload;
}

class _Blocked implements Exception {
  const _Blocked(this.reason);
  final String reason;
}
