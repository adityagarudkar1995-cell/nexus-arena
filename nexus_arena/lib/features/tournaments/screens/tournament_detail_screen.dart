import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../matches/services/match_service.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/tournament.dart';
import '../providers/tournament_provider.dart';
import '../services/tournament_service.dart';
import '../widgets/join_bottom_sheet.dart';
import '../widgets/prize_breakdown.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TournamentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> {
  Tournament? _tournament;
  String? _matchId;
  bool _loading = true;
  String? _error;
  bool _rulesExpanded = false;

  @override
  void initState() {
    super.initState();
    _seedFromCache();
    _load();
  }

  void _seedFromCache() {
    final cached = ref
        .read(tournamentsProvider)
        .valueOrNull
        ?.where((t) => t.id == widget.id)
        .toList();
    if (cached != null && cached.isNotEmpty) {
      _tournament = cached.first;
      _loading = false;
    }
  }

  Future<void> _load() async {
    // Start both fetches in parallel
    final tFuture = TournamentService.fetchTournamentById(widget.id);
    final mFuture = MatchService.fetchMatchForTournament(widget.id);
    try {
      final t = await tFuture;
      String? matchId;
      try {
        final m = await mFuture;
        matchId = m?.id;
      } catch (_) {} // Not registered yet or no match — silent
      if (mounted) {
        setState(() {
          _tournament = t;
          _matchId = matchId;
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _tournament == null) {
        setState(() { _error = e.message; _loading = false; });
      }
    }
  }

  void _onJoinTap() async {
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null || _tournament == null) return;

    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinBottomSheet(
        tournament: _tournament!,
        walletBalancePaise: wallet.balancePaise,
      ),
    );

    if (success == true && mounted) {
      ref.read(tournamentsProvider.notifier).refresh();
      ref.read(walletProvider.notifier).refresh();
      ref.read(myRegistrationsProvider.notifier).refresh();
      await _load(); // Also fetches match — sets _matchId if one exists

      if (!mounted) return;

      if (_matchId != null) {
        context.push('/match-lobby/$_matchId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '🎮 You\'re in! Room ID will be shared 15 min before match.',
            ),
            backgroundColor: AppColors.card,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reactively watch joined state
    final isJoined = ref
            .watch(myRegistrationsProvider)
            .valueOrNull
            ?.any((r) => r.tournamentId == widget.id && r.isActive) ??
        false;
    final walletAsync = ref.watch(walletProvider);

    if (_loading && _tournament == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_error != null && _tournament == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('RETRY')),
            ],
          ),
        ),
      );
    }

    final t = _tournament!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(t),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEntryFeeSection(t),
                  _buildDivider(),
                  _buildPrizeSection(t),
                  _buildDivider(),
                  _buildPlayersSection(t),
                  _buildDivider(),
                  _buildCountdownSection(t),
                  _buildDivider(),
                  _buildRulesSection(t),
                  const SizedBox(height: 80), // space for sticky button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildJoinButton(t, isJoined, walletAsync),
    );
  }

  // ── Sliver AppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(Tournament t) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => context.pop(),
        color: AppColors.textPrimary,
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Text(
          t.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: _buildBannerBackground(t),
      ),
    );
  }

  Widget _buildBannerBackground(Tournament t) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.purple.withValues(alpha: 0.7),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                t.game.toUpperCase(),
                style: TextStyle(
                  color: AppColors.muted.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Content Sections ───────────────────────────────────────────────────────

  Widget _buildEntryFeeSection(Tournament t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ENTRY FEE'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${t.entryFee}',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ModeChip(t.mode),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _TierChip(t.tournamentType, t.tier),
            ),
          ],
        ),
        if (t.mode != 'solo')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t.mode == 'duo'
                  ? 'IGL pays for both players'
                  : 'IGL pays for all 4 players',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPrizeSection(Tournament t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('PRIZE BREAKDOWN'),
            Text(
              'Pool: ₹${t.prizePoolRs}',
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrizeBreakdown(tournament: t),
      ],
    );
  }

  Widget _buildPlayersSection(Tournament t) {
    final filled = t.maxTeams > 0
        ? (t.registeredCount / t.maxTeams).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PLAYERS'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${t.registeredCount} / ${t.maxTeams} joined',
              style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
            ),
            Text(
              '${(filled * 100).toInt()}% full',
              style: TextStyle(
                color: filled >= 0.9 ? AppColors.danger : AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: filled,
            minHeight: 8,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
              filled >= 1.0 ? AppColors.danger : AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Min ${t.minPlayers} players required. Auto-cancel + refund if not reached.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCountdownSection(Tournament t) {
    final timeStr = DateFormat('EEEE, d MMM • h:mm a').format(t.scheduledAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('MATCH STARTS IN'),
        const SizedBox(height: 10),
        _CountdownDisplay(target: t.scheduledAt),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(timeStr,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
            SizedBox(width: 6),
            Text(
              'Room ID & password visible 15 min before match',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulesSection(Tournament t) {
    if (t.rules == null || t.rules!.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: _sectionLabel('MATCH RULES'),
        trailing: Icon(
          _rulesExpanded ? Icons.expand_less : Icons.expand_more,
          color: AppColors.muted,
        ),
        onExpansionChanged: (v) => setState(() => _rulesExpanded = v),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          Text(
            t.rules!,
            style: const TextStyle(color: AppColors.onSurface, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── JOIN Button ────────────────────────────────────────────────────────────

  Widget _buildJoinButton(
      Tournament t, bool isJoined, AsyncValue<dynamic> walletAsync) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _resolveButton(t, isJoined, walletAsync),
      ),
    );
  }

  Widget _resolveButton(
      Tournament t, bool isJoined, AsyncValue<dynamic> walletAsync) {
    final s = t.status;

    if (s == 'ongoing') {
      return _disabledBtn('MATCH IS LIVE', Colors.orange);
    }
    if (s == 'completed' || s == 'cancelled') {
      return _disabledBtn('TOURNAMENT ENDED', AppColors.muted);
    }
    if (s == 'registration_closed') {
      return _disabledBtn('REGISTRATION CLOSED', AppColors.muted);
    }
    if (isJoined) {
      if (_matchId != null) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/match-lobby/$_matchId'),
            icon: const Icon(Icons.door_sliding_outlined),
            label: const Text('VIEW MATCH LOBBY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent, width: 1.5),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        );
      }
      return _disabledBtn('✓  YOU\'RE IN', AppColors.accent);
    }
    if (t.isFull) {
      return _disabledBtn('TOURNAMENT FULL', AppColors.danger);
    }

    // Check wallet balance for a soft warning (actual enforcement is server-side)
    final balance = walletAsync.valueOrNull?.balancePaise ?? 0;
    final hasFunds = balance >= t.entryFee * 100;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _onJoinTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasFunds ? AppColors.accent : AppColors.danger,
          foregroundColor: AppColors.background,
        ),
        child: Text(
          hasFunds
              ? 'JOIN  ₹${t.entryFee}'
              : 'ADD MONEY TO JOIN  ₹${t.entryFee}',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _disabledBtn(String label, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          foregroundColor: color,
          disabledForegroundColor: color,
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(color: AppColors.surface, thickness: 1),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
}

// ── Mode / Tier chips ──────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String mode;
  const _ModeChip(this.mode);

  Color get _color => switch (mode) {
        'solo'  => AppColors.accent,
        'duo'   => AppColors.purple,
        'squad' => Colors.orange,
        _       => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        border: Border.all(color: _color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(mode.toUpperCase(),
          style: TextStyle(
              color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String type;
  final int tier;
  const _TierChip(this.type, this.tier);

  @override
  Widget build(BuildContext context) {
    final label = type == 'weekly' ? 'WEEKLY' : 'TIER $tier';
    final color = type == 'weekly' ? AppColors.gold : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Self-contained countdown widget ───────────────────────────────────────────

class _CountdownDisplay extends StatefulWidget {
  final DateTime target;
  const _CountdownDisplay({required this.target});

  @override
  State<_CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<_CountdownDisplay> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final diff = widget.target.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    if (diff.isNegative) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const Text(
        'Match has started!',
        style: TextStyle(
            color: Colors.orange, fontSize: 20, fontWeight: FontWeight.w700),
      );
    }

    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        _TimeBox(h, 'HRS'),
        _colon(),
        _TimeBox(m, 'MIN'),
        _colon(),
        _TimeBox(s, 'SEC'),
      ],
    );
  }

  Widget _colon() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(':',
            style: TextStyle(
                color: AppColors.accent,
                fontSize: 28,
                fontWeight: FontWeight.w700)),
      );
}

class _TimeBox extends StatelessWidget {
  final String value;
  final String unit;
  const _TimeBox(this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(unit,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }
}
