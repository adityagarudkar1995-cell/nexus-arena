import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authProvider);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        actions: [
          profileAsync.maybeWhen(
            data: (p) => p != null && p.canEditProfile
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.accent),
                    onPressed: () => context.push('/edit-profile'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: AppColors.muted),
              const SizedBox(height: 12),
              const Text('Could not load profile',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('RETRY'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent)),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => context.go('/phone'));
            return const SizedBox.shrink();
          }
          final totalWonRs = walletAsync.valueOrNull?.totalWonRs ?? 0;
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              await Future.wait([
                ref.read(authProvider.notifier).refresh(),
                ref.read(walletProvider.notifier).refresh(),
              ]);
            },
            child: ListView(
              children: [
                _ProfileHeader(profile: profile),
                _StatsRow(profile: profile, totalWonRs: totalWonRs),
                const SizedBox(height: 8),
                _MenuSection(profile: profile, ref: ref),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 0) context.go('/home');
          if (i == 1) context.push('/wallet');
          if (i == 2) context.push('/results');
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined), label: 'Tournaments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Wallet'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined), label: 'Results'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Profile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initials = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';
    final (kycLabel, kycColor) = switch (profile.kycStatus) {
      'approved' => ('KYC Verified', AppColors.accent),
      'submitted' => ('KYC Under Review', AppColors.gold),
      'rejected' => ('KYC Rejected', AppColors.danger),
      _ => ('KYC Pending', AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.background,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.phone,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          if (profile.gameUid != null) ...[
            const SizedBox(height: 4),
            Text(
              'Free Fire UID: ${profile.gameUid}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: kycColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kycColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  profile.isKycApproved
                      ? Icons.verified_rounded
                      : Icons.shield_outlined,
                  size: 14,
                  color: kycColor,
                ),
                const SizedBox(width: 5),
                Text(
                  kycLabel,
                  style: TextStyle(
                    color: kycColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatefulWidget {
  final Profile profile;
  final int totalWonRs;
  const _StatsRow({required this.profile, required this.totalWonRs});

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  int _matchesPlayed = 0;
  int _wins = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await ProfileService.fetchPlayerStats();
      if (mounted) {
        setState(() {
          _matchesPlayed = stats.matchesPlayed;
          _wins = stats.wins;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatBox(
            label: 'MATCHES',
            value: _loaded ? '$_matchesPlayed' : '—',
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'WINS',
            value: _loaded ? '$_wins' : '—',
            color: AppColors.gold,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'EARNED',
            value: '₹${widget.totalWonRs}',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu ──────────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final Profile profile;
  final WidgetRef ref;
  const _MenuSection({required this.profile, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'ACCOUNT',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.edit_outlined,
          label: 'Edit Profile',
          subtitle: profile.canEditProfile
              ? null
              : 'Locked until ${_fmt(profile.nextEditAllowedAt)}',
          onTap: () => context.push('/edit-profile'),
        ),
        _MenuItem(
          icon: Icons.shield_outlined,
          label: 'KYC Verification',
          trailing: _kycBadge(profile.kycStatus),
          onTap: () => context.push('/kyc'),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'WALLET',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.history_outlined,
          label: 'Transaction History',
          onTap: () => context.push('/wallet'),
        ),
        _MenuItem(
          icon: Icons.arrow_outward,
          label: 'Withdraw',
          onTap: () => context.push('/withdraw'),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'APP',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => context.push('/settings'),
        ),
        const Divider(
          height: 32,
          indent: 16,
          endIndent: 16,
          color: AppColors.card,
        ),
        _MenuItem(
          icon: Icons.logout,
          label: 'Sign Out',
          color: AppColors.danger,
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SIGN OUT',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) context.go('/phone');
    }
  }

  Widget? _kycBadge(String status) {
    final (label, color) = switch (status) {
      'approved' => ('Verified', AppColors.accent),
      'submitted' => ('In Review', AppColors.gold),
      'rejected' => ('Rejected', AppColors.danger),
      _ => ('Pending', AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(color: AppColors.muted, fontSize: 11))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
    );
  }
}
