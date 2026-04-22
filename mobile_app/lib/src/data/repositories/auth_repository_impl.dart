import '../../core/storage/session_storage.dart';
import '../../core/storage/settings_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/auth_api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiService _authApi;
  final SessionStorage _sessionStorage;
  final SettingsStorage _settingsStorage;

  AuthRepositoryImpl({
    AuthApiService? authApi,
    SessionStorage? sessionStorage,
    SettingsStorage? settingsStorage,
  }) : _authApi = authApi ?? AuthApiService(),
       _sessionStorage = sessionStorage ?? SessionStorage(),
       _settingsStorage = settingsStorage ?? SettingsStorage();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _authApi.login(email: email, password: password);
    final session = AuthSession(
      accessToken: data['access_token'] as String,
      email: data['email'] as String,
      role: data['role'] as String,
      simupayEmail: data['simupay_email'] as String?,
    );
    await _sessionStorage.save(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _authApi.register(
      email: email,
      password: password,
      fullName: fullName,
    );
    final session = AuthSession(
      accessToken: data['access_token'] as String,
      email: data['email'] as String,
      role: data['role'] as String,
      simupayEmail: data['simupay_email'] as String?,
    );
    await _sessionStorage.save(session);
    return session;
  }

  @override
  Future<AuthSession> linkSimupay({
    required String email,
    required String simupayEmail,
  }) async {
    await _authApi.linkSimupay(email: email, simupayEmail: simupayEmail);
    final current = await _sessionStorage.read();
    if (current != null) {
      final updated = AuthSession(
        accessToken: current.accessToken,
        email: current.email,
        role: current.role,
        simupayEmail: simupayEmail,
      );
      await _sessionStorage.save(updated);
      return updated;
    }
    throw Exception('No active session to link');
  }

  @override
  Future<AuthSession?> loadSession() => _sessionStorage.read();

  @override
  Future<void> logout() => _sessionStorage.clear();

  @override
  Future<void> saveIp(String ip) => _settingsStorage.saveIp(ip);

  @override
  Future<String?> loadIp() => _settingsStorage.readIp();
}
