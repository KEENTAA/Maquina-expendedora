import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../transactions/data/models/transaction_view.dart';
import '../../../transactions/data/orchestrator_api.dart';

class RoleDashboardScreen extends StatefulWidget {
  final String email;
  final String role;

  const RoleDashboardScreen({
    super.key,
    required this.email,
    required this.role,
  });

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  final ApiClient _api = ApiClient();
  final OrchestratorApi _orchestrator = OrchestratorApi();
  final TextEditingController _toEmail = TextEditingController(
    text: 'admin@grog.com',
  );
  final TextEditingController _amount = TextEditingController(text: '5');

  Map<String, dynamic> _wallet = {};
  Map<String, dynamic> _history = {};
  Map<String, dynamic> _machines = {};
  Map<String, dynamic> _sales = {};
  Map<String, dynamic> _iot = {};
  List<TransactionView> _transactions = [];
  bool _loading = true;
  String _info = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, List<dynamic>> _machineInventories = {};

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    try {
      if (widget.role == 'CLIENT') {
        _wallet = await _api.wallet(widget.email);
        _history = await _api.walletHistory(widget.email);
        _transactions = await _orchestrator.listTransactions(widget.email);
        await prefs.setString('cache_client_wallet', jsonEncode(_wallet));
        await prefs.setString('cache_client_history', jsonEncode(_history));
      } else if (widget.role == 'ADMIN') {
        _machines = await _api.machines(ownerEmail: widget.email);
        _sales = await _api.sales();
        
        final machineList = (_machines['machines'] as List<dynamic>? ?? []);
        for (var m in machineList) {
          final inv = await _api.inventory(m['id']);
          _machineInventories[m['id']] = inv['items'] ?? [];
        }

        await prefs.setString('cache_admin_machines', jsonEncode(_machines));
        await prefs.setString('cache_admin_sales', jsonEncode(_sales));
      } else {
        _machines = await _api.machines();
        _iot = await _api.iotMachines();
        await prefs.setString('cache_devops_machines', jsonEncode(_machines));
        await prefs.setString('cache_devops_iot', jsonEncode(_iot));
      }
    } catch (_) {
      // ... cache logic unchanged
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePrice(String machineId, String slot, double newPrice) async {
    try {
      await _api.updateInventoryPrice(machineId, slot, newPrice);
      setState(() => _info = 'Precio actualizado en máquina $machineId slot $slot a Bs. $newPrice');
      await _load();
    } catch (e) {
      setState(() => _info = e.toString());
    }
  }

  void _showEditPriceDialog(String machineId, String slot, String name, dynamic currentPrice) {
    final controller = TextEditingController(text: currentPrice.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Precio: $name'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nuevo Precio (Bs.)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                Navigator.pop(context);
                _updatePrice(machineId, slot, newPrice);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _transfer() async {
    try {
      final res = await _api.transfer(
        widget.email,
        _toEmail.text.trim(),
        double.parse(_amount.text.trim()),
      );
      setState(() => _info = 'Transferencia OK. Saldo: ${res['from_balance']}');
      await _load();
    } catch (e) {
      setState(() => _info = e.toString());
    }
  }

  Future<void> _buyProduct() async {
    try {
      var tx = await _orchestrator.createTransaction(
        userId: widget.email,
        machineId: 'MACHINE-001',
        productId: 'SODA-001',
        amount: 8.5,
      );
      tx = await _orchestrator.generateQr(tx.id);
      setState(() {
        _transactions.insert(0, tx);
        _info = 'QR generado para ${tx.id}';
      });
    } catch (e) {
      setState(() => _info = e.toString());
    }
  }

  Future<void> _simulate(TransactionView tx, String outcome) async {
    try {
      await _orchestrator.confirmPayment(tx.id);
      final res = await _orchestrator.setDispenseResult(
        tx.id,
        outcome == 'success',
      );
      setState(() => _info = 'Resultado: ${res.state.name}');
      await _load();
    } catch (e) {
      setState(() => _info = e.toString());
    }
  }

  Future<void> _devopsCommand(String machineId, String cmd) async {
    try {
      final res = await _api.iotCommand(machineId, cmd);
      setState(() => _info = 'Comando ${res['command']} encolado');
    } catch (e) {
      setState(() => _info = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard ${widget.role} - ${widget.email}'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_info.isNotEmpty)
              Text(_info, style: const TextStyle(color: Colors.indigo)),
            const SizedBox(height: 10),
            Expanded(child: _buildByRole()),
          ],
        ),
      ),
    );
  }

  Widget _buildByRole() {
    if (widget.role == 'CLIENT') {
      final balance = _wallet['balance'] ?? 0;
      final history = (_history['items'] as List<dynamic>? ?? []);
      return ListView(
        children: [
          Card(
            child: ListTile(
              title: const Text('Saldo SimuPay'),
              subtitle: Text('Bs. $balance'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transferir dinero',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: _toEmail,
                    decoration: const InputDecoration(labelText: 'Destino'),
                  ),
                  TextField(
                    controller: _amount,
                    decoration: const InputDecoration(labelText: 'Monto'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _transfer,
                    child: const Text('Transferir'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comprar por QR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  FilledButton(
                    onPressed: _buyProduct,
                    child: const Text('Comprar Soda (Bs. 8.50)'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Modo testing:'),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed:
                            _transactions.isEmpty
                                ? null
                                : () =>
                                    _simulate(_transactions.first, 'success'),
                        child: const Text('Simular pago OK'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            _transactions.isEmpty
                                ? null
                                : () => _simulate(_transactions.first, 'fail'),
                        child: const Text('Simular fallo'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            _transactions.isEmpty
                                ? null
                                : () =>
                                    _simulate(_transactions.first, 'refund'),
                        child: const Text('Simular reembolso'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historial de billetera',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...history.map(
                    (e) => Text(
                      '${e['type']} | ${e['amount']} | ${e['to_email'] ?? ''}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (widget.role == 'ADMIN') {
      final machines = (_machines['machines'] as List<dynamic>? ?? []);
      return ListView(
        children: [
          Card(
            child: ListTile(
              title: const Text('Resumen de Ventas'),
              subtitle: Text(
                'Hoy: Bs. ${_sales['daily_total']} | Mes: Bs. ${_sales['monthly_total']}',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'Mis Máquinas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...machines.map((m) {
            final machineId = m['id'] as String;
            final inventory = _machineInventories[machineId] ?? [];

            return Card(
              child: ExpansionTile(
                leading: Icon(
                  Icons.vending_machine,
                  color: m['status'] == 'online' ? Colors.green : Colors.grey,
                ),
                title: Text('${m['name']}'),
                subtitle: Text('ID: $machineId | Estado: ${m['status']}'),
                children: [
                  const Divider(),
                  ...inventory.map((item) {
                    final productId = item['product_sku'] ?? item['product_id'];
                    final productName = item['product_name'];
                    final currentPrice = item['price'];
                    final stock = item['stock'];

                    return ListTile(
                      title: Text('$productName ($productId)'),
                      subtitle: Text('Stock: $stock | Precio: Bs. $currentPrice'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditPriceDialog(machineId, item['slot'], productName, currentPrice),
                      ),
                    );
                  }),
                  if (inventory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Sin productos en inventario'),
                    ),
                ],
              ),
            );
          }),
        ],
      );
    }

    final machines = (_machines['machines'] as List<dynamic>? ?? []);
    final iotMachines = (_iot['machines'] as List<dynamic>? ?? []);
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vista global',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Máquinas registradas: ${machines.length}'),
                Text('Máquinas con telemetría: ${iotMachines.length}'),
              ],
            ),
          ),
        ),
        ...iotMachines.map(
          (m) => Card(
            child: ListTile(
              title: Text('${m['machine_id']} - ${m['status']}'),
              subtitle: Text('temp=${m['temperature']} hum=${m['humidity']}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed:
                        () =>
                            _devopsCommand(m['machine_id'] as String, 'homing'),
                    child: const Text('Homing'),
                  ),
                  TextButton(
                    onPressed:
                        () => _devopsCommand(
                          m['machine_id'] as String,
                          'restart',
                        ),
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
