import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/payment_service.dart';
import '../widgets/amount_preset_chip.dart';

const _presets = [50, 100, 200, 500, 1000];

class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen> {
  late final Razorpay _razorpay;
  final _customCtrl = TextEditingController();

  int? _selectedPreset = 100;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customCtrl.dispose();
    super.dispose();
  }

  /// Effective amount: custom field wins when it holds a valid number.
  int? get _amountRs {
    final custom = _customCtrl.text.trim();
    if (custom.isNotEmpty) return int.tryParse(custom);
    return _selectedPreset;
  }

  String? get _validationError {
    final amt = _amountRs;
    if (amt == null) return null; // nothing entered yet — no error, just disabled
    if (amt < AppConstants.minTopUpRs) {
      return 'Minimum top-up is ₹${AppConstants.minTopUpRs}';
    }
    if (amt > AppConstants.maxTopUpRs) {
      return 'Maximum top-up is ₹${AppConstants.maxTopUpRs}';
    }
    return null;
  }

  bool get _canPay =>
      !_processing &&
      _amountRs != null &&
      _validationError == null &&
      AppConstants.razorpayKeyId.isNotEmpty;

  Future<void> _startPayment() async {
    final amount = _amountRs;
    if (amount == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _processing = true);

    try {
      final order = await PaymentService.createOrder(amount);
      if (!mounted) return;

      final profile = ref.read(authProvider).valueOrNull;
      _razorpay.open({
        'key': AppConstants.razorpayKeyId,
        'order_id': order.orderId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'name': 'NEXUS ARENA',
        'description': 'Wallet top-up',
        if (profile != null) 'prefill': {'contact': profile.phone},
        'theme': {'color': '#00FF88'},
      });
      // Checkout UI is now modal over the app; drop our own overlay.
      if (mounted) setState(() => _processing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showResultDialog(
        success: false,
        message: _orderErrorMessage(e),
      );
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      _showResultDialog(
        success: false,
        message: 'Payment could not be confirmed. If money was debited, it '
            'will reflect shortly or be auto-refunded.',
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final ok = await PaymentService.verifyPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      if (!mounted) return;
      setState(() => _processing = false);

      if (ok) {
        await ref.read(walletProvider.notifier).refresh();
        await ref.read(transactionsProvider.notifier).refresh();
        if (!mounted) return;
        _showResultDialog(success: true);
      } else {
        _showResultDialog(
          success: false,
          message: 'We could not verify this payment. Any debited amount will '
              'be reconciled automatically.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showResultDialog(
        success: false,
        message: 'Verification failed due to a network issue. Your balance '
            'will update automatically once confirmed.',
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final msg = response.message?.isNotEmpty == true
        ? response.message!
        : 'Payment was cancelled or failed.';
    _showResultDialog(success: false, message: msg);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected wallet: ${response.walletName ?? 'external'}'),
        backgroundColor: AppColors.card,
      ),
    );
  }

  String _orderErrorMessage(Object e) {
    final s = e.toString();
    if (s.contains('amount_too_low')) return 'Minimum top-up is ₹${AppConstants.minTopUpRs}.';
    if (s.contains('amount_too_high')) return 'Maximum top-up is ₹${AppConstants.maxTopUpRs}.';
    if (s.contains('payment_not_configured')) {
      return 'Payments are not configured yet. Please try again later.';
    }
    if (s.contains('invalid_auth')) return 'Session expired. Please sign in again.';
    return 'Could not start payment. Please try again.';
  }

  void _showResultDialog({required bool success, String? message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (success ? AppColors.accent : AppColors.danger)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: success ? AppColors.accent : AppColors.danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Money Added!' : 'Payment Failed',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              success
                  ? 'Your wallet has been topped up successfully.'
                  : (message ?? 'Something went wrong.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          if (success)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // close dialog
                  Navigator.of(context).pop(); // back to wallet
                },
                child: const Text('DONE'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('CANCEL',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('RETRY'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final balanceRs = walletAsync.valueOrNull?.balanceRs;
    final amt = _amountRs;
    final notConfigured = AppConstants.razorpayKeyId.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('ADD MONEY')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // Current balance
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                    Text(
                      balanceRs == null ? '—' : '₹$balanceRs',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CHOOSE AMOUNT',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((p) {
                  final selected =
                      _customCtrl.text.trim().isEmpty && _selectedPreset == p;
                  return AmountPresetChip(
                    amountRs: p,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        _selectedPreset = p;
                        _customCtrl.clear();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'OR ENTER AMOUNT',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  hintText: 'Custom amount',
                  errorText: _validationError,
                ),
                onChanged: (_) => setState(() {
                  if (_customCtrl.text.trim().isNotEmpty) _selectedPreset = null;
                }),
              ),
              const SizedBox(height: 24),
              // Summary
              if (amt != null && _validationError == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Amount', '₹$amt'),
                      const SizedBox(height: 8),
                      _summaryRow('Payment fee', '₹0'),
                      const Divider(height: 24, color: AppColors.muted),
                      _summaryRow('Total payable', '₹$amt', bold: true),
                    ],
                  ),
                ),
              if (notConfigured) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.danger, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Razorpay key not configured. Run with '
                          '--dart-define=RAZORPAY_KEY_ID=...',
                          style: TextStyle(
                              color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Sticky pay button
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _canPay ? _startPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.muted.withValues(alpha: 0.3),
              ),
              child: Text(
                amt == null ? 'ENTER AN AMOUNT' : 'PAY ₹$amt WITH RAZORPAY',
              ),
            ),
          ),
          // Processing overlay
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: bold ? AppColors.textPrimary : AppColors.muted,
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: bold ? AppColors.accent : AppColors.textPrimary,
            fontSize: bold ? 16 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
