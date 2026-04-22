import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthSession? _session;
  bool _loading = false;
  String? _error;

  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  String? get error => _error;
  AuthSession? get session => _session;

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    try {
      final ip = await _authRepository.loadIp();
      if (ip != null) {
        AppConfig.baseUrl = ip;
      }
      _session = await _authRepository.loadSession();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    String? serverIp,
  }) async {
    _setLoading();
    try {
      if (serverIp != null && serverIp.trim().isNotEmpty) {
        AppConfig.baseUrl = serverIp;
        await _authRepository.saveIp(serverIp);
      }
      _session = await _authRepository.login(email: email, password: password);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _clearLoading();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? serverIp,
  }) async {
    _setLoading();
    try {
      if (serverIp != null && serverIp.trim().isNotEmpty) {
        AppConfig.baseUrl = serverIp;
        await _authRepository.saveIp(serverIp);
      }
      _session = await _authRepository.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _clearLoading();
    }
  }

  Future<bool> linkSimupay(String simupayEmail) async {
    if (_session == null) return false;
    _setLoading();
    try {
      _session = await _authRepository.linkSimupay(
        email: _session!.email,
        simupayEmail: simupayEmail,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _clearLoading();
    }
  }

  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    await _authRepository.logout();
    _session = null;
    _loading = false;
    notifyListeners();
  }

  void _setLoading() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void _clearLoading() {
    _loading = false;
    notifyListeners();
  }
}
