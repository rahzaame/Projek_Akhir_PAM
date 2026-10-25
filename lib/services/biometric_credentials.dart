import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricCredentials {
  static const String _emailKey = 'biometric_email';
  static const String _passwordKey = 'biometric_password';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save({required String email, required String password}) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<({String email, String password})?> read() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || email.isEmpty || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
