import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/widgets/error_view.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/widgets/audiobook_card.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/providers/search_history_provider.dart';
import 'package:myna/services/search_service.dart';
import 'package:myna/screens/ebook_detail_screen.dart';
import 'package:myna/widgets/ebook_cover_image.dart';

/// Provider for user's owned audiobook IDs (for filtering recommendations)
final _ownedAudiobookIdsProvider = FutureProvider<Set<int>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return <int>{};

  try {
    final response = await Supabase.instance.client
        .from('entitlements')
        .select('audiobook_id')
        .eq('user_id', user.id);

    return (response as List)
        .map((e) => e['audiobook_id'] as int)
        .toSet();
  } catch (e) {
    AppLogger.e('Error fetching owned audiobook IDs', error: e);
    return <int>{};
  }
});

/// Audible-inspired search screen with recommendations
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  bool _hasMore = true;
  String? _errorMessage;
  Timer? _debounceTimer;
  bool _isFocused = false;

  // Pagination
  static const int _pageSize = 20;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _searchFocusNode.hasFocus);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading || !_hasSearched) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = _searchController.text.trim();
      final normalizedQuery = FarsiUtils.normalizeSearchQuery(query);

      final newResults = await SearchService.searchContent(
        query: normalizedQuery,
        contentType: null,
        categoryId: null,
        freeOnly: false,
        limit: _pageSize,
        offset: _currentOffset + _pageSize,
      );

      if (mounted) {
        setState(() {
          _currentOffset += _pageSize;
          _results.addAll(newResults);
          _hasMore = newResults.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading more search results', error: e);
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 400), _performSearch);
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _search(query);
  }

  Future<void> _search(String query) async {
    final normalizedQuery = FarsiUtils.normalizeSearchQuery(query);

    if (normalizedQuery.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    // Save to recent searches
    ref.read(searchHistoryProvider.notifier).addSearch(query.trim());

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      // Search audiobooks and ebooks in parallel
      final searchResults = await Future.wait([
        SearchService.searchContent(
          query: normalizedQuery,
          contentType: null,
          categoryId: null,
          freeOnly: false,
          limit: _pageSize,
          offset: 0,
        ),
        SearchService.searchEbooks(
          query: normalizedQuery,
          limit: 10,
          offset: 0,
        ),
      ]);

      final audiobookResults = searchResults[0];
      final ebookResults = searchResults[1];

      // Merge: audiobook results first, then ebooks
      final mergedResults = [...audiobookResults, ...ebookResults];

      if (mounted) {
        setState(() {
          _results = mergedResults;
          _isLoading = false;
          _hasMore = audiobookResults.length >= _pageSize;
        });
      }
    } on PostgrestException catch (e) {
      AppLogger.e('Search Supabase error', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطا در جستجو';
        });
      }
    } catch (e) {
      AppLogger.e('Search error', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _isNetworkError(e)
              ? 'خطا در اتصال به اینترنت'
              : 'خطا در جستجو';
        });
      }
    }
  }

  bool _isNetworkError(dynamic e) {
    final message = e.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('timeout');
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Search bar with back button
              _buildSearchHeader(),

              // Content
              Expanded(
                child: _hasSearched
                    ? _buildSearchResults()
                    : _buildDiscoveryContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFocused ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'جستجو در کتاب‌ها و موسیقی...',
                  hintStyle: AppTypography.fieldHint,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _isFocused ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textTertiary,
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _performSearch(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Discovery content shown before searching (like Audible)
  Widget _buildDiscoveryContent() {
    // Get owned audiobook IDs to filter out already owned items
    final ownedIdsAsync = ref.watch(_ownedAudiobookIdsProvider);
    final ownedIds = ownedIdsAsync.valueOrNull ?? <int>{};
    final recentSearches = ref.watch(searchHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(searchRecommendedProvider);
        ref.invalidate(searchPickedForYouProvider);
        ref.invalidate(_ownedAudiobookIdsProvider);
        // Wait for at least one to complete
        await ref.read(searchRecommendedProvider.future);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // Recent searches
            if (recentSearches.isNotEmpty)
              _buildRecentSearchesSection(recentSearches),

            // Search suggestions (popular categories)
            _buildSearchSuggestionsSection(),

            // Recommended for you (horizontal cards) - excludes owned items
            _buildRecommendedSection(ownedIds),

            const SizedBox(height: AppSpacing.sm),

            // Picked for you (vertical list) - excludes owned items
            _buildPickedForYouSection(ownedIds),
          ],
        ),
      ),
    );
  }

  /// Recent searches section with tappable chips
  Widget _buildRecentSearchesSection(List<String> searches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.textTertiary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'جستجوهای اخیر',
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(searchHistoryProvider.notifier).clearHistory();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'پاک کردن',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: searches.length > 5 ? 5 : searches.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final query = searches[index];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: InkWell(
                  onTap: () {
                    _searchController.text = query;
                    _search(query);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          query,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        GestureDetector(
                          onTap: () {
                            ref.read(searchHistoryProvider.notifier).removeSearch(query);
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// Search suggestions from popular categories
  Widget _buildSearchSuggestionsSection() {
    final suggestionsAsync = ref.watch(searchSuggestionsProvider);
    return suggestionsAsync.maybeWhen(
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.textTertiary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'پیشنهاد جستجو',
                    style: AppTypography.titleMedium
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: suggestions.take(8).map((suggestion) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg),
                  child: ActionChip(
                    label: Text(
                      suggestion,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    onPressed: () {
                      _searchController.text = suggestion;
                      _search(suggestion);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection(Set<int> ownedIds) {
    // Use mixed content provider (books + music + podcasts)
    final recommendedAsync = ref.watch(searchRecommendedProvider);

    return recommendedAsync.when(
      loading: () => _buildHorizontalSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        // Filter out owned items
        final filteredItems = items
            .where((item) => !ownedIds.contains(item['id'] as int))
            .toList();

        if (filteredItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('پیشنهاد برای شما', icon: Icons.auto_awesome_rounded),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredItems.length > 8 ? 8 : filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: AudiobookCard(
                      book: item,
                      width: 160,
                      coverHeight: 240,
                      showPrice: false,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickedForYouSection(Set<int> ownedIds) {
    // Use mixed content provider (books + music + podcasts)
    final pickedAsync = ref.watch(searchPickedForYouProvider);

    return pickedAsync.when(
      loading: () => _buildVerticalListSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        // Filter out owned items
        final filteredItems = items
            .where((item) => !ownedIds.contains(item['id'] as int))
            .toList();

        if (filteredItems.isEmpty) return const SizedBox.shrink();

        final displayItems = filteredItems.length > 6 ? filteredItems.sublist(0, 6) : filteredItems;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('انتخاب ما', icon: Icons.thumb_up_rounded),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: displayItems.map((item) => _buildPickedItem(item)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Skeleton loader for horizontal list
  Widget _buildHorizontalSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
          child: Container(
            height: 20,
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      height: 240,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 70,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Skeleton loader for vertical list
  Widget _buildVerticalListSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
          child: Container(
            height: 20,
            width: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 100,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPickedItem(Map<String, dynamic> item) {
    final title = (item['title_fa'] as String?) ?? '';
    final author = (item['author_fa'] as String?) ?? '';
    final duration = item['total_duration_seconds'] as int? ?? 0;
    final durationStr = _formatDuration(duration);
    final isMusic = item['is_music'] == true;
    final isFree = item['is_free'] == true;
    final coverUrl = item['cover_url'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
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
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.cardGap),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover with shadow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 70,
                  height: 70,
                  color: AppColors.surfaceLight,
                  child: coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 140, // 70 * 2x DPR
                          memCacheHeight: 140,
                          errorWidget: (_, __, ___) => _buildPlaceholderIcon(isMusic),
                        )
                      : _buildPlaceholderIcon(isMusic),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.localize(title),
                    style: AppTypography.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.localize(author),
                      style: AppTypography.cardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (durationStr.isNotEmpty) ...[
                        const Icon(
                          Icons.schedule_rounded,
                          size: AppDimensions.iconWithSmallText,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          durationStr,
                          style: AppTypography.micro,
                        ),
                      ],
                      if (durationStr.isNotEmpty && isFree) ...[
                        const SizedBox(width: 12),
                      ],
                      if (isFree) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'رایگان',
                            style: AppTypography.freeBadge,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Arrow icon
            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textTertiary,
              size: 24,
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت ${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
    }
    return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
  }

  /// Search results view
  Widget _buildSearchResults() {
    if (_isLoading) {
      return const SearchResultSkeleton();
    }

    if (_errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _performSearch,
        compact: true,
      );
    }

    if (_results.isEmpty) {
      return _buildEmptyResults();
    }

    return _buildResultsList();
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'نتیجه‌ای پیدا نشد',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'عبارت دیگری را امتحان کن',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    final itemCount = _results.length + (_hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return _buildLoadMoreIndicator();
        }
        return _buildResultCard(_results[index]);
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_isLoadingMore) return const SizedBox(height: 60);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> book) {
    final isEbook = book['_is_ebook'] == true;

    // Ebook results use a separate card with different navigation
    if (isEbook) return _buildEbookResultCard(book);

    final title = (book['title_fa'] as String?) ?? '';
    final authorDisplay = (book['author_display'] as String?) ?? '';
    final narratorDisplay = (book['narrator_display'] as String?) ?? '';
    final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
    final narratorName = narratorDisplay.isNotEmpty
        ? narratorDisplay
        : ((bookMeta?['narrator_name'] as String?) ?? '');
    final author = authorDisplay.isNotEmpty
        ? authorDisplay
        : ((book['author_fa'] as String?) ?? (book['author_en'] as String?) ?? '');
    final subtitle = author.isNotEmpty ? author : narratorName;

    final isFree = book['is_free'] == true;
    final avgRating = (book['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final isMusic = book['is_music'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => AudiobookDetailScreen(
                  audiobookId: book['id'] as int,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardGap),
        child: Row(
          children: [
            // Cover
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 80,
                    color: AppColors.surfaceLight,
                    child: book['cover_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: book['cover_url'] as String,
                            fit: BoxFit.cover,
                            memCacheWidth: 120, // 60 * 2x DPR
                            memCacheHeight: 160, // 80 * 2x DPR
                            errorWidget: (_, __, ___) => _buildPlaceholderIcon(isMusic),
                          )
                        : _buildPlaceholderIcon(isMusic),
                  ),
                ),
                if (isMusic)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note_rounded, size: 10, color: AppColors.textOnPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.localize(title),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.localize(subtitle),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (avgRating > 0) ...[
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFree
                              ? AppColors.success.withValues(alpha:0.12)
                              : AppColors.primary.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isFree ? 'رایگان' : 'پولی',
                          style: TextStyle(
                            color: isFree ? AppColors.success : AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  /// Card for ebook search results — navigates to EbookDetailScreen
  Widget _buildEbookResultCard(Map<String, dynamic> ebook) {
    final title = (ebook['title_fa'] as String?) ?? '';
    final author = (ebook['author_fa'] as String?) ?? '';
    final isFree = ebook['is_free'] == true;
    final pageCount = ebook['page_count'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => EbookDetailScreen(ebook: ebook),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardGap),
            child: Row(
              children: [
                // Cover
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 60,
                        height: 90, // 2:3 ratio for ebooks
                        child: EbookCoverImage(
                          coverUrl: ebook['cover_url'] as String?,
                          coverStoragePath: ebook['cover_storage_path'] as String?,
                          width: 60,
                          height: 90,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // Ebook badge
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 10, color: AppColors.textOnPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.localize(title),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          AppStrings.localize(author),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (pageCount > 0) ...[
                            const Icon(Icons.auto_stories_rounded, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              '${FarsiUtils.toFarsiDigits(pageCount)} صفحه',
                              style: AppTypography.micro,
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFree
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFree ? 'رایگان' : 'کتاب',
                              style: TextStyle(
                                color: isFree ? AppColors.success : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(bool isMusic) {
    return Center(
      child: Icon(
        isMusic ? Icons.music_note_rounded : Icons.auto_stories_rounded,
        color: AppColors.textTertiary,
        size: 24,
      ),
    );
  }
}
