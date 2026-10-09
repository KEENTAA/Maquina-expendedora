import 'dart:async';
import '../../data/services/notification_api_service.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/orchestrator_api_service.dart';
import '../../data/services/vending_api_service.dart';
import '../../data/services/iot_api_service.dart';

class AdminDashboardController extends ChangeNotifier {
  final OrchestratorApiService _api;
  final VendingApiService _vendingApi;
  final IotApiService _iotApi;
  Timer? _sessionCodeTimer;

  bool loading = false;
  String? error;

  double totalSales = 0.0;
  int totalUnitsSold = 0;
  Map<String, int> statusBreakdown = {};
  Map<String, Map<String, int>> methodBreakdown = {};
  Map<String, bool> machineLights = {};
  List<Map<String, dynamic>> tempHistory = [];
  double? minTemp;
  double? maxTemp;
  List<Map<String, dynamic>> distanceHistory = [];
  
  List<dynamic> machines = [];
  List<dynamic> iotMachines = [];
  Map<String, List<dynamic>> inventories = {};
  Map<String, List<dynamic>> topSellers = {};
  Map<String, List<dynamic>> failedSlots = {};
  Map<String, dynamic> banner = {};
  Map<String, Map<String, dynamic>> machineSessionCodes = {};

  AdminDashboardController({
    OrchestratorApiService? api,
    VendingApiService? vendingApi,
    IotApiService? iotApi,
  }) : _api = api ?? OrchestratorApiService(),
       _vendingApi = vendingApi ?? VendingApiService(),
       _iotApi = iotApi ?? IotApiService();

