import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class AddMoneyScreen extends StatelessWidget {
  const AddMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ADD MONEY')),
      body: const Center(
        child: Text(
          'Add money — coming in Phase 6',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
