import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/providers/download_provider.dart';
import 'package:myna/screens/player/player_screen.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/widgets/shared/filter_chip_row.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/providers/ebook_providers.dart';
import 'package:myna/screens/ebook_detail_screen.dart';
import 'package:myna/widgets/ebook_cover_image.dart';

/// Status filter for library items (Audible-style filtering)
enum LibraryStatusFilter {
  all,        // همه
  notStarted, // شروع نشده
  inProgress, // در حال گوش دادن
  finished,   // تمام شده
  downloaded, // دانلود شده
}

/// Sort options for library items
enum LibrarySortOption {
  recentlyPlayed, // آخرین پخش شده (default)
  title,          // عنوان (الف-ی)
  dateAdded,      // تاریخ اضافه شدن
  duration,       // مدت زمان
}

/// Content type for library filtering (Books, Music, Podcasts)
enum ContentType {
  books,    // کتاب‌ها (is_music=false, is_podcast=false, is_article=false)
  music,    // موسیقی (is_music=true)
  podcasts, // پادکست‌ها (is_podcast=true)
  articles, // مقاله‌ها (is_article=true)
}

/// Provider family for owned items with progress, filtered by content type
final ownedItemsWithProgressProvider = FutureProvider.family<List<Map<String, dynamic>>, ContentType>((ref, contentType) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    AppLogger.d('Library: No user logged in');
    return [];
  }

  try {
    AppLogger.d('Library: Step 1 - Fetching entitlements for user ${user.id.substring(0, 8)}... (contentType: $contentType)');

    // Step 1: Get entitlements (includes source for debugging)
    List<dynamic> entitlements;
    try {
      entitlements = await Supabase.instance.client
          .from('entitlements')
          .select('audiobook_id, source')
          .eq('user_id', user.id);
      // Log entitlement sources for debugging
      final sources = entitlements.map((e) => '${e['audiobook_id']}(${e['source']})').join(', ');
      AppLogger.d('Library: Step 1 SUCCESS - Got ${entitlements.length} entitlements: $sources');
    } on PostgrestException catch (e) {
      AppLogger.e('Library: Step 1 FAILED (entitlements) - Code: ${e.code}, Message: ${e.message}');
      rethrow;
    }

    final audiobookIds = entitlements
        .map((e) => e['audiobook_id'] as int)
        .toList();

    if (audiobookIds.isEmpty) {
      AppLogger.d('Library: No audiobook IDs found');
      return [];
    }

    AppLogger.d('Library: Step 2 - Fetching audiobooks for IDs: $audiobookIds');

    // Step 2: Get audiobook details with only needed columns + metadata for narrator/artist
    // PERFORMANCE: Select specific columns instead of * to reduce data transfer
    List<dynamic> audiobooksResponse;
    try {
      // Build query with content type filter
      var query = Supabase.instance.client
          .from('audiobooks')
          .select('''
            id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
            total_duration_seconds, author_fa, author_en, play_count, status, category_id,
            book_metadata(narrator_name),
            music_metadata(artist_name, featured_artists)
          ''')
          .inFilter('id', audiobookIds);

      // Apply content type filter
      // Books: is_music=false (podcasts will be excluded once is_podcast column is added)
      // Music: is_music=true
      // Podcasts: is_podcast=true (returns empty if column doesn't exist yet)
      switch (contentType) {
        case ContentType.books:
          // For books: is_music=false AND exclude podcasts and articles
          query = query.eq('is_music', false).eq('is_article', false);
        case ContentType.music:
          query = query.eq('is_music', true);
        case ContentType.podcasts:
          // Podcasts feature - query with is_podcast filter
          query = query.eq('is_podcast', true);
        case ContentType.articles:
          query = query.eq('is_article', true);
      }

      // Execute query - for podcasts/articles, handle case where column doesn't exist
      if (contentType == ContentType.podcasts || contentType == ContentType.articles) {
        try {
          audiobooksResponse = await query;
        } on PostgrestException catch (e) {
          // If column doesn't exist, return empty list instead of error
          // Note: Supabase may report column with hyphen in error message
          if (e.message.contains('is_podcast') || e.message.contains('is-podcast') ||
              e.message.contains('is_article') || e.message.contains('is-article') ||
              e.code == '42703' || e.code == '400') {
            AppLogger.d('Library: Column not found for $contentType, returning empty list');
            return [];
          }
          rethrow;
        }
      } else {
        audiobooksResponse = await query;
      }
      AppLogger.d('Library: Step 2 SUCCESS - Got ${audiobooksResponse.length} audiobooks');
    } on PostgrestException catch (e) {
      AppLogger.e('Library: Step 2 FAILED (audiobooks) - Code: ${e.code}, Message: ${e.message}');
      rethrow;
    }

    final items = List<Map<String, dynamic>>.from(audiobooksResponse);

    if (items.isEmpty) return [];

    // Get item IDs for further queries
    final itemIds = items.map((i) => i['id'] as int).toList();

    AppLogger.d('Library: Steps 3 & 4 - Fetching chapters and progress in PARALLEL for ${itemIds.length} audiobooks');

    // Steps 3 & 4: Fetch chapters and progress IN PARALLEL (performance optimization)
    // Both queries depend only on itemIds, so they can run concurrently
    late List<dynamic> chaptersResponse;
    late List<dynamic> progressResponse;

    try {
      final results = await Future.wait([
        // Step 3: Get chapters for owned items
        Supabase.instance.client
            .from('chapters')
            .select('id, title_fa, audio_storage_path, duration_seconds, chapter_index, is_preview, audiobook_id')
            .inFilter('audiobook_id', itemIds)
            .order('chapter_index', ascending: true),
        // Step 4: Get progress for owned items
        Supabase.instance.client
            .from('listening_progress')
            .select('*')
            .eq('user_id', user.id)
            .inFilter('audiobook_id', itemIds),
      ]);

      chaptersResponse = results[0] as List<dynamic>;
      progressResponse = results[1] as List<dynamic>;

      AppLogger.d('Library: Steps 3 & 4 SUCCESS (parallel) - Got ${chaptersResponse.length} chapters, ${progressResponse.length} progress records');
    } on PostgrestException catch (e) {
      AppLogger.e('Library: Steps 3 & 4 FAILED - Code: ${e.code}, Message: ${e.message}');
      rethrow;
    }

    // Group chapters by audiobook_id
    final chaptersMap = <int, List<Map<String, dynamic>>>{};
    for (final chapter in chaptersResponse) {
      final audiobookId = chapter['audiobook_id'] as int;
      chaptersMap.putIfAbsent(audiobookId, () => []);
      chaptersMap[audiobookId]!.add(Map<String, dynamic>.from(chapter as Map));
    }

    final progressMap = <int, Map<String, dynamic>>{};
    for (final p in progressResponse) {
      final audiobookId = p['audiobook_id'] as int;
      progressMap[audiobookId] = p as Map<String, dynamic>;
    }

    // Merge chapters and progress into items
    for (final item in items) {
      final itemId = item['id'] as int;
      item['chapters'] = chaptersMap[itemId] ?? [];
      item['progress'] = progressMap[itemId];
    }

    // Sort: in-progress items first, then recently played
    items.sort((a, b) {
      final aProgress = a['progress'] as Map<String, dynamic>?;
      final bProgress = b['progress'] as Map<String, dynamic>?;

      // Items with progress come first
      if (aProgress != null && bProgress == null) return -1;
      if (aProgress == null && bProgress != null) return 1;

      // Among items with progress, sort by last_played_at
      if (aProgress != null && bProgress != null) {
        final aLastPlayed = aProgress['last_played_at'] as String?;
        final bLastPlayed = bProgress['last_played_at'] as String?;
        if (aLastPlayed != null && bLastPlayed != null) {
          return bLastPlayed.compareTo(aLastPlayed); // Most recent first
        }
      }

      return 0;
    });

    AppLogger.d('Library: ALL STEPS SUCCESS - Returning ${items.length} items');
    return items;
  } on PostgrestException catch (e) {
    AppLogger.e('Library: PostgrestException - Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
    rethrow;
  } catch (e, stackTrace) {
    AppLogger.e('Library: Error fetching library', error: e);
    AppLogger.e('Library: Stack trace: $stackTrace');
    rethrow;
  }
});

