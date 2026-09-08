import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../controllers/admin_dashboard_controller.dart';

class AdminPanelTab extends StatefulWidget {
  const AdminPanelTab({super.key});

  @override
  State<AdminPanelTab> createState() => _AdminPanelTabState();
}

class _AdminPanelTabState extends State<AdminPanelTab> {
  // Global Filters
  String _selectedMachineId = 'all'; // 'all' or specific machine id
  String _selectedCategory = 'all'; // 'all', 'snack', 'soda'
  
  // Transaction Effectiveness Filter
  String _selectedPaymentMethod = 'ALL'; // 'ALL', 'QR', 'NFC', 'CODE'

  // Temperature Chart Filters
  int _tempHours = 1; // 1, 6, 24, 168 (7d), 0 (todo)
  int _tempInterval = 10; // minutes

  // Sensor Comparison Filters
  int _sensorHours = 24; // 1, 6, 24, 168

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() {
    final controller = context.read<AdminDashboardController>();
    controller.loadStats();
    controller.loadTempHistory(
      machineId: _selectedMachineId == 'all' ? null : _selectedMachineId,
      intervalMinutes: _tempInterval,
      hours: _tempHours,
    );
    controller.loadDistanceHistory(
      machineId: _selectedMachineId == 'all' ? null : _selectedMachineId,
      hours: _sensorHours,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminDashboardController>();

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        children: [
          // 1. Sales Header Card (Total Bs & Units Sold)
          _buildSalesSummaryHeader(controller),
          const SizedBox(height: 14),

          // 2. Global Machine & Category Filter Bar
          _buildFilterBar(controller),
          const SizedBox(height: 14),

          // 3. Top Sellers Chart (Real product names, exact counts, category & machine filters)
          _buildTopSellersChart(controller),
          const SizedBox(height: 14),

          // 4. Failed Slots Chart (Machine & Category filters)
          _buildFailedSlotsChart(controller),
          const SizedBox(height: 14),

          // 5. Transaction Effectiveness (Renamed from QR, with method selector QR/NFC/PIN/Todos)
          _buildTransactionEffectivenessChart(controller),
          const SizedBox(height: 14),

          // 6. Temperature Monitoring (1h default, max/min peaks, duration filters)
          _buildTemperatureDashboard(controller),
          const SizedBox(height: 14),

          // 7. Sensor Comparison (M1 vs M2 with duration filters)
          _buildDistanceDashboard(controller),
          const SizedBox(height: 16),

          // 8. Download / Export Report Section
          _buildReportExportCard(controller),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Sales Summary Header (Anti-overflow responsive)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSalesSummaryHeader(AdminDashboardController controller) {
    final currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ', decimalDigits: 2);
    final numberFormat = NumberFormat.decimalPattern('es_BO');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ventas & Métricas Globales',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                tooltip: 'Actualizar',
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Total en Bs.
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, color: Colors.yellowAccent.shade100, size: 14),
                          const SizedBox(width: 5),
                          const Expanded(
                            child: Text(
                              'TOTAL VENTAS',
                              style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currencyFormat.format(controller.totalSales),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Cantidad total de productos vendidos
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.cyanAccent.shade100, size: 14),
                          const SizedBox(width: 5),
                          const Expanded(
                            child: Text(
                              'UNIDADES VENDIDAS',
                              style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${numberFormat.format(controller.totalUnitsSold)} u.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Filter Bar (Machine & Category) - Overflow Proof
  // ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar(AdminDashboardController controller) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                const Text('Filtros de Análisis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                if (_selectedMachineId != 'all' || _selectedCategory != 'all')
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMachineId = 'all';
                        _selectedCategory = 'all';
                      });
                      _refresh();
                    },
                    child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Máquina
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        isExpanded: true,
                        value: _selectedMachineId,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('Todas las máquinas', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                          ...controller.machines.map((m) {
                            return DropdownMenuItem(
                              value: m['id'].toString(),
                              child: Text('${m['name']} (${m['id']})', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMachineId = val);
                            _refresh();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Categoría
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        isExpanded: true,
                        value: _selectedCategory,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todo tipo', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'snack', child: Text('🍟 Snacks', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'soda', child: Text('🥤 Bebidas', style: TextStyle(fontSize: 11))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helper: Get Product Info by Slot & Machine
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic>? _findProduct(AdminDashboardController controller, String slot, {String? machineId}) {
    if (machineId != null && controller.inventories.containsKey(machineId)) {
      final items = controller.inventories[machineId] ?? [];
      for (var item in items) {
        if (item['slot'].toString().toUpperCase() == slot.toUpperCase()) {
          return item;
        }
      }
    }
    for (var items in controller.inventories.values) {
      for (var item in items) {
        if (item['slot'].toString().toUpperCase() == slot.toUpperCase()) {
          return item;
        }
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Top Sellers Chart (Real product names, exact counts, anti-overflow)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopSellersChart(AdminDashboardController controller) {
    final Map<String, Map<String, dynamic>> aggregated = {};

    controller.topSellers.forEach((mId, list) {
      if (_selectedMachineId != 'all' && mId != _selectedMachineId) return;

      for (var entry in list) {
        final slot = entry['slot'].toString();
        final count = (entry['count'] as num?)?.toInt() ?? 0;
        final amount = (entry['total_amount'] as num?)?.toDouble() ?? 0.0;

        final prod = _findProduct(controller, slot, machineId: mId);
        final prodType = prod?['slot_type']?.toString().toLowerCase() ?? 'soda';
        final prodName = prod?['product_name'] ?? 'Slot $slot';

        if (_selectedCategory != 'all' && prodType != _selectedCategory) {
          continue;
        }

        final key = prodName;
        if (!aggregated.containsKey(key)) {
          aggregated[key] = {
            'name': prodName,
            'slot': slot,
            'count': 0,
            'total_amount': 0.0,
            'type': prodType,
          };
        }
        aggregated[key]!['count'] = (aggregated[key]!['count'] as int) + count;
        aggregated[key]!['total_amount'] = (aggregated[key]!['total_amount'] as double) + amount;
      }
    });

    final sortedItems = aggregated.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final displayItems = sortedItems.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard_rounded, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Productos Más Vendidos',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${sortedItems.length} en catálogo',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Ranking con nombre real y unidades vendidas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (displayItems.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: Text(
                  'No hay ventas con los filtros actuales.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              )
            else ...[
              SizedBox(
                height: 170,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: ((displayItems.first['count'] as int) * 1.25).toDouble().clamp(5.0, 1000.0),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = displayItems[groupIndex];
                          return BarTooltipItem(
                            '${item['name']}\n${item['count']} unid. (Bs. ${(item['total_amount'] as double).toStringAsFixed(2)})',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (val, meta) {
                            if (val % 1 == 0 && val >= 0) {
                              return Text(val.toInt().toString(), style: const TextStyle(fontSize: 9, color: Colors.grey));
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < displayItems.length) {
                              final name = displayItems[idx]['name'].toString();
                              final shortName = name.length > 6 ? '${name.substring(0, 5)}..' : name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(shortName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: displayItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final count = (item['count'] as int).toDouble();
                      final isSoda = item['type'] == 'soda';

                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: count,
                            color: isSoda ? const Color(0xFF4F46E5) : Colors.orangeAccent.shade700,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...displayItems.map((item) {
                final isSoda = item['type'] == 'soda';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: (isSoda ? const Color(0xFF4F46E5) : Colors.orange).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isSoda ? Icons.local_drink : Icons.fastfood,
                          size: 14,
                          color: isSoda ? const Color(0xFF4F46E5) : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item['count']} u.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bs. ${(item['total_amount'] as double).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Failed Slots Chart (Machine & Category filters)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFailedSlotsChart(AdminDashboardController controller) {
    final Map<String, Map<String, dynamic>> aggregated = {};

    controller.failedSlots.forEach((mId, list) {
      if (_selectedMachineId != 'all' && mId != _selectedMachineId) return;

      for (var entry in list) {
        final slot = entry['slot'].toString();
        final count = (entry['count'] as num?)?.toInt() ?? 0;

        final prod = _findProduct(controller, slot, machineId: mId);
        final prodType = prod?['slot_type']?.toString().toLowerCase() ?? 'soda';
        final prodName = prod?['product_name'] ?? 'Slot $slot';

        if (_selectedCategory != 'all' && prodType != _selectedCategory) {
          continue;
        }

        final key = 'Slot $slot ($prodName)';
        if (!aggregated.containsKey(key)) {
          aggregated[key] = {
            'label': key,
            'slot': slot,
            'name': prodName,
            'count': 0,
          };
        }
        aggregated[key]!['count'] = (aggregated[key]!['count'] as int) + count;
      }
    });

    final sortedItems = aggregated.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final displayItems = sortedItems.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ranuras con Fallas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${displayItems.length} críticas',
                  style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Ranuras que reportaron atascos o fallos de sensor.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 12),
            if (displayItems.isEmpty)
              Container(
                height: 80,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Excelente: Ninguna falla registrada.', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            else
              Column(
                children: displayItems.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['label'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item['count']} fallas',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Transaction Effectiveness (Anti-overflow and responsive badge)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTransactionEffectivenessChart(AdminDashboardController controller) {
    int completed = 0;
    int refunded = 0;
    int failed = 0;

    if (_selectedPaymentMethod == 'ALL') {
      completed = controller.statusBreakdown['COMPLETED'] ?? 0;
      refunded = controller.statusBreakdown['REFUNDED'] ?? 0;
      failed = controller.statusBreakdown['FAILED'] ?? 0;
    } else {
      final methodMap = controller.methodBreakdown[_selectedPaymentMethod] ?? {};
      completed = methodMap['COMPLETED'] ?? 0;
      refunded = methodMap['REFUNDED'] ?? 0;
      failed = methodMap['FAILED'] ?? 0;
    }

    final totalTx = completed + refunded + failed;
    final successRate = totalTx > 0 ? (completed / totalTx * 100).toStringAsFixed(1) : '100.0';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_rounded, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Efectividad de Transacciones',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '$successRate% éxito',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Tasa de éxito y volumen según canal de pago.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 10),

            // Method Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMethodChip('ALL', 'Todos'),
                  const SizedBox(width: 6),
                  _buildMethodChip('QR', 'Código QR'),
                  const SizedBox(width: 6),
                  _buildMethodChip('NFC', 'NFC Móvil'),
                  const SizedBox(width: 6),
                  _buildMethodChip('CODE', 'PIN Teclado'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (totalTx == 0)
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Text('No hay transacciones registradas para este método.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              )
            else
              Row(
                children: [
                  // Pie Chart
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 28,
                        sections: [
                          if (completed > 0)
                            PieChartSectionData(
                              value: completed.toDouble(),
                              title: '$completed',
                              color: Colors.green,
                              radius: 30,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          if (refunded > 0)
                            PieChartSectionData(
                              value: refunded.toDouble(),
                              title: '$refunded',
                              color: Colors.redAccent,
                              radius: 30,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          if (failed > 0)
                            PieChartSectionData(
                              value: failed.toDouble(),
                              title: '$failed',
                              color: Colors.orange,
                              radius: 30,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Breakdown counts with exact quantities
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOutcomeTile(label: 'Completadas', count: completed, total: totalTx, color: Colors.green),
                        const SizedBox(height: 6),
                        _buildOutcomeTile(label: 'Reembolsadas', count: refunded, total: totalTx, color: Colors.redAccent),
                        const SizedBox(height: 6),
                        _buildOutcomeTile(label: 'Fallidas', count: failed, total: totalTx, color: Colors.orange),
                        const Divider(height: 12),
                        Text('Total: $totalTx operaciones', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String methodKey, String label) {
    final isSelected = _selectedPaymentMethod == methodKey;
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
      onSelected: (val) {
        if (val) setState(() => _selectedPaymentMethod = methodKey);
      },
    );
  }

  Widget _buildOutcomeTile({required String label, required int count, required int total, required Color color}) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
        ),
        Text('$count ($pct%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Temperature Monitoring (1h default, max/min peak badges)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTemperatureDashboard(AdminDashboardController controller) {
    final spots = controller.tempHistory.asMap().entries.map((e) {
      final temp = (e.value['temperature'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), temp);
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.device_thermostat_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Monitoreo de Temperatura',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controller.minTemp != null && controller.maxTemp != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      '${controller.minTemp!.toStringAsFixed(1)}°C',
                      style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '${controller.maxTemp!.toStringAsFixed(1)}°C',
                      style: TextStyle(fontSize: 9, color: Colors.red.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Evolución térmica con picos altos y bajos registrados.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTimeFilterChip('1h (Default)', 1, 1),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('6h', 6, 5),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('24h', 24, 15),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('7 Días', 168, 60),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('Histórico', 0, 10),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (spots.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: Text('No hay datos telemétricos en este rango.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              )
            else
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (val, meta) => Text('${val.toInt()}°', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < controller.tempHistory.length && idx % 3 == 0) {
                              final item = controller.tempHistory[idx];
                              final ts = item['timestamp']?.toString() ?? '';
                              if (ts.contains('T')) {
                                final timePart = ts.split('T').last.split('.').first;
                                final hm = timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
                                return Text(hm, style: const TextStyle(fontSize: 8, color: Colors.grey));
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        color: Colors.orange.shade700,
                        barWidth: 2.2,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.orange.withValues(alpha: 0.1),
                        ),
                        dotData: FlDotData(
                          show: spots.length < 20,
                          getDotPainter: (spot, percent, barData, index) {
                            final isMax = controller.maxTemp != null && (spot.y - controller.maxTemp!).abs() < 0.05;
                            final isMin = controller.minTemp != null && (spot.y - controller.minTemp!).abs() < 0.05;
                            if (isMax) {
                              return FlDotCirclePainter(radius: 4.5, color: Colors.red, strokeWidth: 2, strokeColor: Colors.white);
                            }
                            if (isMin) {
                              return FlDotCirclePainter(radius: 4.5, color: Colors.blue, strokeWidth: 2, strokeColor: Colors.white);
                            }
                            return FlDotCirclePainter(radius: 2, color: Colors.orange.shade700);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, int hours, int interval) {
    final isSelected = _tempHours == hours;
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: Colors.orange.shade600,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
      onSelected: (val) {
        if (val) {
          setState(() {
            _tempHours = hours;
            _tempInterval = interval;
          });
          context.read<AdminDashboardController>().loadTempHistory(
            machineId: _selectedMachineId == 'all' ? null : _selectedMachineId,
            intervalMinutes: interval,
            hours: hours,
          );
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Sensor Comparison (M1 vs M2 with duration filters) - Anti-overflow
  // ─────────────────────────────────────────────────────────────
  Widget _buildDistanceDashboard(AdminDashboardController controller) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors_rounded, color: Colors.cyan, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sensores (M1 vs M2)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      value: _sensorHours,
                      items: const [
                        DropdownMenuItem(value: 6, child: Text('6h', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 24, child: Text('24h', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 168, child: Text('7d', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _sensorHours = val);
                          controller.loadDistanceHistory(
                            machineId: _selectedMachineId == 'all' ? null : _selectedMachineId,
                            hours: val,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'M1: Inicial (Celeste) | M2: Final (Morado)',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 14),
            if (controller.distanceHistory.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: Text('No hay datos telemétricos de sensores.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              )
            else
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    titlesData: const FlTitlesData(
                      show: true,
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: controller.distanceHistory.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), (e.value['m1'] as num?)?.toDouble() ?? 0.0);
                        }).toList(),
                        isCurved: false,
                        color: Colors.cyan,
                        barWidth: 2.2,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: controller.distanceHistory.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), (e.value['m2'] as num?)?.toDouble() ?? 0.0);
                        }).toList(),
                        isCurved: false,
                        color: Colors.purple,
                        barWidth: 2.2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.cyan, label: 'Sensor M1'),
                SizedBox(width: 14),
                _LegendItem(color: Colors.purple, label: 'Sensor M2'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 8. Report Export Card with PDF Generation & Sharing
  // ─────────────────────────────────────────────────────────────
  Widget _buildReportExportCard(AdminDashboardController controller) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF4F46E5), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Descargar Reporte Ejecutivo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Genera un documento PDF corporativo con balance de ventas, productos y telemetría.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('Ver Resumen', style: TextStyle(fontSize: 12)),
                    onPressed: () => _generateAndShowReportDialog(context, controller),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Guardar/Enviar PDF', style: TextStyle(fontSize: 12)),
                    onPressed: () => _exportAndSharePdf(context, controller),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAndSharePdf(BuildContext context, AdminDashboardController controller) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ', decimalDigits: 2);

    final completed = controller.statusBreakdown['COMPLETED'] ?? 0;
    final refunded = controller.statusBreakdown['REFUNDED'] ?? 0;
    final failed = controller.statusBreakdown['FAILED'] ?? 0;
    final totalTx = completed + refunded + failed;
    final successRate = totalTx > 0 ? (completed / totalTx * 100).toStringAsFixed(1) : '100.0';

    // Collect top sellers
    final topList = <Map<String, dynamic>>[];
    controller.topSellers.forEach((mId, list) {
      if (_selectedMachineId != 'all' && mId != _selectedMachineId) return;
      for (var entry in list) {
        final slot = entry['slot'].toString();
        final prod = _findProduct(controller, slot, machineId: mId);
        final name = prod?['product_name'] ?? 'Slot $slot';
        topList.add({
          'name': name,
          'slot': slot,
          'count': entry['count'] ?? 0,
          'amount': entry['total_amount'] ?? 0.0,
        });
      }
    });
    topList.sort((a, b) => (b['count'] as num).compareTo(a['count'] as num));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GROG DISPENSADORAS S.A.',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                      pw.Text('Reporte Oficial de Operaciones & Ventas', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Emisión: ${dateFormat.format(now)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text('Máquina: ${_selectedMachineId == 'all' ? 'Todas' : _selectedMachineId}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.indigo600),
              pw.SizedBox(height: 16),

              // KPI Summary Boxes
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.indigo200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RECAUDACIÓN TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          pw.SizedBox(height: 4),
                          pw.Text(currency.format(controller.totalSales), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.teal200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('UNIDADES VENDIDAS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                          pw.SizedBox(height: 4),
                          pw.Text('${controller.totalUnitsSold} unid.', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.green200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TASA DE ÉXITO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                          pw.SizedBox(height: 4),
                          pw.Text('$successRate%', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Section: Top Sellers Table
              pw.Text('1. RANKING DE PRODUCTOS MÁS VENDIDOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Producto', 'Slot', 'Unidades', 'Total Bs.'],
                data: topList.take(6).toList().asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return [
                    '$idx',
                    item['name'],
                    item['slot'],
                    '${item['count']} u.',
                    'Bs. ${(item['amount'] as num).toStringAsFixed(2)}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              ),
              pw.SizedBox(height: 20),

              // Section: Transaction Breakdown
              pw.Text('2. DESGLOSE DE EFECTIVIDAD OPERATIVA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Estado', 'Cantidad', 'Porcentaje'],
                data: [
                  ['Completadas Exitosas', '$completed', '$successRate%'],
                  ['Reembolsadas (Devueltas)', '$refunded', '${totalTx > 0 ? (refunded / totalTx * 100).toStringAsFixed(1) : 0}%'],
                  ['Fallidas sin cobro', '$failed', '${totalTx > 0 ? (failed / totalTx * 100).toStringAsFixed(1) : 0}%'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              ),
              pw.SizedBox(height: 20),

              // Section: Sensor & Telemetry Health
              pw.Text('3. SALUD TÉRMICA & TELEMETRÍA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Temperatura Mínima: ${controller.minTemp != null ? '${controller.minTemp!.toStringAsFixed(1)}°C' : 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Temperatura Máxima: ${controller.maxTemp != null ? '${controller.maxTemp!.toStringAsFixed(1)}°C' : 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Rango de Historial: ${_tempHours == 0 ? 'Histórico' : '$_tempHours Horas'}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Center(
                child: pw.Text('Reporte generado automáticamente desde Grog Wallet Admin Dashboard.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Reporte_Ventas_Grog_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  void _generateAndShowReportDialog(BuildContext context, AdminDashboardController controller) {
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ', decimalDigits: 2);

    final completed = controller.statusBreakdown['COMPLETED'] ?? 0;
    final refunded = controller.statusBreakdown['REFUNDED'] ?? 0;
    final failed = controller.statusBreakdown['FAILED'] ?? 0;
    final totalTx = completed + refunded + failed;
    final successRate = totalTx > 0 ? (completed / totalTx * 100).toStringAsFixed(1) : '100.0';

    final reportText = StringBuffer();
    reportText.writeln('====================================');
    reportText.writeln('   REPORTE EJECUTIVO DE VENTAS');
    reportText.writeln('        GROG DISPENSADORAS');
    reportText.writeln('====================================');
    reportText.writeln('Fecha de emisión: ${dateFormat.format(now)}');
    reportText.writeln('Máquina: ${_selectedMachineId == 'all' ? 'Todas' : _selectedMachineId}');
    reportText.writeln('Categoría: ${_selectedCategory.toUpperCase()}');
    reportText.writeln('');
    reportText.writeln('1. FINANZAS Y DESPACHO');
    reportText.writeln('------------------------------------');
    reportText.writeln('• Recaudación Total: ${currency.format(controller.totalSales)}');
    reportText.writeln('• Unidades Despachadas: ${controller.totalUnitsSold} u.');
    reportText.writeln('');
    reportText.writeln('2. EFECTIVIDAD DE OPERACIONES');
    reportText.writeln('------------------------------------');
    reportText.writeln('• Transacciones Totales: $totalTx');
    reportText.writeln('• Exitosas: $completed ($successRate%)');
    reportText.writeln('• Reembolsadas: $refunded');
    reportText.writeln('• Fallidas: $failed');
    reportText.writeln('');
    reportText.writeln('3. TELEMETRÍA TÉRMICA');
    reportText.writeln('------------------------------------');
    reportText.writeln('• Temperatura Mínima: ${controller.minTemp != null ? '${controller.minTemp!.toStringAsFixed(1)}°C' : 'N/A'}');
    reportText.writeln('• Temperatura Máxima: ${controller.maxTemp != null ? '${controller.maxTemp!.toStringAsFixed(1)}°C' : 'N/A'}');
    reportText.writeln('====================================');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.assessment, color: Color(0xFF4F46E5), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Reporte Consolidado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                reportText.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy, size: 15),
            label: const Text('Copiar'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportText.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte copiado al portapapeles exitosamente.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
