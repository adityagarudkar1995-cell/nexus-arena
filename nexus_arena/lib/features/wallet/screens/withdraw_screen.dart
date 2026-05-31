import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class WithdrawScreen extends StatelessWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WITHDRAW')),
      body: const Center(
        child: Text(
          'Withdrawal — coming in Phase 7',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
