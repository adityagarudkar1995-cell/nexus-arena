import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';

class WalletNotifier extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() => WalletService.fetchWallet();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(WalletService.fetchWallet);
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, Wallet>(
  WalletNotifier.new,
);
