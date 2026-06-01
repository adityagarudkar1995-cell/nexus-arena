import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';

class WalletStatsRow extends StatelessWidget {
  final int totalAddedRs;
  final int totalWonRs;
  final int totalWithdrawnRs;

  const WalletStatsRow({
    super.key,
    required this.totalAddedRs,
    required this.totalWonRs,
    required this.totalWithdrawnRs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _StatBox(
            label: 'TOTAL ADDED',
            valueRs: totalAddedRs,
            color: AppColors.accent,
            icon: Icons.south_west,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'TOTAL WON',
            valueRs: totalWonRs,
            color: AppColors.gold,
            icon: Icons.emoji_events_outlined,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'WITHDRAWN',
            valueRs: totalWithdrawnRs,
            color: AppColors.textSecondary,
            icon: Icons.north_east,
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int valueRs;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.valueRs,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.decimalPattern('en_IN').format(valueRs);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              '₹$formatted',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
