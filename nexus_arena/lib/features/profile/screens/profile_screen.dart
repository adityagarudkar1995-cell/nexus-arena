import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE')),
      body: const Center(
        child: Text(
          'Profile — coming in Phase 8',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
