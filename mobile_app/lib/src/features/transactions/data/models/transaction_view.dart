import '../../domain/transaction_state.dart';

class TransactionView {
  final String id;
  final double amount;
  final String machineId;
  final String productId;
  final TransactionState state;
  final String? qrImage;

  const TransactionView({
    required this.id,
    required this.amount,
    required this.machineId,
    required this.productId,
    required this.state,
    this.qrImage,
  });

  factory TransactionView.fromJson(Map<String, dynamic> json) {
    return TransactionView(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      machineId: json['machine_id'] as String,
      productId: json['product_id'] as String,
      state: TransactionStateX.fromApi(json['state'] as String),
      qrImage: json['qr_image'] as String?,
    );
  }
}
