enum TransactionState {
  pending,
  qrGenerated,
  paid,
  paidPendingDispense,
  completed,
  failed,
  refunded,
}

extension TransactionStateX on TransactionState {
  static TransactionState fromApi(String value) {
    switch (value) {
      case 'QR_GENERATED':
        return TransactionState.qrGenerated;
      case 'PAID':
        return TransactionState.paid;
      case 'PAID_PENDING_DISPENSE':
        return TransactionState.paidPendingDispense;
      case 'COMPLETED':
        return TransactionState.completed;
      case 'FAILED':
        return TransactionState.failed;
      case 'REFUNDED':
        return TransactionState.refunded;
      default:
        return TransactionState.pending;
    }
  }
}
