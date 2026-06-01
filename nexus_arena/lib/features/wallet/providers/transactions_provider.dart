import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';

/// Immutable state for the paginated, filterable transaction list.
class TransactionsState {
  final List<WalletTransaction> items;
  final String? filterType; // null = All
  final bool hasMore;
  final bool loadingMore;

  const TransactionsState({
    this.items = const [],
    this.filterType,
    this.hasMore = true,
    this.loadingMore = false,
  });

  TransactionsState copyWith({
    List<WalletTransaction>? items,
    Object? filterType = _sentinel,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return TransactionsState(
      items: items ?? this.items,
      filterType:
          filterType == _sentinel ? this.filterType : filterType as String?,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  static const _sentinel = Object();
}

class TransactionsNotifier extends AsyncNotifier<TransactionsState> {
  static const _pageSize = 20;

  @override
  Future<TransactionsState> build() => _fetchPage(filterType: null);

  Future<TransactionsState> _fetchPage({required String? filterType}) async {
    final page = await WalletService.fetchTransactions(
      type: filterType,
      limit: _pageSize,
      offset: 0,
    );
    return TransactionsState(
      items: page,
      filterType: filterType,
      hasMore: page.length == _pageSize,
      loadingMore: false,
    );
  }

  /// Switch the active filter and reload from the first page.
  Future<void> setFilter(String? type) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(filterType: type));
  }

  /// Pull-to-refresh keeps the current filter.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchPage(filterType: current?.filterType),
    );
  }

  /// Append the next page; no-op if already loading or exhausted.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(loadingMore: true));
    try {
      final next = await WalletService.fetchTransactions(
        type: current.filterType,
        limit: _pageSize,
        offset: current.items.length,
      );
      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...next],
          hasMore: next.length == _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Surface the failure but keep what we already have.
      state = AsyncValue.data(current.copyWith(loadingMore: false));
    }
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, TransactionsState>(
  TransactionsNotifier.new,
);
