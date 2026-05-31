import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: const Center(
        child: Text(
          'Settings — coming in Phase 8',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
