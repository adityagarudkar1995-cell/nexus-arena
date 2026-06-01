import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../models/wallet_transaction.dart';

class TransactionTile extends StatelessWidget {
  final WalletTransaction txn;

  const TransactionTile({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(txn.type);
    final amountColor = txn.isCredit ? AppColors.accent : AppColors.danger;
    final sign = txn.isCredit ? '+' : '-';
    final amount = NumberFormat.decimalPattern('en_IN').format(txn.amountRs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.icon, size: 20, color: meta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description ?? meta.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign₹$amount',
            style: TextStyle(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  _TxnMeta _metaFor(String type) {
    return switch (type) {
      'deposit' => const _TxnMeta(
          'Money Added', Icons.account_balance_wallet, AppColors.accent),
      'entry_fee' => const _TxnMeta(
          'Entry Fee', Icons.emoji_events_outlined, AppColors.purple),
      'prize' =>
        const _TxnMeta('Prize Won', Icons.star_outline, AppColors.gold),
      'tds' => const _TxnMeta(
          'TDS Deducted', Icons.account_balance_outlined, AppColors.muted),
      'refund' =>
        const _TxnMeta('Refund', Icons.replay_outlined, AppColors.silver),
      'withdrawal' => const _TxnMeta(
          'Withdrawal', Icons.arrow_outward, AppColors.danger),
      _ => const _TxnMeta('Transaction', Icons.swap_horiz, AppColors.muted),
    };
  }
}

class _TxnMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _TxnMeta(this.label, this.icon, this.color);
}
