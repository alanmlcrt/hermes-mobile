import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/profile.dart';

class ProfilesViewModel extends ChangeNotifier {
  ProfilesViewModel(this.gateway) {
    _subscription = gateway.snapshots.listen((_) => notifyListeners());
  }
  final ConnectionGateway gateway;
  late final StreamSubscription<ConnectionSnapshot> _subscription;
  ConnectionSnapshot get snapshot => gateway.snapshot;
  Future<void> refresh() => gateway.refreshProfiles();
  Future<void> select(ProfileKey key) => gateway.selectProfile(key);
  Future<void> reconnect() => gateway.reconnect();
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