/// Provider family for wishlist items, filtered by content type
final wishlistItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, ContentType>((ref, contentType) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  // Include book_metadata for books and music_metadata for music
  var query = Supabase.instance.client
      .from('user_wishlist')
      .select('audiobook_id, audiobooks!inner(*, book_metadata(narrator_name), music_metadata(artist_name))')
      .eq('user_id', user.id);

  // Apply content type filter
  // Books: is_music=false (audiobooks without is_podcast filter for backwards compatibility)
  // Music: is_music=true
  // Podcasts: is_podcast=true (may return empty if column doesn't exist)
  switch (contentType) {
    case ContentType.books:
      // For books: is_music=false AND exclude articles
      query = query.eq('audiobooks.is_music', false).eq('audiobooks.is_article', false);
    case ContentType.music:
      query = query.eq('audiobooks.is_music', true);
    case ContentType.podcasts:
      query = query.eq('audiobooks.is_podcast', true);
    case ContentType.articles:
      query = query.eq('audiobooks.is_article', true);
  }

  // Execute query - for podcasts/articles, handle case where column doesn't exist
  List<dynamic> response;
  if (contentType == ContentType.podcasts || contentType == ContentType.articles) {
    try {
      response = await query;
    } on PostgrestException catch (e) {
      // If column doesn't exist, return empty list instead of error
      if (e.message.contains('is_podcast') || e.message.contains('is-podcast') ||
          e.message.contains('is_article') || e.message.contains('is-article') ||
          e.code == '42703' || e.code == '400') {
        AppLogger.d('Wishlist: Column not found for $contentType, returning empty list');
        return [];
      }
      rethrow;
    }
  } else {
    response = await query;
  }

  // For books, filter out podcasts in memory if they accidentally got included
  var items = response
      .map((e) => e['audiobooks'] as Map<String, dynamic>)
      .toList();

  if (contentType == ContentType.books) {
    // Filter out any items that are podcasts (is_podcast = true)
    items = items.where((item) => item['is_podcast'] != true).toList();
  }

  return items;
});

