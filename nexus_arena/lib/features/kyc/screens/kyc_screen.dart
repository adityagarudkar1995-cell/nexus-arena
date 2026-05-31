import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC VERIFICATION')),
      body: const Center(
        child: Text(
          'KYC — coming in Phase 7',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
