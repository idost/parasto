import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:myna/utils/app_logger.dart';

/// Maximum number of recent searches to store
const int _maxSearchHistory = 10;

/// Manages recent search history
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const _storageKey = 'recent_searches';

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        state = jsonList.cast<String>().take(_maxSearchHistory).toList();
      }
      AppLogger.d('SEARCH_HISTORY: Loaded ${state.length} recent searches');
    } catch (e) {
      AppLogger.e('Failed to load search history', error: e);
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(state));
    } catch (e) {
      AppLogger.e('Failed to save search history', error: e);
    }
  }

  /// Add a search query to history
  void addSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 2) return;

    // Remove if already exists (to move to top)
    final newList = state.where((s) => s.toLowerCase() != trimmed.toLowerCase()).toList();

    // Add to beginning
    newList.insert(0, trimmed);

    // Keep only max items
    state = newList.take(_maxSearchHistory).toList();
    _saveHistory();
  }

  /// Remove a specific search from history
  void removeSearch(String query) {
    state = state.where((s) => s != query).toList();
    _saveHistory();
  }

  /// Clear all search history
  void clearHistory() {
    state = [];
    _saveHistory();
    AppLogger.d('SEARCH_HISTORY: Cleared all history');
  }
}

/// Provider for search history
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

/// Suggested search queries based on popular categories from the database
final searchSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  try {
    // Fetch popular categories from the database
    final response = await Supabase.instance.client
        .from('categories')
        .select('name_fa')
        .eq('is_active', true)
        .order('audiobooks_count', ascending: false)
        .limit(10);

    final categories = (response as List)
        .map((c) => c['name_fa'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toList();

    if (categories.isNotEmpty) {
      return categories;
    }
  } catch (e) {
    AppLogger.e('Failed to fetch search suggestions', error: e);
  }

  // Fallback to hardcoded suggestions if database fetch fails
  return [
    'رمان',
    'داستان کوتاه',
    'تاریخ',
    'روانشناسی',
    'فلسفه',
    'شعر',
    'کودک',
    'علمی تخیلی',
  ];
});
