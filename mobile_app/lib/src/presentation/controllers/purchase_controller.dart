import 'package:flutter/foundation.dart';

import '../../domain/entities/product_transaction.dart';
import '../../domain/repositories/purchase_repository.dart';

class PurchaseController extends ChangeNotifier {
  final PurchaseRepository _purchaseRepository;

  ProductTransaction? transaction;
  bool loading = false;
  String? error;

  PurchaseController({required PurchaseRepository purchaseRepository})
    : _purchaseRepository = purchaseRepository;

  Future<bool> loadTransaction(String transactionId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      transaction = await _purchaseRepository.getTransaction(transactionId);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> initMachineTransaction(
    String machineId, {
    String? productId,
    double? amount,
  }) async {
    loading = true;
    error = null;
    transaction = null;
    notifyListeners();
    try {
      transaction = await _purchaseRepository.initTransaction(
        machineId,
        productId,
        amount,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmAndPay({required String payerEmail}) async {
    final tx = transaction;
    if (tx == null) return false;

    loading = true;
    error = null;
    notifyListeners();
    try {
      transaction = await _purchaseRepository.confirmPayment(
        tx.id,
        payerEmail: payerEmail,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
