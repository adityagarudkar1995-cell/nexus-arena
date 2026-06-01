import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class AmountPresetChip extends StatelessWidget {
  final int amountRs;
  final bool selected;
  final VoidCallback onTap;

  const AmountPresetChip({
    super.key,
    required this.amountRs,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.muted,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '₹$amountRs',
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