/// Legacy providers for backwards compatibility
final ownedBooksWithProgressProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(ownedItemsWithProgressProvider(ContentType.books).future);
});

final wishlistBooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(wishlistItemsProvider(ContentType.books).future);
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Content type: Books, Music, or Podcasts
  ContentType _contentType = ContentType.books;

  // Status filter for owned items (Audible-style)
  LibraryStatusFilter _statusFilter = LibraryStatusFilter.all;

  // Sort option for owned items
  LibrarySortOption _sortOption = LibrarySortOption.recentlyPlayed;

  // View mode toggle (list or grid)
  bool _isGridView = false;

  // Local search for filtering owned items
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchInLibrary,
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                )
              : const Text('قفسه'),
          centerTitle: !_isSearching,
          leading: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                )
              : null,
          actions: [
            // Search toggle
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                onPressed: () => setState(() => _isSearching = true),
                tooltip: AppStrings.search,
              ),
            // Clear search button when searching
            if (_isSearching && _searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            // Sort options dropdown
            if (!_isSearching)
              PopupMenuButton<LibrarySortOption>(
                icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
                tooltip: AppStrings.sortByRecentlyPlayed,
                onSelected: (value) => setState(() => _sortOption = value),
                itemBuilder: (context) => [
                  _buildSortMenuItem(LibrarySortOption.recentlyPlayed, AppStrings.sortByRecentlyPlayed),
                  _buildSortMenuItem(LibrarySortOption.title, AppStrings.sortByTitle),
                  _buildSortMenuItem(LibrarySortOption.dateAdded, AppStrings.sortByDateAdded),
                  _buildSortMenuItem(LibrarySortOption.duration, AppStrings.sortByDuration),
                ],
              ),
            // Grid/List view toggle
            if (!_isSearching)
              IconButton(
                icon: Icon(
                  _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _isGridView = !_isGridView),
                tooltip: _isGridView ? AppStrings.listView : AppStrings.gridView,
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: Column(
              children: [
                // همه / ای بوک / کتاب گویا / پادکست content type selector
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // همه (All) → shows all non-music/podcast content
                        _buildContentTypeButton(ContentType.books, 'همه', Icons.apps_rounded),
                        // ای بوک (Ebook)
                        _buildContentTypeButton(ContentType.music, 'ای بوک', Icons.menu_book_rounded),
                        // کتاب گویا (Audiobook)
                        _buildContentTypeButton(ContentType.podcasts, 'کتاب گویا', Icons.headphones_rounded),
                        // پادکست (Podcast)
                        _buildContentTypeButton(ContentType.articles, 'پادکست', Icons.podcasts_rounded),
                      ],
                    ),
                  ),
                ),
                // My Items / Wishlist tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textTertiary,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: [
                    const Tab(text: 'محتوای من'),
                    Tab(text: AppStrings.wishlist),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Key ensures widget rebuilds when switching between content types, status filter, sort, view mode, or search
            _OwnedItemsTab(
              key: ValueKey('owned_${_contentType}_${_statusFilter}_${_sortOption}_${_isGridView}_$_searchQuery'),
              contentType: _contentType,
              statusFilter: _statusFilter,
              sortOption: _sortOption,
              isGridView: _isGridView,
              searchQuery: _searchQuery,
              onStatusFilterChanged: (filter) => setState(() => _statusFilter = filter),
            ),
            _WishlistTab(key: ValueKey('wishlist_$_contentType'), contentType: _contentType),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTypeButton(ContentType type, String label, IconData icon) {
    final isSelected = _contentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _contentType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<LibrarySortOption> _buildSortMenuItem(LibrarySortOption option, String label) {
    final isSelected = _sortOption == option;
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================================
/// LIBRARY SEARCH DESIGN
/// =============================================================================
///
/// The library search is CLIENT-SIDE filtering (not server-side) because:
/// 1. User library lists are typically small (owned items only)
/// 2. Data is already loaded via ownedItemsWithProgressProvider
/// 3. Instant response without network round-trip
///
/// SEARCH BEHAVIOR:
/// - Searches ONLY within the user's own library (books they own via entitlements)
/// - Context-aware: respects کتاب‌ها vs موسیقی tab selection
/// - Fields searched: title_fa, title_en, author_fa (creator name)
/// - Uses FarsiUtils.normalizeSearchQuery for Persian text normalization
/// - Clearing the search returns to the full library list
/// =============================================================================

class _OwnedItemsTab extends ConsumerStatefulWidget {
  final ContentType contentType;
  final LibraryStatusFilter statusFilter;
  final LibrarySortOption sortOption;
  final bool isGridView;
  final String searchQuery;
  final ValueChanged<LibraryStatusFilter>? onStatusFilterChanged;

  const _OwnedItemsTab({
    super.key,
    required this.contentType,
    required this.statusFilter,
    required this.sortOption,
    required this.isGridView,
    required this.searchQuery,
    this.onStatusFilterChanged,
  });

  @override
  ConsumerState<_OwnedItemsTab> createState() => _OwnedItemsTabState();
}

class _OwnedItemsTabState extends ConsumerState<_OwnedItemsTab> {
  /// Filter items by search query (client-side)
  /// Uses widget.searchQuery from parent LibraryScreen AppBar
  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    if (widget.searchQuery.isEmpty) return items;

    final normalizedQuery = FarsiUtils.normalizeSearchQuery(widget.searchQuery);
    if (normalizedQuery.isEmpty) return items;

    return items.where((item) {
      // Search in title_fa
      final titleFa = FarsiUtils.normalizeSearchQuery(
        (item['title_fa'] as String?) ?? '',
      );
      if (titleFa.contains(normalizedQuery)) return true;

      // Search in title_en
      final titleEn = ((item['title_en'] as String?) ?? '').toLowerCase();
      if (titleEn.contains(normalizedQuery.toLowerCase())) return true;

      // Search in author_fa (for books) or artist name (for music)
      final authorFa = FarsiUtils.normalizeSearchQuery(
        (item['author_fa'] as String?) ?? '',
      );
      if (authorFa.contains(normalizedQuery)) return true;

      return false;
    }).toList();
  }

  /// Filter items by status (Audible-style: Not Started / In Progress / Finished)
  List<Map<String, dynamic>> _filterByStatus(List<Map<String, dynamic>> items) {
    switch (widget.statusFilter) {
      case LibraryStatusFilter.all:
        return items;
      case LibraryStatusFilter.notStarted:
        // Items with no progress OR completion_percentage == 0
        return items.where((item) {
          final progress = item['progress'] as Map<String, dynamic>?;
          if (progress == null) return true;
          final completion = (progress['completion_percentage'] as int?) ?? 0;
          return completion == 0;
        }).toList();
      case LibraryStatusFilter.inProgress:
        // Items with progress > 0 AND not completed
        return items.where((item) {
          final progress = item['progress'] as Map<String, dynamic>?;
          if (progress == null) return false;
          final completion = (progress['completion_percentage'] as int?) ?? 0;
          final isCompleted = progress['is_completed'] == true;
          return completion > 0 && !isCompleted;
        }).toList();
      case LibraryStatusFilter.finished:
        // Items marked as completed
        return items.where((item) {
          final progress = item['progress'] as Map<String, dynamic>?;
          if (progress == null) return false;
          return progress['is_completed'] == true;
        }).toList();
      case LibraryStatusFilter.downloaded:
        // Items with offline downloads (mobile only)
        if (kIsWeb) return [];
        return items.where((item) {
          final audiobookId = item['id'] as int;
          return ref.read(downloadProvider.notifier).hasAnyDownloads(audiobookId);
        }).toList();
    }
  }

  /// Sort items based on selected sort option
  List<Map<String, dynamic>> _sortItems(List<Map<String, dynamic>> items) {
    final sorted = List<Map<String, dynamic>>.from(items);
    switch (widget.sortOption) {
      case LibrarySortOption.recentlyPlayed:
        // Sort by last_played_at (most recent first)
        sorted.sort((a, b) {
          final progressA = a['progress'] as Map<String, dynamic>?;
          final progressB = b['progress'] as Map<String, dynamic>?;
          final dateA = progressA?['last_played_at'] as String?;
          final dateB = progressB?['last_played_at'] as String?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending
        });
        break;
      case LibrarySortOption.title:
        // Sort alphabetically by title_fa
        sorted.sort((a, b) {
          final titleA = (a['title_fa'] as String?) ?? '';
          final titleB = (b['title_fa'] as String?) ?? '';
          return titleA.compareTo(titleB); // Ascending
        });
        break;
      case LibrarySortOption.dateAdded:
        // Sort by created_at (most recent first)
        sorted.sort((a, b) {
          final dateA = a['created_at'] as String?;
          final dateB = b['created_at'] as String?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending
        });
        break;
      case LibrarySortOption.duration:
        // Sort by total_duration_seconds (longest first)
        sorted.sort((a, b) {
          final durationA = (a['total_duration_seconds'] as int?) ?? 0;
          final durationB = (b['total_duration_seconds'] as int?) ?? 0;
          return durationB.compareTo(durationA); // Descending
        });
        break;
    }
    return sorted;
  }

  bool get _isMusic => widget.contentType == ContentType.music;
  bool get _isEbook => widget.contentType == ContentType.music; // "ای بوک" tab reuses ContentType.music
  bool get _isPodcast => widget.contentType == ContentType.podcasts;
  bool get _isArticle => widget.contentType == ContentType.articles;

  @override
  Widget build(BuildContext context) {
    // Ebook tab uses a separate provider (different table: ebooks vs audiobooks)
    if (_isEbook) {
      return _buildEbookTab(context);
    }

    final itemsAsync = ref.watch(ownedItemsWithProgressProvider(widget.contentType));

    return itemsAsync.when(
      loading: () => const LibraryListSkeleton(),
      error: (e, stackTrace) {
        // Log detailed error for debugging
        AppLogger.e('Library tab error: $e', error: e, stackTrace: stackTrace);
        final errorMsg = e is PostgrestException
            ? 'Code: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}'
            : e.toString();
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _isMusic ? AppStrings.errorLoadingMusic : AppStrings.errorLoadingLibrary,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 8),
              // Show actual error in debug mode
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  errorMsg,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ownedItemsWithProgressProvider(widget.contentType)),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        );
      },
      data: (items) {
        // Apply client-side filters: first status, then search, then sort
        final statusFiltered = _filterByStatus(items);
        final searchFiltered = _filterItems(statusFiltered);
        final filteredItems = _sortItems(searchFiltered);

        // Build the status filter chip bar using shared FilterChipRow
        final Widget statusChipsBar = Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: FilterChipRow<LibraryStatusFilter>(
            options: [
              const FilterOption(label: 'همه', value: LibraryStatusFilter.all),
              const FilterOption(label: 'شروع نشده', value: LibraryStatusFilter.notStarted),
              const FilterOption(label: 'در حال گوش دادن', value: LibraryStatusFilter.inProgress),
              const FilterOption(label: 'تمام شده', value: LibraryStatusFilter.finished),
              if (!kIsWeb)
                const FilterOption(label: 'دانلود شده', value: LibraryStatusFilter.downloaded),
            ],
            selected: widget.statusFilter,
            onChanged: (filter) => widget.onStatusFilterChanged?.call(filter),
          ),
        );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownedItemsWithProgressProvider(widget.contentType));
            // Wait for the provider to reload before dismissing the indicator
            await ref.read(ownedItemsWithProgressProvider(widget.contentType).future);
          },
          color: AppColors.primary,
          child: items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Decorative icon container
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha:0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isMusic ? Icons.music_note_rounded : (_isPodcast ? Icons.podcasts_rounded : Icons.auto_stories_rounded),
                                      size: 48,
                                      color: AppColors.primary.withValues(alpha:0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _isMusic ? AppStrings.noMusicYet : (_isPodcast ? AppStrings.noPodcastsYet : (_isArticle ? AppStrings.noArticlesYet : AppStrings.noBooksYet)),
                                    style: AppTypography.emptyState,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isMusic
                                        ? AppStrings.musicWillAppearHere
                                        : (_isPodcast ? AppStrings.podcastsWillAppearHere : (_isArticle ? AppStrings.articlesWillAppearHere : AppStrings.booksWillAppearHere)),
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  // CTA Button to browse catalog
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Navigate to home screen (index 0) to browse
                                      // This assumes MainScreen controls the navigation
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                    },
                                    icon: const Icon(Icons.explore_rounded),
                                    label: Text(_isMusic ? AppStrings.searchMusic : (_isPodcast ? AppStrings.searchPodcasts : AppStrings.searchBooks)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.textOnPrimary,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : filteredItems.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.4,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: AppColors.textTertiary,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        AppStrings.noResults,
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppStrings.searchQuery(widget.searchQuery),
                                        style: const TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : widget.isGridView
                            ? CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverToBoxAdapter(child: statusChipsBar),
                                  SliverPadding(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    sliver: SliverGrid(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.58,
                                        crossAxisSpacing: AppSpacing.cardGap,
                                        mainAxisSpacing: AppSpacing.cardGap,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _OwnedItemGridCard(
                                          item: filteredItems[index],
                                          isMusic: _isMusic,
                                        ),
                                        childCount: filteredItems.length,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverToBoxAdapter(child: statusChipsBar),
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _OwnedItemCard(
                                          item: filteredItems[index],
                                          isMusic: _isMusic,
                                        ),
                                        childCount: filteredItems.length,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
        );
      },
    );
  }

  /// Ebook tab — uses ownedEbooksProvider (separate ebooks table)
  Widget _buildEbookTab(BuildContext context) {
    final ebooksAsync = ref.watch(ownedEbooksProvider);

    return ebooksAsync.when(
      loading: () => const LibraryListSkeleton(),
      error: (e, stackTrace) {
        AppLogger.e('Library ebook tab error: $e', error: e, stackTrace: stackTrace);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(AppStrings.errorLoadingLibrary, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ownedEbooksProvider),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        );
      },
      data: (ebooks) {
        // Apply client-side search filter
        final filtered = _filterEbooks(ebooks);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownedEbooksProvider);
            await ref.read(ownedEbooksProvider.future);
          },
          color: AppColors.primary,
          child: ebooks.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 48,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'هنوز کتابی ندارید',
                              style: AppTypography.emptyState,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'کتاب‌های خریداری شده اینجا نمایش داده می‌شوند',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                              icon: const Icon(Icons.explore_rounded),
                              label: Text(AppStrings.exploreBooks),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textOnPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
                                const SizedBox(height: 16),
                                Text(AppStrings.noResults, style: const TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : widget.isGridView
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.55, // Taller for 2:3 ebook covers
                                  crossAxisSpacing: AppSpacing.cardGap,
                                  mainAxisSpacing: AppSpacing.cardGap,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _OwnedEbookGridCard(ebook: filtered[index]),
                                  childCount: filtered.length,
                                ),
                              ),
                            ),
                          ],
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _OwnedEbookCard(ebook: filtered[index]),
                                  childCount: filtered.length,
                                ),
                              ),
                            ),
                          ],
                        ),
        );
      },
    );
  }

  /// Filter ebooks by search query
  List<Map<String, dynamic>> _filterEbooks(List<Map<String, dynamic>> ebooks) {
    if (widget.searchQuery.isEmpty) return ebooks;
    final normalizedQuery = FarsiUtils.normalizeSearchQuery(widget.searchQuery);
    if (normalizedQuery.isEmpty) return ebooks;

    return ebooks.where((ebook) {
      final titleFa = FarsiUtils.normalizeSearchQuery((ebook['title_fa'] as String?) ?? '');
      if (titleFa.contains(normalizedQuery)) return true;
      final titleEn = ((ebook['title_en'] as String?) ?? '').toLowerCase();
      if (titleEn.contains(normalizedQuery.toLowerCase())) return true;
      final authorFa = FarsiUtils.normalizeSearchQuery((ebook['author_fa'] as String?) ?? '');
      if (authorFa.contains(normalizedQuery)) return true;
      return false;
    }).toList();
  }
}