  void startSessionCodePolling() {
    _sessionCodeTimer?.cancel();
    _sessionCodeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshSessionCodes();
    });
  }

  void stopSessionCodePolling() {
    _sessionCodeTimer?.cancel();
    _sessionCodeTimer = null;
  }

  Future<void> refreshSessionCodes() async {
    if (machines.isEmpty) return;
    bool hasChanges = false;
    for (var machine in machines) {
      final machineId = machine['id'];
      try {
        final codeData = await _vendingApi.getSessionCode(machineId);
        machineSessionCodes[machineId] = codeData;
        hasChanges = true;
      } catch (_) {}
    }
    if (hasChanges) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopSessionCodePolling();
    super.dispose();
  }

  Future<void> loadStats() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final summary = await _api.getAdminStatsSummary();
      totalSales = (summary['total_sales'] as num).toDouble();
      totalUnitsSold = (summary['total_units_sold'] as num?)?.toInt() ?? 0;
      statusBreakdown = Map<String, int>.from(summary['status_breakdown'] ?? {});
      
      final rawMethod = summary['method_breakdown'];
      if (rawMethod is Map) {
        methodBreakdown = rawMethod.map(
          (k, v) => MapEntry(k.toString(), Map<String, int>.from(v is Map ? v : {})),
        );
      } else {
        methodBreakdown = {};
      }
      
      banner = await _vendingApi.getBanner();

      // Load machines
      final machinesData = await _vendingApi.listMachines();
      machines = machinesData['machines'] ?? [];

      // Load IoT machines for DEVOPS/Support
      final iotData = await _iotApi.listIotMachines();
      iotMachines = iotData['machines'] ?? [];
      
      // Load inventories, stats and active session codes for all machines concurrently
      await Future.wait(machines.map((machine) async {
        final machineId = machine['id']?.toString() ?? '';
        if (machineId.isEmpty) return;

        // Inventario por máquina
        try {
          final invData = await _vendingApi.getInventory(machineId);
          final rawItems = invData['items'];
          if (rawItems is List) {
            inventories[machineId] = rawItems
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : e)
                .toList();
          } else {
            inventories[machineId] = [];
          }
        } catch (_) {
          inventories[machineId] ??= [];
        }

        // Top sellers por máquina
        try {
          final topData = await _api.getTopSellers(machineId: machineId);
          final rawTop = topData['items'];
          if (rawTop is List) {
            topSellers[machineId] = rawTop
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .toList();
          } else {
            topSellers[machineId] = [];
          }
        } catch (_) {
          topSellers[machineId] ??= [];
        }

        // Ranuras con fallas por máquina
        try {
          final failData = await _api.getFailedSlots(machineId: machineId);
          final rawFail = failData['items'];
          if (rawFail is List) {
            failedSlots[machineId] = rawFail
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .toList();
          } else {
            failedSlots[machineId] = [];
          }
        } catch (_) {
          failedSlots[machineId] ??= [];
        }

        // Código de sesión activo
        try {
          final codeData = await _vendingApi.getSessionCode(machineId);
          machineSessionCodes[machineId] = Map<String, dynamic>.from(codeData);
        } catch (_) {}
      }));
      
      startSessionCodePolling();
      notifyListeners();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadBannerOnly() async {
    try {
      banner = await _vendingApi.getBanner();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMachinesOnly() async {
    try {
      final machinesData = await _vendingApi.listMachines();
      machines = machinesData['machines'] ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendIotCommand(String machineId, String command) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _iotApi.sendCommand(machineId, command);
      // Recargar telemetría después de un comando si es necesario
      final iotData = await _iotApi.listIotMachines();
      iotMachines = iotData['machines'] ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateSlotDetails(
    String machineId,
    String slot,
    String inventoryId,
    double newPrice,
    int newStock,
    bool isEnabled,
    String? slotType, {
    String? newProductName,
    String? newSlot,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _vendingApi.updateInventoryPrice(machineId, slot, newPrice);
      await _vendingApi.updateSlotStatus(
        machineId,
        slot,
        isEnabled,
        slotType,
        productName: newProductName,
        newSlot: newSlot,
      );
      
      await _vendingApi.updateInventoryStock(inventoryId, newStock);

      await _api.refreshConfig(machineId);
      final inventoryData = await _vendingApi.getInventory(machineId);
      inventories[machineId] = inventoryData['items'] ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> createSlot(
    String machineId, {
    required String slot,
    required String productName,
    required double price,
    required int stock,
    int capacity = 20,
    String slotType = 'soda',
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _vendingApi.createSlot(
        machineId,
        slot: slot,
        productName: productName,
        price: price,
        stock: stock,
        capacity: capacity,
        slotType: slotType,
      );
      await _api.refreshConfig(machineId);
      final inventoryData = await _vendingApi.getInventory(machineId);
      inventories[machineId] = inventoryData['items'] ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reorderSlots(String machineId, List<String> orderedSlots) async {
    try {
      // Optimistic update
      final currentList = inventories[machineId] ?? [];
      final Map<String, dynamic> itemMap = {
        for (var item in currentList) item['slot'].toString(): item
      };
      final reordered = <dynamic>[];
      for (var s in orderedSlots) {
        if (itemMap.containsKey(s)) {
          reordered.add(itemMap[s]);
        }
      }
      inventories[machineId] = reordered;
      notifyListeners();

      await _vendingApi.reorderSlots(machineId, orderedSlots);
      await _api.refreshConfig(machineId);
      final inventoryData = await _vendingApi.getInventory(machineId);
      inventories[machineId] = inventoryData['items'] ?? [];
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }


  Future<void> updatePrice(String machineId, String slot, double newPrice) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _vendingApi.updateInventoryPrice(machineId, slot, newPrice);
      // Notificar a la máquina para que refresque su pantalla
      await _api.refreshConfig(machineId);
      
      // Reload inventory for this machine
      final inventoryData = await _vendingApi.getInventory(machineId);
      inventories[machineId] = inventoryData['items'] ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateSlotStatus(String machineId, String slot, bool isEnabled, String? slotType) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _vendingApi.updateSlotStatus(machineId, slot, isEnabled, slotType);
      // Reload inventory for this machine
      final inventoryData = await _vendingApi.getInventory(machineId);
      inventories[machineId] = inventoryData['items'] ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setBannerImage(String imageBase64) {
    banner['image_base64'] = imageBase64;
    notifyListeners();
  }

  Future<bool> updateBanner(String title, String concept, String imageBase64) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _vendingApi.updateBanner(title, concept, imageBase64);
      banner = await _vendingApi.getBanner();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLights(String machineId) async {
    try {
      await _api.toggleLights(machineId);
      machineLights[machineId] = !(machineLights[machineId] ?? false);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadTempHistory({
    String? machineId,
    int intervalMinutes = 10,
    int hours = 1,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final history = await _api.getTemperatureHistory(
        machineId: machineId ?? 'all',
        intervalMinutes: intervalMinutes,
        hours: hours,
      );
      tempHistory = List<Map<String, dynamic>>.from(history['items'] ?? []);
      minTemp = (history['min_temperature'] as num?)?.toDouble();
      maxTemp = (history['max_temperature'] as num?)?.toDouble();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadDistanceHistory({
    String? machineId,
    int hours = 24,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final history = await _api.getDistanceHistory(
        machineId: machineId ?? 'all',
        hours: hours,
      );
      distanceHistory = List<Map<String, dynamic>>.from(history['items'] ?? []);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateSlotImage(String machineId, String slotOrId, String imageBase64) async {
    try {
      await _vendingApi.updateSlotImage(machineId, slotOrId, imageBase64);
      final inv = await _vendingApi.getInventory(machineId);
      inventories[machineId] = inv['items'] ?? [];
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }


  Future<void> updateMachineLocation(String machineId, double lat, double lng) async {
    try {
      await _vendingApi.updateMachineLocation(machineId, lat, lng);
      await loadStats();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }


  Future<bool> sendBroadcast(String title, String summary, String description, String type) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final notifApi = NotificationApiService();
      await notifApi.broadcastNotification(title, summary, description, type);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getMachineConfig(String machineId) async {
    try {
      final res = await _vendingApi.getMachineConfig(machineId);
      return res['config'] as Map<String, dynamic>?;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateMachineConfig(String machineId, {int? codeTtl, String? wifiSsid, String? wifiPassword, String? serverIp}) async {
    try {
      await _vendingApi.updateMachineConfig(
        machineId,
        codeTtl: codeTtl,
        wifiSsid: wifiSsid,
        wifiPassword: wifiPassword,
        serverIp: serverIp,
      );
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> claimMachine({
    required String codeOrToken,
    required String ownerEmail,
    String? name,
  }) async {
    try {
      loading = true;
      error = null;
      notifyListeners();

      final res = await _vendingApi.claimMachine(
        codeOrToken: codeOrToken,
        ownerEmail: ownerEmail,
        name: name,
      );

      // Refresh list of machines and inventories
      final machinesData = await _vendingApi.listMachines();
      machines = machinesData['machines'] ?? [];

      for (var machine in machines) {
        final mId = machine['id'];
        try {
          final inv = await _vendingApi.getInventory(mId);
          inventories[mId] = inv['items'] ?? [];
        } catch (_) {}
      }

      loading = false;
      notifyListeners();
      return res;
    } catch (e) {
      loading = false;
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> factoryResetMachine(String machineId) async {
    try {
      loading = true;
      error = null;
      notifyListeners();

      final res = await _vendingApi.factoryResetMachine(machineId);

      // Refresh list of machines and inventories
      final machinesData = await _vendingApi.listMachines();
      machines = machinesData['machines'] ?? [];

      loading = false;
      notifyListeners();
      return res;
    } catch (e) {
      loading = false;
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

}

