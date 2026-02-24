import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Cache for banners - they change infrequently
List<Map<String, dynamic>>? _bannersCache;
DateTime? _bannersCacheTime;
const _bannersCacheDuration = Duration(minutes: 10);

/// Provider for active banners on home screen (listener view)
/// Uses in-memory cache to reduce redundant fetches
final homeBannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_bannersCache != null && _bannersCacheTime != null) {
    final elapsed = DateTime.now().difference(_bannersCacheTime!);
    if (elapsed < _bannersCacheDuration) {
      return _bannersCache!;
    }
  }

  try {
    final response = await Supabase.instance.client
        .from('promo_banners')
        .select('*')
        .eq('is_active', true)
        .or('starts_at.is.null,starts_at.lte.${DateTime.now().toIso8601String()}')
        .or('ends_at.is.null,ends_at.gte.${DateTime.now().toIso8601String()}')
        .order('sort_order')
        .limit(10);
    final result = List<Map<String, dynamic>>.from(response);

    // Cache the result
    _bannersCache = result;
    _bannersCacheTime = DateTime.now();

    return result;
  } catch (e) {
    AppLogger.e('Error fetching home banners', error: e);
    rethrow;
  }
});

/// Cache for shelves - they change infrequently
List<Map<String, dynamic>>? _shelvesCache;
DateTime? _shelvesCacheTime;
const _shelvesCacheDuration = Duration(minutes: 10);

/// Provider for active shelves with their audiobooks on home screen
/// OPTIMIZED: Single batch query instead of N+1 pattern
/// Uses in-memory cache to reduce redundant fetches
final homeShelvesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_shelvesCache != null && _shelvesCacheTime != null) {
    final elapsed = DateTime.now().difference(_shelvesCacheTime!);
    if (elapsed < _shelvesCacheDuration) {
      return _shelvesCache!;
    }
  }

  try {
    // Get active shelves
    final shelvesResponse = await Supabase.instance.client
        .from('promo_shelves')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')
        .limit(10);

    final shelves = List<Map<String, dynamic>>.from(shelvesResponse);
    if (shelves.isEmpty) {
      _shelvesCache = [];
      _shelvesCacheTime = DateTime.now();
      return [];
    }

    // OPTIMIZATION: Get all shelf IDs and fetch ALL items in ONE query
    // PERFORMANCE: Select only needed columns instead of audiobooks(*)
    final shelfIds = shelves.map((s) => s['id'] as int).toList();
    final allItemsResponse = await Supabase.instance.client
        .from('promo_shelf_items')
        .select('''
          shelf_id, audiobook_id, sort_order,
          audiobooks(
            id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
            author_fa, author_en, play_count, avg_rating, price_toman,
            book_metadata(narrator_name),
            music_metadata(artist_name, featured_artists)
          )
        ''')
        .inFilter('shelf_id', shelfIds)
        .order('sort_order');

    final allItems = List<Map<String, dynamic>>.from(allItemsResponse);

    // Group items by shelf_id
    final itemsByShelf = <int, List<Map<String, dynamic>>>{};
    for (final item in allItems) {
      final shelfId = item['shelf_id'] as int;
      itemsByShelf.putIfAbsent(shelfId, () => []);
      if (item['audiobooks'] != null) {
        itemsByShelf[shelfId]!.add(item['audiobooks'] as Map<String, dynamic>);
      }
    }

    // Assign audiobooks to each shelf
    for (final shelf in shelves) {
      final shelfId = shelf['id'] as int;
      shelf['audiobooks'] = itemsByShelf[shelfId] ?? [];
    }

    // Filter out shelves with no audiobooks
    final result = shelves.where((s) => (s['audiobooks'] as List).isNotEmpty).toList();

    // Cache the result
    _shelvesCache = result;
    _shelvesCacheTime = DateTime.now();

    return result;
  } catch (e) {
    AppLogger.e('Error fetching home shelves', error: e);
    rethrow;
  }
});

/// Provider for shelf detail page (used when clicking banner that targets shelf)
final shelfDetailProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, shelfId) async {
  try {
    final shelfResponse = await Supabase.instance.client
        .from('promo_shelves')
        .select('*')
        .eq('id', shelfId)
        .maybeSingle();

    if (shelfResponse == null) return null;

    final shelf = Map<String, dynamic>.from(shelfResponse);

    // Get shelf audiobooks
    // PERFORMANCE: Select only needed columns instead of audiobooks(*)
    final itemsResponse = await Supabase.instance.client
        .from('promo_shelf_items')
        .select('''
          audiobook_id, sort_order,
          audiobooks(
            id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
            author_fa, author_en, play_count, avg_rating, price_toman,
            book_metadata(narrator_name),
            music_metadata(artist_name, featured_artists)
          )
        ''')
        .eq('shelf_id', shelfId)
        .order('sort_order');

    final items = List<Map<String, dynamic>>.from(itemsResponse);
    shelf['audiobooks'] = items
        .where((item) => item['audiobooks'] != null)
        .map((item) => item['audiobooks'] as Map<String, dynamic>)
        .toList();

    return shelf;
  } catch (e) {
    AppLogger.e('Error fetching shelf detail', error: e);
    rethrow;
  }
});

// ============================================
// ADMIN PROVIDERS
// ============================================

/// Admin provider for all banners
final adminBannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('promo_banners')
        .select('*')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching admin banners', error: e);
    rethrow;
  }
});

/// Admin provider for all shelves
final adminShelvesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('promo_shelves')
        .select('*')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching admin shelves', error: e);
    rethrow;
  }
});

/// Admin provider for shelf items (audiobooks in a specific shelf)
final adminShelfItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, shelfId) async {
  try {
    final response = await Supabase.instance.client
        .from('promo_shelf_items')
        .select('*, audiobooks(id, title_fa, cover_url)')
        .eq('shelf_id', shelfId)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching shelf items', error: e);
    rethrow;
  }
});
