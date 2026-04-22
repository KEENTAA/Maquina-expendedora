import 'dart:async';

import '../../domain/entities/product_transaction.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../services/orchestrator_api_service.dart';
import '../services/simupay_api_service.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  final OrchestratorApiService _orchestratorApi;
  final SimuPayApiService _simuPayApi;

  PurchaseRepositoryImpl({
    OrchestratorApiService? orchestratorApi,
    SimuPayApiService? simuPayApi,
  }) : _orchestratorApi = orchestratorApi ?? OrchestratorApiService(),
       _simuPayApi = simuPayApi ?? SimuPayApiService();

  @override
  Future<ProductTransaction> getTransaction(String transactionId) async {
    final data = await _orchestratorApi.getTransaction(transactionId);
    return _mapTransaction(data);
  }

  @override
  Future<ProductTransaction> initTransaction(
    String machineId,
    String? productId,
    double? amount,
  ) async {
    final data = await _orchestratorApi.initTransaction(
      machineId: machineId,
      productId: productId,
      amount: amount,
    );
    return _mapTransaction(data);
  }

  @override
  Future<ProductTransaction> confirmPayment(
    String transactionId, {
    required String payerEmail,
  }) async {
    ProductTransaction latest = await getTransaction(transactionId);

    if (latest.state == ProductTransactionState.pending) {
      await _orchestratorApi.generateQr(transactionId);
      latest = await getTransaction(transactionId);
    }

    if (latest.state == ProductTransactionState.qrGenerated) {
      final providerTxId = latest.paymentReference;
      if (providerTxId == null || providerTxId.isEmpty) {
        throw Exception(
          'No se pudo identificar la referencia de pago para la transacción.',
        );
      }

      await _simuPayApi.paySessionWithWallet(
        providerTransactionId: providerTxId,
        fromEmail: payerEmail,
      );
      await _orchestratorApi.confirmPayment(transactionId);
      latest = await getTransaction(transactionId);
    }

    for (var i = 0; i < 8; i++) {
      if (_isFinal(latest.state)) break;
      await Future.delayed(const Duration(seconds: 2));
      latest = await getTransaction(transactionId);
    }
    return latest;
  }

  bool _isFinal(ProductTransactionState state) {
    return state == ProductTransactionState.completed ||
        state == ProductTransactionState.failed ||
        state == ProductTransactionState.refunded;
  }

  ProductTransaction _mapTransaction(Map<String, dynamic> data) {
    final rawState = (data['state'] as String? ?? 'PENDING').toUpperCase();
    final state = switch (rawState) {
      'QR_GENERATED' => ProductTransactionState.qrGenerated,
      'PAID_PENDING_DISPENSE' => ProductTransactionState.paidPendingDispense,
      'COMPLETED' => ProductTransactionState.completed,
      'FAILED' => ProductTransactionState.failed,
      'REFUNDED' => ProductTransactionState.refunded,
      _ => ProductTransactionState.pending,
    };

    return ProductTransaction(
      id: data['id'] as String,
      userId: data['user_id'] as String? ?? '',
      machineId: data['machine_id'] as String? ?? '',
      productId: data['product_id'] as String? ?? '',
      amount: (data['amount'] as num).toDouble(),
      state: state,
      qrImage: data['qr_image'] as String?,
      paymentReference: data['payment_reference'] as String?,
    );
  }
}
