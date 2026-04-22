import '../entities/wallet_info.dart';
import '../entities/wallet_movement.dart';

abstract class WalletRepository {
  Future<WalletInfo> getWallet(String email);
  Future<WalletInfo> linkWallet(String email);
  Future<List<WalletMovement>> getMovements(String email);
  Future<void> transfer({
    required String from,
    required String to,
    required double amount,
  });
  Future<void> payQr({
    required String from,
    required String qrData,
    double? amount,
  });
}
