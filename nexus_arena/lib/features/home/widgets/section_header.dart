import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final bool isSpecial;

  const SectionHeader({super.key, required this.title, this.isSpecial = false});

  @override
  Widget build(BuildContext context) {
    final barColor = isSpecial ? AppColors.gold : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          if (isSpecial) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: const Text(
                'SUNDAY ONLY',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
