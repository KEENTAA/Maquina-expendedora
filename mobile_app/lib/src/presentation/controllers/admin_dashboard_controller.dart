import 'package:flutter/foundation.dart';
import '../../data/services/orchestrator_api_service.dart';
import '../../data/services/vending_api_service.dart';

class AdminDashboardController extends ChangeNotifier {
  final OrchestratorApiService _api;
  final VendingApiService _vendingApi;

  bool loading = false;
  String? error;

  double totalSales = 0.0;
  Map<String, int> statusBreakdown = {};
  List<Map<String, dynamic>> tempHistory = [];
  List<Map<String, dynamic>> distanceHistory = [];
  
  List<dynamic> machines = [];
  Map<String, List<dynamic>> inventories = {};

  AdminDashboardController({
    OrchestratorApiService? api,
    VendingApiService? vendingApi,
  }) : _api = api ?? OrchestratorApiService(),
       _vendingApi = vendingApi ?? VendingApiService();

  Future<void> loadStats() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final summary = await _api.getAdminStatsSummary();
      totalSales = (summary['total_sales'] as num).toDouble();
      statusBreakdown = Map<String, int>.from(summary['status_breakdown'] ?? {});
      
      // Load machines
      final machinesData = await _vendingApi.listMachines();
      machines = machinesData['machines'] ?? [];
      
      // Load inventories for all machines
      for (var machine in machines) {
        final machineId = machine['id'];
        final inventoryData = await _vendingApi.getInventory(machineId);
        inventories[machineId] = inventoryData['items'] ?? [];
      }
      
      notifyListeners();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updatePrice(String machineId, String slot, double newPrice) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _vendingApi.updateInventoryPrice(machineId, slot, newPrice);
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

  Future<void> loadTempHistory({int intervalMinutes = 10}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final history = await _api.getTemperatureHistory(intervalMinutes: intervalMinutes);
      tempHistory = List<Map<String, dynamic>>.from(history['items'] ?? []);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadDistanceHistory() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final history = await _api.getDistanceHistory();
      distanceHistory = List<Map<String, dynamic>>.from(history['items'] ?? []);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
