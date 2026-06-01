import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/withdrawal.dart';
import '../services/wallet_service.dart';

class WithdrawalsState {
  final List<Withdrawal> items;
  final int todayWithdrawnPaise;

  const WithdrawalsState({
    this.items = const [],
    this.todayWithdrawnPaise = 0,
  });

  int get todayWithdrawnRs => todayWithdrawnPaise ~/ 100;
}

class WithdrawalsNotifier extends AsyncNotifier<WithdrawalsState> {
  @override
  Future<WithdrawalsState> build() => _fetch();

  Future<WithdrawalsState> _fetch() async {
    final results = await Future.wait([
      WalletService.fetchWithdrawals(),
      WalletService.fetchTodayWithdrawnPaise(),
    ]);
    return WithdrawalsState(
      items: results[0] as List<Withdrawal>,
      todayWithdrawnPaise: results[1] as int,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final withdrawalsProvider =
    AsyncNotifierProvider<WithdrawalsNotifier, WithdrawalsState>(
  WithdrawalsNotifier.new,
);
