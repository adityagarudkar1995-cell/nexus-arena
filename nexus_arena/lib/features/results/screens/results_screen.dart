import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RESULTS')),
      body: const Center(
        child: Text(
          'Match results — coming in Phase 7',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
