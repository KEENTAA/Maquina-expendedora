import 'package:flutter/material.dart';
import '../../data/orchestrator_api.dart';
import '../../data/models/transaction_view.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final OrchestratorApi _api = OrchestratorApi();
  final List<TransactionView> _items = [];
  bool _loading = false;

  Future<void> _buy(String productId, double amount) async {
    setState(() => _loading = true);
    try {
      var tx = await _api.createTransaction(
        userId: 'client@grog.com',
        machineId: 'MACHINE-001',
        productId: productId,
        amount: amount,
      );
      tx = await _api.generateQr(tx.id);
      setState(() => _items.insert(0, tx));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmPaid(TransactionView tx) async {
    final updated = await _api.confirmPayment(tx.id);
    _replaceItem(updated);
  }

  Future<void> _dispense(TransactionView tx, bool success) async {
    final updated = await _api.setDispenseResult(tx.id, success);
    _replaceItem(updated);
  }

  void _replaceItem(TransactionView updated) {
    final index = _items.indexWhere((t) => t.id == updated.id);
    if (index < 0) return;
    setState(() => _items[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grog Mobile')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : () => _buy('SODA-001', 8.50),
                    child: const Text('Comprar Soda (Bs. 8.50)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _loading ? null : () => _buy('CHIPS-002', 6.00),
                    child: const Text('Comprar Chips (Bs. 6.00)'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final tx = _items[index];
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TX ${tx.id}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Producto: ${tx.productId} | Monto: Bs. ${tx.amount.toStringAsFixed(2)}',
                        ),
                        Text('Estado: ${tx.state.name}'),
                        if (tx.qrImage != null) ...[
                          const SizedBox(height: 8),
                          const Text('QR generado (base64 image):'),
                          const SizedBox(height: 4),
                          Text(
                            tx.qrImage!.substring(
                              0,
                              tx.qrImage!.length > 60 ? 60 : tx.qrImage!.length,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _confirmPaid(tx),
                              child: const Text('Simular pago confirmado'),
                            ),
                            OutlinedButton(
                              onPressed: () => _dispense(tx, true),
                              child: const Text('Despacho OK'),
                            ),
                            OutlinedButton(
                              onPressed: () => _dispense(tx, false),
                              child: const Text('Despacho Falló'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
