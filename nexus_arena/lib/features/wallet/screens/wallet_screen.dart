import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_stats_row.dart';

class _Filter {
  final String label;
  final String? type; // null = All
  const _Filter(this.label, this.type);
}

const _filters = <_Filter>[
  _Filter('All', null),
  _Filter('Added', 'deposit'),
  _Filter('Won', 'prize'),
  _Filter('Entry Fee', 'entry_fee'),
  _Filter('Withdrawn', 'withdrawal'),
  _Filter('Refund', 'refund'),
];

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final txnAsync = ref.watch(transactionsProvider);
    final activeFilter = txnAsync.valueOrNull?.filterType;

    return Scaffold(
      appBar: AppBar(title: const Text('WALLET')),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await Future.wait([
            ref.read(walletProvider.notifier).refresh(),
            ref.read(transactionsProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // ── Balance card ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: walletAsync.when(
                loading: () => const _BalanceShimmer(),
                error: (_, _) => _BalanceError(
                  onRetry: () => ref.read(walletProvider.notifier).refresh(),
                ),
                data: (wallet) => BalanceCard(
                  balanceRs: wallet.balanceRs,
                  onAddMoney: () => context.push('/add-money'),
                  onWithdraw: () => context.push('/withdraw'),
                ),
              ),
            ),
            // ── Stats row ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: walletAsync.maybeWhen(
                data: (wallet) => WalletStatsRow(
                  totalAddedRs: wallet.totalDepositedRs,
                  totalWonRs: wallet.totalWonRs,
                  totalWithdrawnRs: wallet.totalWithdrawnRs,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            // ── Section title + filter tabs ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: const [
                    Text(
                      'TRANSACTIONS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final selected = f.type == activeFilter;
                    return _FilterChip(
                      label: f.label,
                      selected: selected,
                      onTap: () => ref
                          .read(transactionsProvider.notifier)
                          .setFilter(f.type),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // ── Transaction list ──────────────────────────────────────────
            txnAsync.when(
              loading: () => const _TxnListShimmer(),
              error: (e, _) => SliverToBoxAdapter(
                child: _TxnError(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(transactionsProvider.notifier).refresh(),
                ),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return const SliverToBoxAdapter(child: _TxnEmpty());
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i == state.items.length) {
                        return _LoadMoreFooter(
                          hasMore: state.hasMore,
                          loading: state.loadingMore,
                          onLoadMore: () => ref
                              .read(transactionsProvider.notifier)
                              .loadMore(),
                        );
                      }
                      return TransactionTile(txn: state.items[i]);
                    },
                    childCount: state.items.length + 1,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.muted,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Load more footer ──────────────────────────────────────────────────────────

class _LoadMoreFooter extends StatelessWidget {
  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;

  const _LoadMoreFooter({
    required this.hasMore,
    required this.loading,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No more transactions',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: OutlinedButton(
        onPressed: onLoadMore,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(double.infinity, 44),
          side: const BorderSide(color: AppColors.accent, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('LOAD MORE'),
      ),
    );
  }
}

// ── Empty / error / shimmer states ────────────────────────────────────────────

class _TxnEmpty extends StatelessWidget {
  const _TxnEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.muted),
          SizedBox(height: 14),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Add money or join a tournament to get started',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TxnError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TxnError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text(
            'Failed to load transactions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('RETRY'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceError extends StatelessWidget {
  final VoidCallback onRetry;
  const _BalanceError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Could not load balance',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'RETRY',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceShimmer extends StatelessWidget {
  const _BalanceShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        height: 180,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _TxnListShimmer extends StatelessWidget {
  const _TxnListShimmer();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Column(
          children: List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 160,
                          height: 13,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
