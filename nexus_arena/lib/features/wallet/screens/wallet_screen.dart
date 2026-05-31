import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WALLET')),
      body: const Center(
        child: Text(
          'Wallet — coming in Phase 5',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
