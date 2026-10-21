import 'dart:math';

import 'app_error.dart';
import 'profile.dart';

class ConnectionKey {
  const ConnectionKey(this.value);
  factory ConnectionKey.create() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return ConnectionKey(
      '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
    );
  }
  final String value;
  @override
  bool operator ==(Object other) =>
      other is ConnectionKey && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

/// Validation commune au clavier, deep link et générateur QR.
Uri parseOrigin(String input) {
  try {
    var uri = Uri.parse(input.trim());
    if (uri.scheme == 'hermes-mobile') {
      if (uri.host != 'pair' ||
          (uri.path.isNotEmpty && uri.path != '/') ||
          uri.hasFragment ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          uri.queryParametersAll.length != 1 ||
          uri.queryParametersAll['url']?.length != 1) {
        throw const AppError('connection.invalid_origin');
      }
      uri = Uri.parse(uri.queryParameters['url']!);
    }
    final host = uri.host.toLowerCase();
    final validHost =
        host.isNotEmpty && !host.contains('%') && !RegExp(r'\s').hasMatch(host);
    if (!validHost ||
        uri.authority.contains('@') ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                host.endsWith('.ts.net') &&
                host.length > '.ts.net'.length)) ||
        (uri.hasPort && (uri.port < 1 || uri.port > 65535))) {
      throw const AppError('connection.invalid_origin');
    }
    return uri.replace(path: '');
  } on AppError {
    rethrow;
  } catch (_) {
    throw const AppError('connection.invalid_origin');
  }
}

class Connection {
  const Connection({
    required this.key,
    required this.origin,
    this.selectedProfile,
  });
  final ConnectionKey key;
  final Uri origin;
  final ProfileKey? selectedProfile;
}

enum LinkState { offline, resyncing, connected }

enum ProfilesState { initial, loading, ready, empty, error, refreshing }

enum CapabilityState { present, absent, unverified }

class Capability {
  const Capability(this.name, this.state, {this.required = false});
  final String name;
  final CapabilityState state;
  final bool required;
}

class ConnectionSnapshot {
  ConnectionSnapshot({
    this.connection,
    this.link = LinkState.offline,
    this.profilesState = ProfilesState.initial,
    List<Profile> profiles = const [],
    List<Capability> capabilities = const [],
    this.selectedProfile,
    this.error,
    this.busy = false,
    this.authenticated = false,
  }) : profiles = List.unmodifiable(profiles),
       capabilities = List.unmodifiable(capabilities);
  final Connection? connection;
  final LinkState link;
  final ProfilesState profilesState;
  final List<Profile> profiles;
  final List<Capability> capabilities;
  final ProfileKey? selectedProfile;
  final AppError? error;
  final bool busy;
  final bool authenticated;
  bool get acceptanceOpen =>
      capabilities.any((c) => c.required && c.state != CapabilityState.present);

  ConnectionSnapshot copyWith({
    Connection? connection,
    LinkState? link,
    ProfilesState? profilesState,
    List<Profile>? profiles,
    List<Capability>? capabilities,
    ProfileKey? selectedProfile,
    bool clearSelection = false,
    AppError? error,
    bool clearError = false,
    bool? busy,
    bool? authenticated,
  }) => ConnectionSnapshot(
    connection: connection ?? this.connection,
    link: link ?? this.link,
    profilesState: profilesState ?? this.profilesState,
    profiles: profiles ?? this.profiles,
    capabilities: capabilities ?? this.capabilities,
    selectedProfile: clearSelection
        ? null
        : selectedProfile ?? this.selectedProfile,
    error: clearError ? null : error ?? this.error,
    busy: busy ?? this.busy,
    authenticated: authenticated ?? this.authenticated,
  );
}
