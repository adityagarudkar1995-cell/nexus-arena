import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../models/match_lobby.dart';
import '../services/match_service.dart';
import '../widgets/lobby_countdown.dart';
import '../widgets/room_card.dart';

class MatchLobbyScreen extends ConsumerStatefulWidget {
  final String id; // matchId
  const MatchLobbyScreen({super.key, required this.id});

  @override
  ConsumerState<MatchLobbyScreen> createState() => _MatchLobbyScreenState();
}

class _MatchLobbyScreenState extends ConsumerState<MatchLobbyScreen>
    with SingleTickerProviderStateMixin {
  MatchLobby? _lobby;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Pulse animation for "ROOM OPEN" banner
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _load();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lobby = await MatchService.fetchMatchLobby(widget.id);
      if (mounted) setState(() { _lobby = lobby; _loading = false; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MATCH LOBBY'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_lobby != null) _StatusBadge(_lobby!.status),
          const SizedBox(width: 12),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _lobby == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null && _lobby == null) {
      return _buildError();
    }
    final l = _lobby!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildMatchInfoCard(l),
            const SizedBox(height: 28),
            _buildStateContent(l),
            if (!_isTerminal(l.status)) ...[
              const SizedBox(height: 32),
              _buildHowToJoin(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined,
                size: 72, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Could not load match lobby',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Match info card ────────────────────────────────────────────────────────

  Widget _buildMatchInfoCard(MatchLobby l) {
    final timeStr = DateFormat('EEEE, d MMM • h:mm a').format(l.scheduledAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports_outlined,
              color: AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FREE FIRE',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2),
                ),
                const SizedBox(height: 2),
                Text(timeStr,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (l.roomIdVisibleAt != null) ...[
            const Icon(Icons.lock_clock_outlined,
                color: AppColors.muted, size: 14),
            const SizedBox(width: 4),
            Text(
              'Room: ${DateFormat('h:mm a').format(l.roomIdVisibleAt!)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ── State-dependent content ────────────────────────────────────────────────

  Widget _buildStateContent(MatchLobby l) {
    if (l.status == 'cancelled') return _buildCancelledState();
    if (l.status == 'completed') return _buildCompletedState();
    if (l.status == 'live') return _buildLiveState(l);
    if (l.isRoomVisible) return _buildOpenState(l);
    return _buildLockedState(l);
  }

  Widget _buildLockedState(MatchLobby l) {
    return Column(
      children: [
        const Icon(Icons.lock_outline_rounded, size: 80, color: AppColors.muted),
        const SizedBox(height: 16),
        const Text(
          'Room Not Open Yet',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Room ID and password will be revealed\n15 minutes before the match starts.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (l.roomIdVisibleAt != null)
          LobbyCountdown(
            target: l.roomIdVisibleAt!,
            headerLabel: 'ROOM OPENS IN',
            expiredLabel: 'Room is about to open...',
          )
        else
          Text(
            'Room details will appear here soon',
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildOpenState(MatchLobby l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent
                  .withValues(alpha: 0.08 + 0.06 * _pulseAnim.value),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.accent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(
                        alpha: 0.5 + 0.5 * _pulseAnim.value),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ROOM IS OPEN',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        RoomCard(
          roomId: l.roomId!,
          roomPassword: l.roomPassword!,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _share(l),
            icon: const Icon(Icons.share_outlined),
            label: const Text('SHARE WITH TEAM'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              minimumSize: const Size(0, 48),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 14, color: AppColors.danger),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Share ONLY with your team members — don\'t post publicly.',
                  style:
                      TextStyle(color: AppColors.danger, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveState(MatchLobby l) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_esports_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'MATCH IS LIVE',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'The match is in progress!\nResults will be posted after it ends.',
          style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.push('/results'),
          icon: const Icon(Icons.leaderboard_outlined),
          label: const Text('VIEW RESULTS'),
        ),
      ],
    );
  }

  Widget _buildCompletedState() {
    return Column(
      children: [
        const Icon(Icons.emoji_events_outlined,
            size: 72, color: AppColors.muted),
        const SizedBox(height: 16),
        const Text(
          'Match Completed',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'The match has ended. Check the results screen to see the winners.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.push('/results'),
          icon: const Icon(Icons.leaderboard_outlined),
          label: const Text('VIEW RESULTS'),
        ),
      ],
    );
  }

  Widget _buildCancelledState() {
    return Column(
      children: [
        const Icon(Icons.cancel_outlined, size: 72, color: AppColors.danger),
        const SizedBox(height: 16),
        const Text(
          'Match Cancelled',
          style: TextStyle(
              color: AppColors.danger,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'This match was cancelled due to insufficient players.\nYour entry fee has been refunded to your wallet.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.go('/wallet'),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('VIEW WALLET'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  // ── How to join steps ──────────────────────────────────────────────────────

  Widget _buildHowToJoin() {
    const steps = [
      'Open Free Fire and tap the Battle button on the home screen',
      'Select Room → Enter Room from the mode selector',
      'Type in the Room ID shown above',
      'Enter the Room Password when prompted',
      'Choose your character and tap Ready',
      'Wait for the host to start — good luck! 🎮',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW TO JOIN',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isTerminal(String status) =>
      status == 'completed' || status == 'cancelled';

  Future<void> _share(MatchLobby l) async {
    final time = DateFormat('h:mm a').format(l.scheduledAt);
    await SharePlus.instance.share(
      ShareParams(
        text: '🎮 NEXUS ARENA Match\n'
            'Room ID: ${l.roomId}\n'
            'Password: ${l.roomPassword}\n'
            'Match Time: $time\n\n'
            "Join the Free Fire room and let's battle!",
        subject: 'NEXUS ARENA Match Details',
      ),
    );
  }
}

// ── Status badge for AppBar ────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  (String, Color) get _display => switch (status) {
        'pending'   => ('UPCOMING', AppColors.muted),
        'live'      => ('LIVE', Colors.orange),
        'completed' => ('ENDED', AppColors.muted),
        'cancelled' => ('CANCELLED', AppColors.danger),
        _           => ('UNKNOWN', AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _display;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
