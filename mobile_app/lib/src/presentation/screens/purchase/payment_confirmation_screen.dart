import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/product_transaction.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/purchase_controller.dart';
import 'purchase_result_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String transactionId;

  const PaymentConfirmationScreen({super.key, required this.transactionId});

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<PurchaseController>().loadTransaction(
        widget.transactionId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseController>();
    final tx = purchase.transaction;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pago')),
      body:
          purchase.loading && tx == null
              ? const Center(child: CircularProgressIndicator())
              : tx == null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    purchase.error ?? 'No se pudo cargar la transacción.',
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transacción: ${tx.id}'),
                            const SizedBox(height: 6),
                            Text('Producto: ${tx.productId}'),
                            Text('Máquina: ${tx.machineId}'),
                            Text('Monto: Bs. ${tx.amount.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            Text('Estado: ${_stateLabel(tx.state)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            purchase.loading
                                ? null
                                : () async {
                                  final auth = context.read<AuthController>();
                                  final session = auth.session;
                                  final payerEmail =
                                      session?.simupayEmail ?? session?.email;
                                  if (payerEmail == null ||
                                      payerEmail.isEmpty) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No hay cuenta de pago disponible en la sesión.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final ok =
                                      await context
                                          .read<PurchaseController>()
                                          .confirmAndPay(
                                            payerEmail: payerEmail,
                                          );
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context
                                                  .read<PurchaseController>()
                                                  .error ??
                                              'No se pudo procesar el pago',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final latest =
                                      context
                                          .read<PurchaseController>()
                                          .transaction!;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => PurchaseResultScreen(
                                            transaction: latest,
                                          ),
                                    ),
                                  );
                                },
                        child: Text(
                          purchase.loading ? 'Procesando...' : 'Pagar ahora',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  String _stateLabel(ProductTransactionState state) {
    return switch (state) {
      ProductTransactionState.pending => 'Pendiente',
      ProductTransactionState.qrGenerated => 'QR generado',
      ProductTransactionState.paidPendingDispense =>
        'Pago confirmado, esperando entrega',
      ProductTransactionState.completed => 'Completada',
      ProductTransactionState.failed => 'Fallida',
      ProductTransactionState.refunded => 'Reembolsada',
    };
  }
}
