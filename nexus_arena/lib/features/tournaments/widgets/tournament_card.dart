import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../models/tournament.dart';

class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final bool isJoined;
  final VoidCallback onCardTap;
  final VoidCallback onJoinTap;

  const TournamentCard({
    super.key,
    required this.tournament,
    required this.isJoined,
    required this.onCardTap,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopRow(),
                  const SizedBox(height: 8),
                  _buildTitle(),
                  const SizedBox(height: 10),
                  _buildFeeAndPool(),
                  const SizedBox(height: 8),
                  _buildPrizeBreakdown(),
                  const SizedBox(height: 10),
                  _buildProgress(),
                  const SizedBox(height: 12),
                  _buildBottomRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final hasImage =
        tournament.bannerUrl != null && tournament.bannerUrl!.isNotEmpty;
    if (hasImage) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: CachedNetworkImage(
          imageUrl: tournament.bannerUrl!,
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _gradientBanner(),
        ),
      );
    }
    return _gradientBanner();
  }

  Widget _gradientBanner() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.purple.withValues(alpha: 0.5),
              AppColors.surface,
            ],
          ),
        ),
        child: Center(
          child: Text(
            tournament.game.toUpperCase(),
            style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.35),
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        _ModeBadge(tournament.mode),
        const SizedBox(width: 6),
        _TierBadge(tournament.tournamentType, tournament.tier),
        const Spacer(),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final (label, color) = Tournament.statusDisplay(tournament.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      tournament.title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFeeAndPool() {
    return Row(
      children: [
        _InfoChip(
          label: 'Entry',
          value: '₹${tournament.entryFee}',
          valueColor: AppColors.accent,
        ),
        const SizedBox(width: 16),
        _InfoChip(
          label: 'Prize Pool',
          value: '₹${tournament.prizePoolRs}',
          valueColor: AppColors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildPrizeBreakdown() {
    // Only show placement breakdown if prizes are set
    if (tournament.prize1stPaise == 0) return const SizedBox.shrink();
    return Row(
      children: [
        _PrizeChip('🥇', '₹${tournament.prize1stRs}', AppColors.gold),
        const SizedBox(width: 10),
        _PrizeChip('🥈', '₹${tournament.prize2ndRs}', AppColors.silver),
        const SizedBox(width: 10),
        _PrizeChip('🥉', '₹${tournament.prize3rdRs}', AppColors.bronze),
        const Spacer(),
        const Text(
          'TDS 30% applies',
          style: TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final filled = tournament.maxTeams > 0
        ? (tournament.registeredCount / tournament.maxTeams).clamp(0.0, 1.0)
        : 0.0;
    final barColor =
        filled >= 1.0 ? AppColors.danger : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${tournament.registeredCount}/${tournament.maxTeams} players',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            Text(
              '${(filled * 100).toInt()}%',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: filled,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.access_time_rounded,
            size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          _matchTimeLabel(),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const Spacer(),
        _buildJoinButton(),
      ],
    );
  }

  String _matchTimeLabel() {
    final now = DateTime.now();
    final diff = tournament.scheduledAt.difference(now);
    final timeStr = DateFormat('h:mm a').format(tournament.scheduledAt);

    if (diff.isNegative) return timeStr;
    if (diff.inHours >= 2) return timeStr;
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes}m away';
    return 'Starting now';
  }

  Widget _buildJoinButton() {
    final s = tournament.status;

    if (s == 'ongoing') return _StatusPill('LIVE', Colors.orange);
    if (s == 'completed' || s == 'cancelled') {
      return _StatusPill('ENDED', AppColors.muted);
    }
    if (s == 'registration_closed') {
      return _StatusPill('CLOSED', AppColors.muted);
    }
    if (isJoined) return _StatusPill('JOINED ✓', AppColors.accent);
    if (tournament.isFull) return _StatusPill('FULL', AppColors.danger);

    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onJoinTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        child: Text('JOIN  ₹${tournament.entryFee}'),
      ),
    );
  }
}

// ── Small helper widgets ─────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final String mode;
  const _ModeBadge(this.mode);

  Color get _color => switch (mode) {
        'solo' => AppColors.accent,
        'duo' => AppColors.purple,
        'squad' => Colors.orange,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return _Pill(mode.toUpperCase(), _color);
  }
}

class _TierBadge extends StatelessWidget {
  final String type;
  final int tier;
  const _TierBadge(this.type, this.tier);

  @override
  Widget build(BuildContext context) {
    final label = type == 'weekly' ? 'WEEKLY' : 'T$tier';
    final color = type == 'weekly' ? AppColors.gold : AppColors.muted;
    return _Pill(label, color);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _InfoChip(
      {required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PrizeChip extends StatelessWidget {
  final String emoji;
  final String amount;
  final Color color;
  const _PrizeChip(this.emoji, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Text(amount,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
