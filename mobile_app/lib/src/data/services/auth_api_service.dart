import '../../core/config/app_config.dart';
import '../../core/network/http_api_client.dart';

class AuthApiService {
  final HttpApiClient _http;

  AuthApiService({HttpApiClient? http}) : _http = http ?? HttpApiClient();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _http.postJson(
      Uri.parse('${AppConfig.authUrl}/api/v1/auth/login'),
      body: {'email': email, 'password': password},
    );
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _http.postJson(
      Uri.parse('${AppConfig.authUrl}/api/v1/auth/register'),
      body: {'email': email, 'password': password, 'full_name': fullName},
    );
  }

  Future<Map<String, dynamic>> linkSimupay({
    required String email,
    required String simupayEmail,
  }) {
    return _http.postJson(
      Uri.parse('${AppConfig.authUrl}/api/v1/auth/link-simupay'),
      body: {'email': email, 'simupay_email': simupayEmail},
    );
  }
}
