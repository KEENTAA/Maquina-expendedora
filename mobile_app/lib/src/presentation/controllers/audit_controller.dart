
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../domain/entities/audit_log.dart';

class AuditController extends ChangeNotifier {
  List<AuditLog> _logs = [];
  bool _isLoading = false;
  String? _error;

  List<AuditLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchLogs({String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = category != null && category.isNotEmpty 
          ? '${AppConfig.auditUrl}/api/v1/audit/logs?limit=100&category=$category'
          : '${AppConfig.auditUrl}/api/v1/audit/logs?limit=100';
          
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _logs = data.map((e) => AuditLog.fromJson(e)).toList();
      } else {
        _error = 'Error al cargar logs: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error de conexión: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