class _OwnedItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final bool isMusic;  // Keep for UI display purposes

  const _OwnedItemCard({required this.item, required this.isMusic});

  // Derive ContentType from isMusic for provider calls
  ContentType get _contentType => isMusic ? ContentType.music : ContentType.books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = item['progress'] as Map<String, dynamic>?;
    final chapters = item['chapters'] as List<dynamic>?;
    final sortedChapters = chapters != null
        ? (List<Map<String, dynamic>>.from(chapters)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
              ((a['chapter_index'] as int?) ?? 0).compareTo((b['chapter_index'] as int?) ?? 0)))
        : <Map<String, dynamic>>[];

    final completionPercentage = (progress?['completion_percentage'] as int?) ?? 0;
    final isCompleted = progress?['is_completed'] == true;
    final currentChapterIndex = (progress?['current_chapter_index'] as int?) ?? 0;
    final positionSeconds = (progress?['position_seconds'] as int?) ?? 0;

    final hasProgress = progress != null && completionPercentage > 0;

    // Check for offline downloads (only on mobile)
    final audiobookId = item['id'] as int;
    final hasOfflineContent = !kIsWeb && ref.watch(downloadProvider.select(
      (_) => ref.read(downloadProvider.notifier).hasAnyDownloads(audiobookId),
    ));

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => AudiobookDetailScreen(
                audiobookId: audiobookId,
              ),
            ),
          ).then((_) => ref.invalidate(ownedItemsWithProgressProvider(_contentType)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover with progress overlay
              Stack(
                children: [
                  Hero(
                    tag: 'cover_$audiobookId',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 80,
                        color: AppColors.surfaceLight,
                        child: item['cover_url'] != null
                            ? CachedNetworkImage(
                                imageUrl: item['cover_url'] as String,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Icon(
                                  isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded,
                                  color: AppColors.textTertiary,
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded,
                                  color: AppColors.textTertiary,
                                ),
                              )
                            : Icon(isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  // Completion badge
                  if (isCompleted)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      top: 4,
                      end: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.textOnPrimary,
                          size: 12,
                        ),
                      ),
                    ),
                  // Offline badge (bottom-start)
                  if (hasOfflineContent)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      bottom: 4,
                      start: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha:0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: AppColors.textOnPrimary,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.localize((item['title_fa'] as String?) ?? ''),
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        // Check if this item is branded as "پرستو"
                        final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
                        // Get narrator/artist from the correct metadata table
                        // For books: book_metadata.narrator_name (actual voice narrator)
                        // For music: music_metadata.artist_name or author_fa (artist)
                        String narratorOrArtist;
                        if (isMusic) {
                          final musicMeta = item['music_metadata'] as Map<String, dynamic>?;
                          narratorOrArtist = (musicMeta?['artist_name'] as String?) ??
                              (item['author_fa'] as String?) ?? '';
                        } else {
                          final bookMeta = item['book_metadata'] as Map<String, dynamic>?;
                          narratorOrArtist = (bookMeta?['narrator_name'] as String?) ?? '';
                        }
                        final displayName = isParastoBrand ? AppStrings.appName : narratorOrArtist;
                        return Text(
                          AppStrings.localize(displayName),
                          style: AppTypography.cardSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Progress indicator
                    if (hasProgress) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: completionPercentage / 100,
                                backgroundColor: AppColors.surfaceLight,
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.primary,
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${FarsiUtils.toFarsiDigits(completionPercentage)}٪',
                            style: AppTypography.progressText.copyWith(
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? AppStrings.finished
                            : isMusic
                                ? AppStrings.trackOf(currentChapterIndex + 1, sortedChapters.length)
                                : AppStrings.chapterOf(currentChapterIndex + 1, sortedChapters.length),
                        style: AppTypography.meta,
                      ),
                    ] else
                      Text(
                        isMusic
                            ? AppStrings.tracks(sortedChapters.length)
                            : AppStrings.chapters(sortedChapters.length),
                        style: AppTypography.meta,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Play button
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      hasProgress && !isCompleted
                          ? Icons.play_circle_fill
                          : Icons.play_circle_outline,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    onPressed: sortedChapters.isEmpty
                        ? null
                        : () {
                            // Start playing directly (user owns this item via entitlement)
                            ref.read(audioProvider.notifier).play(
                              audiobook: item,
                              chapters: sortedChapters,
                              chapterIndex: hasProgress ? currentChapterIndex : 0,
                              seekTo: hasProgress ? positionSeconds : null,
                              isOwned: true,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PlayerScreen(
                                  audiobook: item,
                                  chapters: sortedChapters,
                                  initialChapterIndex:
                                      hasProgress ? currentChapterIndex : 0,
                                  playbackAlreadyStarted: true, // We already called play() above
                                ),
                              ),
                            ).then(
                                (_) => ref.invalidate(ownedItemsWithProgressProvider(_contentType)));
                          },
                  ),
                  if (hasProgress && !isCompleted)
                    Text(
                      AppStrings.continueButton,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid card for owned items (compact view for grid layout)
class _OwnedItemGridCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final bool isMusic;  // Keep for UI display purposes

  const _OwnedItemGridCard({required this.item, required this.isMusic});

  // Derive ContentType from isMusic for provider calls
  ContentType get _contentType => isMusic ? ContentType.music : ContentType.books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = item['progress'] as Map<String, dynamic>?;
    final chapters = item['chapters'] as List<dynamic>?;
    final sortedChapters = chapters != null
        ? (List<Map<String, dynamic>>.from(chapters)
          ..sort((a, b) =>
              ((a['chapter_index'] as int?) ?? 0).compareTo((b['chapter_index'] as int?) ?? 0)))
        : <Map<String, dynamic>>[];
    final completionPercentage = (progress?['completion_percentage'] as int?) ?? 0;
    final isCompleted = progress?['is_completed'] == true;
    final hasProgress = progress != null && completionPercentage > 0;
    final currentChapterIndex = (progress?['current_chapter_index'] as int?) ?? 0;
    final positionSeconds = (progress?['position_seconds'] as int?) ?? 0;
    final audiobookId = item['id'] as int;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: audiobookId),
          ),
        ).then((_) => ref.invalidate(ownedItemsWithProgressProvider(_contentType)));
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with badges
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Hero(
                    tag: 'cover_$audiobookId',
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                        color: AppColors.surfaceLight,
                        image: item['cover_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(item['cover_url'] as String),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: item['cover_url'] == null
                          ? Center(
                              child: Icon(
                                isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded,
                                size: 40,
                                color: AppColors.textTertiary,
                              ),
                            )
                          : null,
                    ),
                  ),
                  // Completion badge
                  if (isCompleted)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      top: 8,
                      end: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: AppColors.textOnPrimary, size: 14),
                      ),
                    ),
                  // Play button overlay for in-progress items
                  if (hasProgress && !isCompleted)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      bottom: AppSpacing.sm,
                      start: AppSpacing.sm,
                      child: GestureDetector(
                        onTap: sortedChapters.isEmpty
                            ? null
                            : () {
                                ref.read(audioProvider.notifier).play(
                                  audiobook: item,
                                  chapters: sortedChapters,
                                  chapterIndex: currentChapterIndex,
                                  seekTo: positionSeconds,
                                  isOwned: true,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => PlayerScreen(
                                      audiobook: item,
                                      chapters: sortedChapters,
                                      initialChapterIndex: currentChapterIndex,
                                      playbackAlreadyStarted: true,
                                    ),
                                  ),
                                ).then((_) => ref.invalidate(ownedItemsWithProgressProvider(_contentType)));
                              },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.textOnPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  // Progress bar at bottom of cover
                  if (hasProgress && !isCompleted)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceLight,
                        ),
                        child: FractionallySizedBox(
                          alignment: AlignmentDirectional.centerEnd,
                          widthFactor: completionPercentage / 100,
                          child: Container(color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title and info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.localize((item['title_fa'] as String?) ?? ''),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
                        final author = (item['author_fa'] as String?) ?? '';
                        final displayText = isParastoBrand ? AppStrings.appName : author;
                        if (displayText.isEmpty) return const SizedBox.shrink();
                        return Text(
                          AppStrings.localize(displayText),
                          style: AppTypography.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const Spacer(),
                    // Status indicator
                    Row(
                      children: [
                        if (isCompleted) ...[
                          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.finished,
                            style: AppTypography.freeBadge,
                          ),
                        ] else if (hasProgress) ...[
                          Text(
                            '${FarsiUtils.toFarsiDigits(completionPercentage)}٪',
                            style: AppTypography.progressText,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistTab extends ConsumerWidget {
  final ContentType contentType;

  const _WishlistTab({super.key, required this.contentType});

  bool get isMusic => contentType == ContentType.music;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(wishlistItemsProvider(contentType));

    return itemsAsync.when(
      loading: () => const LibraryListSkeleton(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              AppStrings.errorLoadingWishlist,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(wishlistItemsProvider(contentType)),
              child: Text(AppStrings.retry),
            ),
          ],
        ),
      ),
      data: (items) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(wishlistItemsProvider(contentType));
            // Wait for the provider to reload before dismissing the indicator
            await ref.read(wishlistItemsProvider(contentType).future);
          },
          color: AppColors.primary,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Decorative heart icon container
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha:0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite_border,
                                size: 48,
                                color: AppColors.error.withValues(alpha:0.7),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppStrings.wishlistEmpty,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isMusic
                                  ? AppStrings.addMusicToWishlist
                                  : AppStrings.addBooksToWishlist,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                AppStrings.tapHeartToAdd,
                                style: TextStyle(
                                  color: AppColors.textTertiary.withValues(alpha:0.7),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // CTA Button
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              icon: const Icon(Icons.explore_rounded),
                              label: Text(isMusic ? AppStrings.exploreMusic : AppStrings.exploreBooks),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildWishlistCard(context, ref, items[index]),
                ),
        );
      },
    );
  }

  Widget _buildWishlistCard(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => AudiobookDetailScreen(
                audiobookId: item['id'] as int,
              ),
            ),
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 50,
            height: 60,
            color: AppColors.surfaceLight,
            child: item['cover_url'] != null
                ? CachedNetworkImage(
                    imageUrl: item['cover_url'] as String,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Icon(
                      isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded,
                      color: AppColors.textTertiary,
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded,
                      color: AppColors.textTertiary,
                    ),
                  )
                : Icon(isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded, color: AppColors.textTertiary),
          ),
        ),
        title: Text(
          AppStrings.localize((item['title_fa'] as String?) ?? ''),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item['is_free'] == true
              ? AppStrings.free
              : '${(item['price_toman'] as num?) ?? 0}',
          style: TextStyle(
            color: item['is_free'] == true ? AppColors.success : AppColors.primary,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: AppColors.error),
          onPressed: () async {
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) return;

            await Supabase.instance.client
                .from('user_wishlist')
                .delete()
                .eq('user_id', user.id)
                .eq('audiobook_id', item['id'] as int);

            ref.invalidate(wishlistItemsProvider(contentType));
          },
        ),
      ),
    );
  }
}

