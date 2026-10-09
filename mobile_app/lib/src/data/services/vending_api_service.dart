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
    return _http.patchJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory/$slotOrId/price?price=$price'),
    );
  }

  Future<Map<String, dynamic>> updateSlotStatus(String machineId, String slotOrId, bool isEnabled, String? slotType, {String? productName, String? newSlot}) {
    final Map<String, dynamic> body = {
      'is_enabled': isEnabled,
      'slot_type': slotType,
    };
    if (productName != null) {
      body['product_name'] = productName;
    }
    if (newSlot != null) {
      body['new_slot'] = newSlot;
    }
    return _http.patchJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory/$slotOrId/status'),
      body: body,
    );
  }

  Future<Map<String, dynamic>> createSlot(String machineId, {
    required String slot,
    required String productName,
    required double price,
    required int stock,
    int capacity = 20,
    String slotType = 'soda',
  }) {
    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/slots'),
      body: {
        'slot': slot,
        'product_name': productName,
        'price': price,
        'stock': stock,
        'capacity': capacity,
        'slot_type': slotType,
      },
    );
  }

  Future<Map<String, dynamic>> reorderSlots(String machineId, List<String> orderedSlots) {
    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/reorder-slots'),
      body: {
        'ordered_slots': orderedSlots,
      },
    );
  }


  Future<Map<String, dynamic>> getBanner() {
    return _http.getJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/settings/banner'),
    );
  }

  Future<Map<String, dynamic>> updateBanner(String title, String concept, String imageBase64) {
    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/admin/settings/banner'),
      body: {
        'title': title,
        'concept': concept,
        'image_base64': imageBase64,
      },
    );
  }

  Future<Map<String, dynamic>> updateSlotImage(String machineId, String slotOrId, String imageBase64) {
    return _http.patchJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/inventory/$slotOrId/image'),
      body: {'image_base64': imageBase64},
    );
  }


  Future<Map<String, dynamic>> updateInventoryStock(String inventoryId, int stock) {
    return _http.patchJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/inventory/$inventoryId'),
      body: {'stock': stock, 'capacity': 20}, // Assuming capacity is 20
    );
  }


  Future<Map<String, dynamic>> updateMachineLocation(String machineId, double lat, double lng) {
    return _http.patchJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/location'),
      body: {'latitude': lat, 'longitude': lng},
    );
  }

  Future<Map<String, dynamic>> getSessionCode(String machineId) {
    return _http.getJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/session-code'),
    );
  }

  Future<Map<String, dynamic>> verifyMachineCode(String code, {String machineId = 'MACHINE-001'}) {
    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/verify-code'),
      body: {'code': code},
    );
  }

  Future<Map<String, dynamic>> selectSlot(String machineId, String slot) {
    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/select-slot'),
      body: {'slot': slot},
    );
  }

  Future<Map<String, dynamic>> getMachineConfig(String machineId) {
    return _http.getJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/config'),
    );
  }

  Future<Map<String, dynamic>> updateMachineConfig(String machineId, {int? codeTtl, String? wifiSsid, String? wifiPassword, String? serverIp}) {
    final Map<String, dynamic> body = {};
    if (codeTtl != null) body['code_ttl'] = codeTtl;
    if (wifiSsid != null) body['wifi_ssid'] = wifiSsid;
    if (wifiPassword != null) body['wifi_password'] = wifiPassword;
    if (serverIp != null) body['server_ip'] = serverIp;

    return _http.putJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/config'),
      body: body,
    );
  }

  Future<Map<String, dynamic>> generateProvisioningToken(String machineId, {
    String? machineType,
    String? environment,
    String? protocol,
    String? brandModel,
    String? name,
  }) {
    final Map<String, dynamic> body = {'machine_id': machineId};
    if (machineType != null) body['machine_type'] = machineType;
    if (environment != null) body['environment'] = environment;
    if (protocol != null) body['protocol'] = protocol;
    if (brandModel != null) body['brand_model'] = brandModel;
    if (name != null) body['name'] = name;

    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/provisioning/generate-token'),
      body: body,
    );
  }

  Future<Map<String, dynamic>> getProvisioningStatus(String machineId) {
    return _http.getJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/provisioning/status/$machineId'),
    );
  }

  Future<Map<String, dynamic>> claimMachine({
    required String codeOrToken,
    required String ownerEmail,
    String? name,
  }) {
    final Map<String, dynamic> body = {
      'code_or_token': codeOrToken,
      'owner_email': ownerEmail,
    };
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }

    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/provisioning/claim'),
      body: body,
    );
  }

  Future<Map<String, dynamic>> factoryResetMachine(String machineId) {
    return _http.postJson(
      Uri.parse('${AppConfig.vendingUrl}/api/v1/machines/$machineId/factory-reset'),
      body: {},
    );
  }
}

