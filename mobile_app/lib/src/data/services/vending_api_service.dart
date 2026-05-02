import '../../core/config/app_config.dart';
import '../../core/network/http_api_client.dart';

class VendingApiService {
  final HttpApiClient _http;

  VendingApiService({HttpApiClient? http})
    : _http = http ?? HttpApiClient();

  Future<Map<String, dynamic>> listMachines({String? ownerEmail}) {
    final query = ownerEmail != null ? '?owner_email=$ownerEmail' : '';
    return _http.getJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines$query'),
    );
  }

  Future<Map<String, dynamic>> getInventory(String machineId) {
    return _http.getJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory'),
    );
  }

  Future<Map<String, dynamic>> updateInventoryPrice(String machineId, String slotOrId, double price) {
    // Note: The backend uses query params for price in the PATCH request based on ApiClient implementation
    return _http.patchJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory/$slotOrId/price?price=$price'),
    );
  }
}
