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

  bool get isIncome {
    final t = type.toLowerCase();
    if (t == 'income' || t == 'deposit' || t == 'recharge') {
      return true;
    }
    if (t == 'payment') {
      return false;
    }
    if (t == 'transfer') {
      // Si no hay toEmail registrado o toEmail coincide con el usuario, se toma como ingreso
      return toEmail == null;
    }
    return false;
  }
}
