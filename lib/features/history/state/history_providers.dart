import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/models/models.dart';
import '../../auth/state/auth_providers.dart';
import '../../review/state/review_providers.dart';
import '../data/history_filters.dart';
import '../data/history_repository.dart';

export '../data/history_filters.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(
    observationRepository: ref.read(observationRepositoryProvider),
  );
});

/// Paginated list state for the History & Audit screen.
class HistoryState {
  const HistoryState({
    this.filters = const HistoryFilters(),
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final HistoryFilters filters;
  final List<ObservationModel> items;
  final int page;
  final bool hasMore;
  final int total;

  /// First-page load in progress (full-screen loading state).
  final bool loading;

  /// Next-page load in progress (footer spinner; list stays visible).
  final bool loadingMore;

  /// First-page failure (full-screen error state with Retry).
  final Object? error;

  /// Next-page failure (footer retry; already-loaded rows stay visible).
  final String? loadMoreError;

  HistoryState copyWith({
    HistoryFilters? filters,
    List<ObservationModel>? items,
    int? page,
    bool? hasMore,
    int? total,
    bool? loading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return HistoryState(
      filters: filters ?? this.filters,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Owns filters + pages. Changing a filter resets to page 1; a stale
/// response from a superseded request (user changed filters mid-flight) is
/// dropped via [_generation] so rows from two filter sets never mix.
class HistoryController extends StateNotifier<HistoryState> {
  HistoryController(
    this._repository, {
    required this.asReviewer,
    this.perPage = 20,
  }) : super(const HistoryState()) {
    refresh();
  }

  final HistoryRepository _repository;
  final bool asReviewer;
  final int perPage;
  int _generation = 0;

  Future<void> refresh() async {
    final gen = ++_generation;
    state = state.copyWith(
      loading: true,
      loadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final result = await _repository.search(
        asReviewer: asReviewer,
        filters: state.filters,
        page: 1,
        perPage: perPage,
      );
      if (!mounted || gen != _generation) return;
      state = state.copyWith(
        items: result.items,
        page: result.currentPage,
        hasMore: result.hasMore,
        total: result.total,
        loading: false,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(loading: false, error: e, items: const []);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final result = await _repository.search(
        asReviewer: asReviewer,
        filters: state.filters,
        page: state.page + 1,
        perPage: perPage,
      );
      if (!mounted || gen != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        page: result.currentPage,
        hasMore: result.hasMore,
        total: result.total,
        loadingMore: false,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false, loadMoreError: e.toString());
    }
  }

  void updateFilters(HistoryFilters Function(HistoryFilters) change) {
    state = state.copyWith(filters: change(state.filters));
    refresh();
  }
}

/// Role is read from the authenticated session (Manager/Owner → reviewer
/// endpoint, Staff → own-only endpoint). The server independently enforces
/// the same split, so a tampered client flag cannot widen visibility.
final historyControllerProvider =
    StateNotifierProvider.autoDispose<HistoryController, HistoryState>((ref) {
      final user = ref.watch(authControllerProvider).user;
      return HistoryController(
        ref.read(historyRepositoryProvider),
        asReviewer: user?.isManagerOrOwner ?? false,
      );
    });
