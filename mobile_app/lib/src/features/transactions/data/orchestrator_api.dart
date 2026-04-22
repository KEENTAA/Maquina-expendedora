import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import 'models/transaction_view.dart';

class OrchestratorApi {
  final http.Client _client;

  OrchestratorApi({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${AppConfig.orchestratorUrl}$path');

  Future<TransactionView> createTransaction({
    required String userId,
    required String machineId,
    required String productId,
    required double amount,
  }) async {
    final res = await _client.post(
      _uri('/api/v1/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'machine_id': machineId,
        'product_id': productId,
        'amount': amount,
      }),
    );
    _ensureSuccess(res);
    return TransactionView.fromJson(jsonDecode(res.body));
  }

  Future<TransactionView> generateQr(String transactionId) async {
    final res = await _client.post(
      _uri('/api/v1/transactions/$transactionId/generate-qr'),
    );
    _ensureSuccess(res);
    return TransactionView.fromJson(jsonDecode(res.body));
  }

  Future<TransactionView> confirmPayment(String transactionId) async {
    final res = await _client.post(
      _uri('/api/v1/transactions/$transactionId/payment-confirmed'),
    );
    _ensureSuccess(res);
    return TransactionView.fromJson(jsonDecode(res.body));
  }

  Future<TransactionView> setDispenseResult(
    String transactionId,
    bool success,
  ) async {
    final res = await _client.post(
      _uri('/api/v1/transactions/$transactionId/dispense-result'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'success': success}),
    );
    _ensureSuccess(res);
    return TransactionView.fromJson(jsonDecode(res.body));
  }

  Future<List<TransactionView>> listTransactions(String userId) async {
    final res = await _client.get(_uri('/api/v1/transactions?user_id=$userId'));
    _ensureSuccess(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items =
        (body['items'] as List<dynamic>)
            .map((e) => TransactionView.fromJson(e as Map<String, dynamic>))
            .toList();
    return items;
  }

  void _ensureSuccess(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('Orchestrator error ${res.statusCode}: ${res.body}');
  }
}
