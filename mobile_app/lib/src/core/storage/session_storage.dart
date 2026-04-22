import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_session.dart';

class SessionStorage {
  static const _tokenKey = 'session_token';
  static const _emailKey = 'session_email';
  static const _roleKey = 'session_role';
  static const _simupayEmailKey = 'session_simupay_email';

  final FlutterSecureStorage _storage;

  SessionStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _tokenKey, value: session.accessToken);
    await _storage.write(key: _emailKey, value: session.email);
    await _storage.write(key: _roleKey, value: session.role);
    if (session.simupayEmail != null) {
      await _storage.write(key: _simupayEmailKey, value: session.simupayEmail);
    } else {
      await _storage.delete(key: _simupayEmailKey);
    }
  }

  Future<AuthSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final email = await _storage.read(key: _emailKey);
    final role = await _storage.read(key: _roleKey);
    final simupayEmail = await _storage.read(key: _simupayEmailKey);
    if (token == null || email == null || role == null) return null;
    return AuthSession(
      accessToken: token,
      email: email,
      role: role,
      simupayEmail: simupayEmail,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _simupayEmailKey);
  }
}
