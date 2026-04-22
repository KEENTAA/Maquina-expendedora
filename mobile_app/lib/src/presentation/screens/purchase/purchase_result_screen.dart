import 'package:flutter/material.dart';

import '../../../domain/entities/product_transaction.dart';

class PurchaseResultScreen extends StatelessWidget {
  final ProductTransaction transaction;

  const PurchaseResultScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final icon = switch (transaction.state) {
      ProductTransactionState.completed => Icons.check_circle,
      ProductTransactionState.refunded ||
      ProductTransactionState.failed => Icons.error,
      _ => Icons.hourglass_bottom,
    };
    final color = switch (transaction.state) {
      ProductTransactionState.completed => Colors.green,
      ProductTransactionState.refunded ||
      ProductTransactionState.failed => Colors.red,
      _ => Colors.orange,
    };

    final message = switch (transaction.state) {
      ProductTransactionState.completed => 'Producto entregado correctamente.',
      ProductTransactionState.refunded =>
        'No se pudo entregar, pago reembolsado.',
      ProductTransactionState.failed => 'No se pudo completar la compra.',
      ProductTransactionState.paidPendingDispense =>
        'Pago confirmado. Esperando confirmación de entrega de máquina (IoT).',
      _ => 'Transacción en proceso.',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'TX: ${transaction.id}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
