import 'package:supabase_flutter/supabase_flutter.dart';

import 'custom_encryption.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  static const int maxPasswordLength = 50;

  String _protect(String password) => CustomEncryption.encrypt(password);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: _protect(password),
      );
    } on AuthApiException catch (e) {
      final pesan = e.message.toLowerCase();
      if (pesan.contains('confirm') || pesan.contains('rate limit')) {
        rethrow;
      }
      if (e.statusCode != '400') rethrow;
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: _protect(password),
      data: data,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: _protect(newPassword)),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;
}
