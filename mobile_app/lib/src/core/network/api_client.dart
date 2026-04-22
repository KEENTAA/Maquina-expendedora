import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiClient {
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('${AppConfig.authUrl}/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> wallet(String email) async {
    final res = await _client.get(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/$email'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transfer(
    String from,
    String to,
    double amount,
  ) async {
    final res = await _client.post(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/transfer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'from_email': from, 'to_email': to, 'amount': amount}),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> walletHistory(String email) async {
    final res = await _client.get(
      Uri.parse('${AppConfig.simupayUrl}/api/v1/wallets/$email/transactions'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> machines({String? ownerEmail}) async {
    final q = ownerEmail == null ? '' : '?owner_email=$ownerEmail';
    final res = await _client.get(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines$q'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> inventory(String machineId) async {
    final res = await _client.get(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProductPrice(String productId, double price) async {
    final res = await _client.patch(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/products/$productId/price?price=$price'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateInventoryPrice(String machineId, String slotOrId, double price) async {
    final res = await _client.patch(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory/$slotOrId/price?price=$price'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sales() async {
    final res = await _client.get(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/admin/sales'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> iotMachines() async {
    final res = await _client.get(
      Uri.parse('${AppConfig.iotUrl}/api/v1/iot/machines'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> iotTelemetry(String machineId) async {
    final res = await _client.get(
      Uri.parse('${AppConfig.iotUrl}/api/v1/iot/telemetry/$machineId'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> iotCommand(
    String machineId,
    String command,
  ) async {
    final res = await _client.post(
      Uri.parse('${AppConfig.iotUrl}/api/v1/iot/commands/$machineId/$command'),
    );
    _ensureSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensureSuccess(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
