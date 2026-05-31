import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/tournament.dart';

class PrizeBreakdown extends StatelessWidget {
  final Tournament tournament;
  const PrizeBreakdown({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final hasPrizes = tournament.prize1stPaise > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasPrizes)
          const Text(
            'Prizes to be announced',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          )
        else ...[
          _PrizeRow('🥇', '1st Place', '₹${tournament.prize1stRs}', AppColors.gold),
          const SizedBox(height: 8),
          _PrizeRow('🥈', '2nd Place', '₹${tournament.prize2ndRs}', AppColors.silver),
          const SizedBox(height: 8),
          _PrizeRow('🥉', '3rd Place', '₹${tournament.prize3rdRs}', AppColors.bronze),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.danger),
                SizedBox(width: 6),
                Text(
                  'TDS 30% will be deducted on all winnings',
                  style: TextStyle(color: AppColors.danger, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PrizeRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String amount;
  final Color color;

  const _PrizeRow(this.emoji, this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(amount,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
