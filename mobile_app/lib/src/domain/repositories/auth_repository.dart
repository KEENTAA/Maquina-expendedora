import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  });
  Future<AuthSession?> loadSession();
  Future<void> logout();

  Future<AuthSession> linkSimupay({
    required String email,
    required String simupayEmail,
  });

  Future<void> saveIp(String ip);
  Future<String?> loadIp();
}
