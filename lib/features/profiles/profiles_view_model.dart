import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/profile.dart';
import '../../models/companion_background.dart';

class ProfilesViewModel extends ChangeNotifier {
  ProfilesViewModel(this.gateway, {CompanionBackgroundStore? backgrounds})
    : backgrounds = backgrounds ?? const DefaultCompanionBackgroundStore() {
    _subscription = gateway.snapshots.listen((_) {
      _syncBackground();
      notifyListeners();
    });
    _syncBackground();
  }
  final CompanionBackgroundStore backgrounds;
  CompanionBackgroundIdentity? backgroundIdentity;
  CompanionPalette palette = CompanionPalette.lavenderPeach;
  bool backgroundLoading = false;
  bool backgroundError = false;
  bool _disposed = false;
  int _readGeneration = 0;
  final _writes = <Future<void>>{};
  Future<void> get backgroundWritesDone =>
      Future.wait(_writes.map((write) => write.catchError((Object _) {})));
  CompanionBackgroundIdentity? _verifiedIdentity;
  CompanionBackgroundIdentity? get _selection {
    final state = snapshot;
    final connection = state.connection;
    final profile = state.selectedProfile;
    if (connection == null || profile == null) {
      _verifiedIdentity = null;
      return null;
    }
    final identity = CompanionBackgroundIdentity(
      connection.origin,
      connection.key,
      profile,
    );
    final loading =
        state.profilesState == ProfilesState.loading ||
        state.profilesState == ProfilesState.refreshing;
    if (state.profiles.any((p) => p.key == profile) ||
        (loading && identity == _verifiedIdentity)) {
      return _verifiedIdentity = identity;
    }
    _verifiedIdentity = null;
    return null;
  }

  void _syncBackground() {
    final identity = _selection;
    if (identity == backgroundIdentity) return;
    backgroundIdentity = identity;
    _readGeneration++;
    palette = CompanionPalette.lavenderPeach;
    backgroundError = false;
    backgroundLoading = identity != null;
    if (identity != null) unawaited(loadBackground());
  }

  Future<void> loadBackground() async {
    final identity = backgroundIdentity;
    if (identity == null) return;
    final generation = ++_readGeneration;
    backgroundLoading = true;
    backgroundError = false;
    notifyListeners();
    try {
      final value = await backgrounds.read(identity);
      if (_disposed || generation != _readGeneration) return;
      palette = value;
    } catch (_) {
      if (_disposed || generation != _readGeneration) return;
      backgroundError = true;
    }
    if (_disposed || generation != _readGeneration) return;
    backgroundLoading = false;
    notifyListeners();
  }

  Future<void> saveBackground(
    CompanionBackgroundIdentity identity,
    CompanionPalette value,
  ) async {
    if (_disposed ||
        identity != backgroundIdentity ||
        backgroundLoading ||
        backgroundError) {
      throw StateError('Background identity is no longer editable');
    }
    final generation = _readGeneration;
    final write = backgrounds.save(identity, value);
    _writes.add(write);
    try {
      await write;
    } finally {
      _writes.remove(write);
    }
    if (_disposed ||
        identity != backgroundIdentity ||
        generation != _readGeneration) {
      return;
    }
    _readGeneration++;
    backgroundLoading = false;
    backgroundError = false;
    palette = value;
    notifyListeners();
  }

  final ConnectionGateway gateway;
  late final StreamSubscription<ConnectionSnapshot> _subscription;
  ConnectionSnapshot get snapshot => gateway.snapshot;
  Future<void> refresh() => gateway.refreshProfiles();
  Future<void> select(ProfileKey key) => gateway.selectProfile(key);
  Future<void> reconnect() => gateway.reconnect();
  @override
  void dispose() {
    _disposed = true;
    _readGeneration++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