// ============================================
// OWNED EBOOK CARDS (Library ebook tab)
// ============================================

/// List card for an owned ebook in the library
class _OwnedEbookCard extends StatelessWidget {
  final Map<String, dynamic> ebook;

  const _OwnedEbookCard({required this.ebook});

  @override
  Widget build(BuildContext context) {
    final title = (ebook['title_fa'] as String?) ?? '';
    final author = (ebook['author_fa'] as String?) ?? '';
    final pageCount = ebook['page_count'] as int? ?? 0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EbookDetailScreen(ebook: ebook),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover (2:3 ratio)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 90,
                  child: EbookCoverImage(
                    coverUrl: ebook['cover_url'] as String?,
                    coverStoragePath: ebook['cover_storage_path'] as String?,
                    width: 60,
                    height: 90,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: AppTypography.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (pageCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${FarsiUtils.toFarsiDigits(pageCount)} صفحه',
                        style: AppTypography.micro.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              // Open button
              const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid card for an owned ebook in the library
class _OwnedEbookGridCard extends StatelessWidget {
  final Map<String, dynamic> ebook;

  const _OwnedEbookGridCard({required this.ebook});

  @override
  Widget build(BuildContext context) {
    final title = (ebook['title_fa'] as String?) ?? '';
    final author = (ebook['author_fa'] as String?) ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => EbookDetailScreen(ebook: ebook),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover (2:3 aspect ratio)
          Expanded(
            child: EbookCoverImage(
              coverUrl: ebook['cover_url'] as String?,
              coverStoragePath: ebook['cover_storage_path'] as String?,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (author.isNotEmpty)
            Text(
              author,
              style: AppTypography.cardSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

