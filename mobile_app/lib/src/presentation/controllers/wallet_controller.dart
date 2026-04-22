import 'package:flutter/foundation.dart';

import '../../domain/entities/wallet_info.dart';
import '../../domain/entities/wallet_movement.dart';
import '../../domain/repositories/wallet_repository.dart';

class WalletController extends ChangeNotifier {
  final WalletRepository _walletRepository;

  WalletInfo? wallet;
  List<WalletMovement> movements = const [];
  bool loading = false;
  String? error;

  WalletController({required WalletRepository walletRepository})
    : _walletRepository = walletRepository;

  Future<void> load(String email) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      wallet = await _walletRepository.getWallet(email);
      if (wallet!.linked) {
        movements = await _walletRepository.getMovements(email);
      } else {
        movements = const [];
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> linkWallet(String email) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      wallet = await _walletRepository.linkWallet(email);
      movements = await _walletRepository.getMovements(email);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> transfer({
    required String from,
    required String to,
    required double amount,
  }) async {
    try {
      await _walletRepository.transfer(from: from, to: to, amount: amount);
      await load(from);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> payQr({
    required String from,
    required String qrData,
    double? amount,
  }) async {
    try {
      await _walletRepository.payQr(from: from, qrData: qrData, amount: amount);
      await load(from);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
