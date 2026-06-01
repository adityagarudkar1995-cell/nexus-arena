import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/withdrawal.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/withdrawals_provider.dart';
import '../services/wallet_service.dart';

const _minRs = 100;
final _upiRe = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _amountCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  int get _remainingDailyRs {
    final today = ref.read(withdrawalsProvider).valueOrNull?.todayWithdrawnRs ?? 0;
    return (AppConstants.maxWithdrawalPerDayRs - today).clamp(0, AppConstants.maxWithdrawalPerDayRs);
  }

  int _maxWithdrawableRs(int balanceRs) {
    final r = _remainingDailyRs;
    return balanceRs < r ? balanceRs : r;
  }

  String? _amountError(int balanceRs) {
    final txt = _amountCtrl.text.trim();
    if (txt.isEmpty) return null;
    final amt = int.tryParse(txt);
    if (amt == null) return 'Enter a valid amount';
    if (amt < _minRs) return 'Minimum withdrawal is ₹$_minRs';
    if (amt > balanceRs) return 'Amount exceeds wallet balance';
    if (amt > _remainingDailyRs) {
      return 'Exceeds today\'s remaining limit (₹$_remainingDailyRs)';
    }
    return null;
  }

  String? get _upiError {
    final txt = _upiCtrl.text.trim();
    if (txt.isEmpty) return null;
    if (!_upiRe.hasMatch(txt)) return 'Enter a valid UPI ID (name@bank)';
    return null;
  }

  bool _canSubmit(int balanceRs) {
    final amt = int.tryParse(_amountCtrl.text.trim());
    return !_submitting &&
        amt != null &&
        _amountError(balanceRs) == null &&
        _upiCtrl.text.trim().isNotEmpty &&
        _upiError == null;
  }

  Future<void> _submit(int balanceRs) async {
    final amt = int.parse(_amountCtrl.text.trim());
    final upi = _upiCtrl.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await WalletService.requestWithdrawal(amountRs: amt, upiId: upi);
      await Future.wait([
        ref.read(walletProvider.notifier).refresh(),
        ref.read(withdrawalsProvider.notifier).refresh(),
        ref.read(transactionsProvider.notifier).refresh(),
      ]);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _amountCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal requested. It will be processed soon.'),
          backgroundColor: AppColors.card,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendly(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('insufficient_funds')) return 'Insufficient wallet balance.';
    if (s.contains('kyc_not_approved')) return 'Complete KYC to withdraw.';
    if (s.contains('daily_limit_exceeded')) {
      return 'Daily withdrawal limit (₹${AppConstants.maxWithdrawalPerDayRs}) reached.';
    }
    if (s.contains('invalid_upi')) return 'Invalid UPI ID.';
    if (s.contains('amount_too_low')) return 'Minimum withdrawal is ₹$_minRs.';
    return 'Withdrawal failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final profile = ref.watch(authProvider).valueOrNull;
    final withdrawalsAsync = ref.watch(withdrawalsProvider);
    final balanceRs = walletAsync.valueOrNull?.balanceRs ?? 0;
    final kycApproved = profile?.isKycApproved ?? false;

    // One-time UPI prefill from profile.
    if (!_prefilled && profile?.upiId != null && profile!.upiId!.isNotEmpty) {
      _upiCtrl.text = profile.upiId!;
      _prefilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('WITHDRAW')),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await Future.wait([
            ref.read(walletProvider.notifier).refresh(),
            ref.read(withdrawalsProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Balance + daily limit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available Balance',
                          style: TextStyle(color: AppColors.muted, fontSize: 14)),
                      Text('₹$balanceRs',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Today's remaining limit",
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      Text('₹$_remainingDailyRs of ₹${AppConstants.maxWithdrawalPerDayRs}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!kycApproved)
              _KycBanner(
                status: profile?.kycStatus ?? 'pending',
                onTap: () => context.push('/kyc'),
              )
            else ...[
              // Amount
              TextField(
                controller: _amountCtrl,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                  helperText:
                      'Min ₹$_minRs · Max ₹${_maxWithdrawableRs(balanceRs)} now',
                  helperStyle: const TextStyle(color: AppColors.muted),
                  errorText: _amountError(balanceRs),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // UPI
              TextField(
                controller: _upiCtrl,
                enabled: !_submitting,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'name@bank',
                  errorText: _upiError,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    _canSubmit(balanceRs) ? () => _submit(balanceRs) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor:
                      AppColors.muted.withValues(alpha: 0.3),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.background),
                      )
                    : const Text('SUBMIT REQUEST'),
              ),
            ],

            const SizedBox(height: 28),
            const Text(
              'PAST REQUESTS',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            withdrawalsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
              ),
              error: (e, _) => Text('Could not load requests: $e',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              data: (state) {
                if (state.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No withdrawal requests yet',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  );
                }
                return Column(
                  children: state.items
                      .map((w) => _WithdrawalTile(withdrawal: w))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── KYC gate banner ───────────────────────────────────────────────────────────

class _KycBanner extends StatelessWidget {
  final String status;
  final VoidCallback onTap;

  const _KycBanner({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (msg, cta) = switch (status) {
      'submitted' => ('Your KYC is under review. Withdrawals unlock once approved.', 'VIEW STATUS'),
      'rejected' => ('Your KYC was rejected. Resubmit your documents to withdraw.', 'RESUBMIT KYC'),
      _ => ('Complete KYC verification to withdraw your winnings.', 'COMPLETE KYC'),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text('KYC Required',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(color: AppColors.onSurface, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Withdrawal history tile ───────────────────────────────────────────────────

class _WithdrawalTile extends StatelessWidget {
  final Withdrawal withdrawal;
  const _WithdrawalTile({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (withdrawal.status) {
      'pending' => ('Pending', AppColors.gold),
      'processing' => ('Processing', AppColors.purple),
      'completed' => ('Completed', AppColors.accent),
      'rejected' => ('Rejected', AppColors.danger),
      'failed' => ('Failed', AppColors.danger),
      _ => (withdrawal.status, AppColors.muted),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${withdrawal.amountRs}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(withdrawal.upiId,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(withdrawal.requestedAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if (withdrawal.isRejected && withdrawal.rejectionReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Reason: ${withdrawal.rejectionReason}',
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
