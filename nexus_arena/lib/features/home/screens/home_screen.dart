import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEXUS ARENA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent),
            onPressed: () => context.push('/wallet'),
          ),
        ],
      ),
      body: const Center(
        child: Text('Tournaments coming soon...', style: TextStyle(color: AppColors.muted)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Tournaments'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_outlined),  label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),        label: 'Profile'),
        ],
        onTap: (i) {
          if (i == 2) context.push('/profile');
        },
      ),
    );
  }
}
