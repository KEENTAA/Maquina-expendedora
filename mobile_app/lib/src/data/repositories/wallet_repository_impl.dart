import '../../core/network/app_exception.dart';
import '../../domain/entities/wallet_info.dart';
import '../../domain/entities/wallet_movement.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../services/simupay_api_service.dart';

class WalletRepositoryImpl implements WalletRepository {
  final SimuPayApiService _simuPayApi;

  WalletRepositoryImpl({SimuPayApiService? simuPayApi})
    : _simuPayApi = simuPayApi ?? SimuPayApiService();

  @override
  Future<WalletInfo> getWallet(String email) async {
    try {
      final data = await _simuPayApi.getWallet(email);
      return WalletInfo(
        email: data['email'] as String,
        balance: (data['balance'] as num).toDouble(),
        linked: true,
      );
    } on AppException catch (e) {
      if (e.statusCode == 404) {
        return WalletInfo(email: email, balance: 0, linked: false);
      }
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<WalletInfo> linkWallet(String email) async {
    final data = await _simuPayApi.createWallet(email);
    return WalletInfo(
      email: data['email'] as String,
      balance: (data['balance'] as num).toDouble(),
      linked: true,
    );
  }

  @override
  Future<List<WalletMovement>> getMovements(String email) async {
    final data = await _simuPayApi.getWalletMovements(email);
    final items =
        (data['items'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item as Map<String, dynamic>)
            .map(
              (item) => WalletMovement(
                id: item['id'] as String,
                type: item['type'] as String? ?? 'UNKNOWN',
                amount: (item['amount'] as num).toDouble(),
                fromEmail: item['from_email'] as String?,
                toEmail: item['to_email'] as String?,
                createdAt: DateTime.parse(item['created_at'] as String),
              ),
            )
            .toList();
    return items;
  }

  @override
  Future<void> transfer({
    required String from,
    required String to,
    required double amount,
  }) async {
    await _simuPayApi.transfer(from: from, to: to, amount: amount);
  }

  @override
  Future<void> payQr({
    required String from,
    required String qrData,
    double? amount,
  }) async {
    await _simuPayApi.payQr(from: from, qrData: qrData, amount: amount);
  }
}
