import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../../tournaments/widgets/tournament_card.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(tournamentsProvider);
    final walletAsync = ref.watch(walletProvider);
    final joinedIds = ref.watch(joinedTournamentIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NEXUS ARENA',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          _WalletBalanceButton(walletAsync: walletAsync),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: tournamentsAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => _buildError(context, ref, e.toString()),
        data: (tournaments) {
          final daily = tournaments.where((t) => t.isDaily).toList();
          final weekly = tournaments.where((t) => t.isWeekly).toList();
          final showWeekly = weekly.isNotEmpty && _shouldShowWeekly();

          if (daily.isEmpty && !showWeekly) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(tournamentsProvider.notifier).refresh(),
                ref.read(walletProvider.notifier).refresh(),
                ref.read(myRegistrationsProvider.notifier).refresh(),
              ]);
            },
            color: AppColors.accent,
            backgroundColor: AppColors.card,
            child: CustomScrollView(
              slivers: [
                if (daily.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(title: "TODAY'S TOURNAMENTS"),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TournamentCard(
                            tournament: daily[i],
                            isJoined: joinedIds.contains(daily[i].id),
                            onCardTap: () =>
                                context.push('/tournament/${daily[i].id}'),
                            onJoinTap: () =>
                                context.push('/tournament/${daily[i].id}'),
                          ),
                        ),
                        childCount: daily.length,
                      ),
                    ),
                  ),
                ],
                if (showWeekly) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                        title: 'WEEKLY SPECIAL', isSpecial: true),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TournamentCard(
                            tournament: weekly[i],
                            isJoined: joinedIds.contains(weekly[i].id),
                            onCardTap: () =>
                                context.push('/tournament/${weekly[i].id}'),
                            onJoinTap: () =>
                                context.push('/tournament/${weekly[i].id}'),
                          ),
                        ),
                        childCount: weekly.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.push('/wallet');
          if (i == 2) context.push('/results');
          if (i == 3) context.push('/profile');
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

  bool _shouldShowWeekly() {
    // Show Thu–Sun (3 days before + Sunday itself)
    return DateTime.now().weekday >= 4;
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const _SkeletonCard(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 72, color: AppColors.muted),
          const SizedBox(height: 16),
          const Text(
            'No tournaments today',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back soon for upcoming matches',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Failed to load tournaments',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(tournamentsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wallet balance AppBar button ─────────────────────────────────────────────

class _WalletBalanceButton extends StatelessWidget {
  final AsyncValue<dynamic> walletAsync;
  const _WalletBalanceButton({required this.walletAsync});

  @override
  Widget build(BuildContext context) {
    return walletAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      error: (_, _) => IconButton(
        icon: const Icon(Icons.account_balance_wallet_outlined,
            color: AppColors.muted),
        onPressed: () => context.push('/wallet'),
      ),
      data: (wallet) => TextButton.icon(
        onPressed: () => context.push('/wallet'),
        icon: const Icon(Icons.account_balance_wallet_outlined,
            size: 16, color: AppColors.accent),
        label: Text(
          '₹${wallet.balanceRs}',
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

// ── Shimmer skeleton card ─────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner placeholder
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge row
                Row(children: [
                  _box(60, 20),
                  const SizedBox(width: 6),
                  _box(40, 20),
                  const Spacer(),
                  _box(50, 20),
                ]),
                const SizedBox(height: 10),
                _box(200, 18),
                const SizedBox(height: 10),
                Row(children: [_box(80, 14), const SizedBox(width: 16), _box(100, 14)]),
                const SizedBox(height: 10),
                Row(children: [_box(60, 14), const SizedBox(width: 10), _box(60, 14), const SizedBox(width: 10), _box(60, 14)]),
                const SizedBox(height: 10),
                _box(double.infinity, 6),
                const SizedBox(height: 12),
                Row(children: [_box(90, 14), const Spacer(), _box(90, 32)]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
