import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the Anthropic API key in the platform secure store (Keychain on iOS,
/// Keystore on Android).
class ApiKeyStore {
  ApiKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'anthropic_api_key';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  Future<void> delete() => _storage.delete(key: _key);
}
