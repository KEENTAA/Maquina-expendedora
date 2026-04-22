import '../entities/product_transaction.dart';

abstract class PurchaseRepository {
  Future<ProductTransaction> getTransaction(String transactionId);
  Future<ProductTransaction> confirmPayment(
    String transactionId, {
    required String payerEmail,
  });
  Future<ProductTransaction> initTransaction(
    String machineId,
    String? productId,
    double? amount,
  );
}
