import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/search_result.dart';
import 'package:myna/services/search_service.dart';

/// Provider for the current search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for selected result types filter
final searchTypesFilterProvider = StateProvider<Set<SearchResultType>>((ref) {
  return SearchResultType.values.toSet();
});

/// Provider for search results
final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final types = ref.watch(searchTypesFilterProvider);

  if (query.trim().length < 2) return [];

  return SearchService.search(
    query: query,
    types: types.length == SearchResultType.values.length ? null : types,
    limit: 30,
  );
});

/// Debounced search query provider
/// Updates search results after a delay to avoid too many API calls
class DebouncedSearchNotifier extends StateNotifier<String> {
  Timer? _debounceTimer;
  final Ref _ref;

  DebouncedSearchNotifier(this._ref) : super('');

  void updateQuery(String query) {
    _debounceTimer?.cancel();
    state = query;

    if (query.trim().length < 2) {
      _ref.read(searchQueryProvider.notifier).state = '';
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    state = '';
    _ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for debounced search input
final debouncedSearchProvider =
    StateNotifierProvider<DebouncedSearchNotifier, String>((ref) {
  return DebouncedSearchNotifier(ref);
});
