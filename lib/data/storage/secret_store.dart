import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/connection.dart';

enum SecretUsage { password, accessToken, refreshToken, observerBearer }

abstract interface class SecretStore {
  Future<String?> read(ConnectionKey key, SecretUsage usage);
  Future<void> write(ConnectionKey key, SecretUsage usage, String value);
  Future<void> delete(ConnectionKey key, SecretUsage usage);
  Future<void> clear(ConnectionKey key);
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore(this.storage);
  final FlutterSecureStorage storage;
  String _key(ConnectionKey key, SecretUsage usage) =>
      '${key.value}/${usage.name}';
  @override
  Future<String?> read(ConnectionKey key, SecretUsage usage) =>
      storage.read(key: _key(key, usage));
  @override
  Future<void> write(ConnectionKey key, SecretUsage usage, String value) =>
      storage.write(key: _key(key, usage), value: value);
  @override
  Future<void> delete(ConnectionKey key, SecretUsage usage) =>
      storage.delete(key: _key(key, usage));
  @override
  Future<void> clear(ConnectionKey key) async {
    for (final usage in SecretUsage.values) {
      await storage.delete(key: _key(key, usage));
    }
  }
}
