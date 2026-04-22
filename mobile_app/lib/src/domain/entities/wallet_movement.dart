class WalletMovement {
  final String id;
  final String type;
  final double amount;
  final String? fromEmail;
  final String? toEmail;
  final DateTime createdAt;

  const WalletMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.fromEmail,
    this.toEmail,
  });
}
