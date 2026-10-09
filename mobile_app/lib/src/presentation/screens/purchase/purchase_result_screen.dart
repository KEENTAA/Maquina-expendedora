import 'dart:async';
import 'package:flutter/material.dart';

import '../../../domain/entities/product_transaction.dart';
import '../../../data/repositories/purchase_repository_impl.dart';

class PurchaseResultScreen extends StatefulWidget {
  final ProductTransaction transaction;

  const PurchaseResultScreen({super.key, required this.transaction});

  @override
  State<PurchaseResultScreen> createState() => _PurchaseResultScreenState();
}

class _PurchaseResultScreenState extends State<PurchaseResultScreen> {
  late ProductTransaction _transaction;
  Timer? _pollTimer;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    if (_transaction.state == ProductTransactionState.paidPendingDispense) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollCount++;
      if (_pollCount > 30) {
        timer.cancel();
        return;
      }
      try {
        final repo = PurchaseRepositoryImpl();
        final updated = await repo.getTransaction(_transaction.id);
        if (mounted) {
          setState(() {
            _transaction = updated;
          });
          if (updated.state != ProductTransactionState.paidPendingDispense) {
            timer.cancel();
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (_transaction.state) {
      ProductTransactionState.completed => Icons.check_circle,
      ProductTransactionState.refunded ||
      ProductTransactionState.failed => Icons.error,
      _ => Icons.hourglass_bottom,
    };
    final color = switch (_transaction.state) {
      ProductTransactionState.completed => Colors.green,
      ProductTransactionState.refunded ||
      ProductTransactionState.failed => Colors.red,
      _ => Colors.orange,
    };

    final message = switch (_transaction.state) {
      ProductTransactionState.completed => '¡Producto entregado correctamente!',
      ProductTransactionState.refunded =>
        'No se pudo entregar, pago reembolsado.',
      ProductTransactionState.failed => 'No se pudo completar la compra.',
      ProductTransactionState.paidPendingDispense =>
        'Pago confirmado. Esperando confirmación de entrega de máquina (IoT)...',
      _ => 'Transacción en proceso...',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _transaction.state == ProductTransactionState.completed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TX: ${_transaction.id}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  if (_transaction.state == ProductTransactionState.paidPendingDispense) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                  if (_transaction.state == ProductTransactionState.completed) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Finalizar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
