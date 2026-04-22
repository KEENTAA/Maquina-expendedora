enum ProductTransactionState {
  pending,
  qrGenerated,
  paidPendingDispense,
  completed,
  failed,
  refunded,
}

class ProductTransaction {
  final String id;
  final String userId;
  final String machineId;
  final String productId;
  final double amount;
  final ProductTransactionState state;
  final String? qrImage;
  final String? paymentReference;

  const ProductTransaction({
    required this.id,
    required this.userId,
    required this.machineId,
    required this.productId,
    required this.amount,
    required this.state,
    this.qrImage,
    this.paymentReference,
  });
}
