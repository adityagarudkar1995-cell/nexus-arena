import '../../../core/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../models/withdrawal.dart';

class WalletService {
  static Future<Wallet> fetchWallet() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList('/rest/v1/wallets?limit=1');
    if (data.isEmpty) throw ApiException('wallet_not_found', 404);
    return Wallet.fromJson(data.first as Map<String, dynamic>);
  }

  static Future<List<WalletTransaction>> fetchTransactions({
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    var path =
        '/rest/v1/wallet_transactions?order=created_at.desc&limit=$limit&offset=$offset';
    if (type != null) path += '&type=eq.$type';
    final data = await client.getList(path);
    return data
        .cast<Map<String, dynamic>>()
        .map(WalletTransaction.fromJson)
        .toList();
  }

  static Future<List<Withdrawal>> fetchWithdrawals() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/withdrawals?order=requested_at.desc',
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(Withdrawal.fromJson)
        .toList();
  }

  /// Requests a withdrawal via the server-side function (atomic deduct + insert).
  /// Returns the server response map; throws ApiException on validation failure.
  static Future<Map<String, dynamic>> requestWithdrawal({
    required int amountRs,
    required String upiId,
  }) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    return client.post(
      '/request-withdrawal',
      {'amount_rs': amountRs, 'upi_id': upiId},
      isFunction: true,
    );
  }

  static Future<int> fetchTodayWithdrawnPaise() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final data = await client.getList(
      '/rest/v1/withdrawals?requested_at=gte.$startOfDay&status=not.in.(failed,rejected)&select=amount',
    );
    return data.fold<int>(
      0,
      (sum, row) =>
          sum + (int.tryParse((row as Map<String, dynamic>)['amount']?.toString() ?? '') ?? 0),
    );
  }
}
