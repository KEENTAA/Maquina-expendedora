import '../../core/config/app_config.dart';
import '../../core/network/http_api_client.dart';

class SimuPayApiService {
  final HttpApiClient _http;

  SimuPayApiService({HttpApiClient? http}) : _http = http ?? HttpApiClient();

  Future<Map<String, dynamic>> getWallet(String email) {
    return _http.getJson(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/$email'),
    );
  }

  Future<Map<String, dynamic>> createWallet(String email) {
    return _http.postJson(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets'),
      body: {'email': email, 'initial_balance': 0},
    );
  }

  Future<Map<String, dynamic>> getWalletMovements(String email) {
    return _http.getJson(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/$email/transactions'),
    );
  }

  Future<Map<String, dynamic>> transfer({
    required String from,
    required String to,
    required double amount,
  }) {
    return _http.postJson(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/transfer'),
      body: {'from_email': from, 'to_email': to, 'amount': amount},
    );
  }

  Future<Map<String, dynamic>> payQr({
    required String from,
    required String qrData,
    double? amount,
  }) {
    return _http.postJson(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/pay-qr'),
      body: {'from_email': from, 'qr_data': qrData, 'amount': amount},
    );
  }

  Future<Map<String, dynamic>> paySessionWithWallet({
    required String providerTransactionId,
    required String fromEmail,
  }) {
    return _http.postJson(
      Uri.parse(
        '${AppConfig.simupayUrl}/api/v1/payments/$providerTransactionId/pay-wallet',
      ),
      body: {'from_email': fromEmail},
    );
  }
}
