import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../matches/services/match_service.dart';
import '../../../core/api_client.dart';
import '../models/tournament.dart';

class JoinBottomSheet extends ConsumerStatefulWidget {
  final Tournament tournament;
  final int walletBalancePaise;

  const JoinBottomSheet({
    super.key,
    required this.tournament,
    required this.walletBalancePaise,
  });

  @override
  ConsumerState<JoinBottomSheet> createState() => _JoinBottomSheetState();
}

class _JoinBottomSheetState extends ConsumerState<JoinBottomSheet> {
  final _teamNameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    super.dispose();
  }

  int get _entryFeePaise => widget.tournament.entryFee * 100;
  int get _balanceAfterPaise => widget.walletBalancePaise - _entryFeePaise;
  bool get _hasFunds => widget.walletBalancePaise >= _entryFeePaise;
  bool get _needsTeam => widget.tournament.mode != 'solo';

  Future<void> _confirm() async {
    setState(() { _loading = true; _error = null; });
    try {
      await MatchService.joinTournament(
        widget.tournament.id,
        teamName: _needsTeam && _teamNameCtrl.text.trim().isNotEmpty
            ? _teamNameCtrl.text.trim()
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = _mapError(e.message); });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  String _mapError(String code) => switch (code) {
        'insufficient_funds'    => 'Not enough balance. Add money to your wallet first.',
        'already_registered'   => 'You\'re already registered for this tournament.',
        'tournament_full'      => 'This tournament just became full.',
        'registration_not_open' => 'Registration is no longer open.',
        _                      => 'Something went wrong. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(),
            const Divider(color: AppColors.surface, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeeRow(),
                  const SizedBox(height: 10),
                  _buildBalanceRow(),
                  const SizedBox(height: 10),
                  _buildAfterRow(),
                  if (!_hasFunds) _buildLowFundsWarning(),
                  if (_needsTeam) _buildTeamNameField(),
                  if (_error != null) _buildError(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildActions(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'CONFIRM ENTRY',
          style: TextStyle(
            color: AppColors.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w700, letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.tournament.title,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }

  Widget _buildFeeRow() => _Row(
        label: 'Entry Fee',
        value: '₹${widget.tournament.entryFee}',
        valueColor: AppColors.onSurface,
      );

  Widget _buildBalanceRow() => _Row(
        label: 'Your Balance',
        value: '₹${widget.walletBalancePaise ~/ 100}',
        valueColor: _hasFunds ? AppColors.accent : AppColors.danger,
      );

  Widget _buildAfterRow() => _Row(
        label: 'Balance After Joining',
        value: _hasFunds
            ? '₹${_balanceAfterPaise ~/ 100}'
            : '—',
        valueColor: _hasFunds ? AppColors.onSurface : AppColors.muted,
      );

  Widget _buildLowFundsWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wallet_outlined, size: 16, color: AppColors.danger),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Insufficient balance. Please add money first.',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamNameField() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextField(
        controller: _teamNameCtrl,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Team Name (optional)',
          hintText: 'e.g. Team Alpha',
          prefixIcon: const Icon(Icons.group_outlined, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _error!,
        style: const TextStyle(color: AppColors.danger, fontSize: 13),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.muted,
                side: const BorderSide(color: AppColors.muted),
                minimumSize: const Size(0, 50),
              ),
              child: const Text('CANCEL'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_loading || !_hasFunds) ? null : _confirm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
                disabledBackgroundColor: AppColors.muted.withValues(alpha: 0.3),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : Text('CONFIRM  ₹${widget.tournament.entryFee}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _Row({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
