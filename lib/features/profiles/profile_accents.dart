import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/connection_gateway.dart';
import '../../models/profile.dart';
import '../../models/profile_accent.dart';

/// Couleur de chaque profil de la connexion courante : choisie et stockée,
/// sinon [ProfileAccent.defaultFor]. Lue à la demande, mise en cache.
class ProfileAccents extends ChangeNotifier {
  ProfileAccents(this.gateway, [ProfileAccentStore? store])
    : store = store ?? MemoryProfileAccentStore();
  final ConnectionGateway gateway;
  final ProfileAccentStore store;
  final _cache = <ProfileIdentity, ProfileAccent>{};
  final _requested = <ProfileIdentity>{};
  bool _disposed = false;

  ProfileIdentity? _identity(ProfileKey profile) {
    final connection = gateway.snapshot.connection;
    return connection == null
        ? null
        : ProfileIdentity(connection.origin, connection.key, profile);
  }

  ProfileAccent of(ProfileKey profile) {
    final identity = _identity(profile);
    if (identity == null) return ProfileAccent.defaultFor(profile);
    final cached = _cache[identity];
    if (cached != null) return cached;
    if (_requested.add(identity)) {
      unawaited(
        store.read(identity).then((value) {
          if (_disposed || value == null || _cache.containsKey(identity)) {
            return;
          }
          _cache[identity] = value;
          notifyListeners();
        }, onError: (Object _) {}),
      );
    }
    return ProfileAccent.defaultFor(profile);
  }

  /// Affichée tout de suite ; l'ancienne revient si l'écriture échoue.
  Future<void> choose(ProfileKey profile, ProfileAccent accent) async {
    final identity = _identity(profile);
    if (identity == null) return;
    final previous = _cache[identity];
    _cache[identity] = accent;
    notifyListeners();
    try {
      await store.save(identity, accent);
    } catch (_) {
      if (_disposed) return;
      if (previous == null) {
        _cache.remove(identity);
      } else {
        _cache[identity] = previous;
      }
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
