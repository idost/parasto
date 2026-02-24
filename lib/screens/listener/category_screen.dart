import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/widgets/error_view.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

/// =============================================================================
/// CATEGORY DETAIL SCREEN (Books only)
/// =============================================================================
///
/// Shows audiobooks in a specific BOOK category.
/// FILTERS:
/// - status = 'approved' (only approved content)
/// - is_music = false (only books, not music)
/// - category_id = widget.categoryId
///
/// NOTE: This screen is for book categories. Music categories use a different
/// system via music_categories table and audiobook_music_categories junction.
/// =============================================================================

class CategoryScreen extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _audiobooks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _sortBy = 'newest';
  String? _errorMessage;
  bool _isGridView = true; // Default to grid view for category browsing

  // Pagination
  static const int _pageSize = 20;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAudiobooks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      String orderColumn = 'created_at';
      bool ascending = false;

      switch (_sortBy) {
        case 'newest':
          orderColumn = 'created_at';
          ascending = false;
          break;
        case 'popular':
          orderColumn = 'play_count';
          ascending = false;
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          ascending = false;
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }

      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('*, book_metadata(narrator_name)')
          .eq('category_id', widget.categoryId as Object)
          .eq('status', 'approved' as Object)
          .eq('is_music', false)
          .order(orderColumn, ascending: ascending)
          .range(_currentOffset + _pageSize, _currentOffset + _pageSize * 2 - 1);

      final newItems = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _currentOffset += _pageSize;
          _audiobooks.addAll(newItems);
          _hasMore = newItems.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading more audiobooks', error: e);
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      String orderColumn = 'created_at';
      bool ascending = false;

      switch (_sortBy) {
        case 'newest':
          orderColumn = 'created_at';
          ascending = false;
          break;
        case 'popular':
          orderColumn = 'play_count';
          ascending = false;
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          ascending = false;
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }

      // Query audiobooks in this category with pagination
      // Filters: approved status, books only (not music), matching category
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('*, book_metadata(narrator_name)')
          .eq('category_id', widget.categoryId as Object)
          .eq('status', 'approved' as Object)
          .eq('is_music', false) // Only books, not music
          .order(orderColumn, ascending: ascending)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _audiobooks = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          _hasMore = _audiobooks.length >= _pageSize;
        });
      }
    } on PostgrestException catch (e) {
      AppLogger.e('Category Supabase error', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطا در بارگذاری کتاب‌ها';
        });
      }
    } catch (e) {
      AppLogger.e('Error loading audiobooks', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _isNetworkError(e)
              ? 'خطا در اتصال به اینترنت'
              : 'خطا در بارگذاری کتاب‌ها';
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(
            _audiobooks.isEmpty
                ? widget.categoryName
                : '${widget.categoryName} (${FarsiUtils.toFarsiDigits(_audiobooks.length)})',
          ),
          actions: [
            // Search icon
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              ),
              tooltip: 'جستجو',
            ),
            // Grid/List view toggle
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView ? 'نمایش لیستی' : 'نمایش شبکه‌ای',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded),
              onSelected: (value) {
                setState(() => _sortBy = value);
                _loadAudiobooks();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'newest',
                  child: Row(
                    children: [
                      if (_sortBy == 'newest') const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('جدیدترین'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'popular',
                  child: Row(
                    children: [
                      if (_sortBy == 'popular') const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('محبوب‌ترین'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rating',
                  child: Row(
                    children: [
                      if (_sortBy == 'rating') const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('بالاترین امتیاز'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'title',
                  child: Row(
                    children: [
                      if (_sortBy == 'title') const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('الفبایی'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const BookGridSkeleton(itemCount: 6)
            : _errorMessage != null
                ? ErrorView(
                    message: _errorMessage!,
                    onRetry: _loadAudiobooks,
                  )
                : _audiobooks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 64, color: AppColors.textTertiary),
                            SizedBox(height: 16),
                            Text(
                              'کتابی در این دسته‌بندی یافت نشد',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                    onRefresh: _loadAudiobooks,
                    color: AppColors.primary,
                    child: _isGridView
                        ? GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _audiobooks.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _audiobooks.length) {
                                return _buildLoadMoreIndicator();
                              }
                              return _buildBookCard(_audiobooks[index]);
                            },
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _audiobooks.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _audiobooks.length) {
                                return _buildLoadMoreIndicator();
                              }
                              return _buildBookListCard(_audiobooks[index]);
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_isLoadingMore) {
      return const SizedBox(height: 60); // Spacer for scroll trigger
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildBookListCard(Map<String, dynamic> book) {
    final title = (book['title_fa'] as String?) ?? '';
    final author = (book['author_fa'] as String?) ?? (book['author_en'] as String?) ?? '';
    final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;
    final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
    final narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
    final narrator = isParastoBrand ? 'پرستو' : narratorRaw;
    final displayAuthor = author.isNotEmpty ? author : narrator;
    final isFree = book['is_free'] == true;
    final avgRating = (book['avg_rating'] as num?)?.toDouble() ?? 0.0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 70,
                  height: 105,
                  color: AppColors.surfaceLight,
                  child: book['cover_url'] != null
                      ? Image.network(
                          book['cover_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.auto_stories_rounded, color: AppColors.textTertiary),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.auto_stories_rounded, color: AppColors.textTertiary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Book info
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
                    const SizedBox(height: 4),
                    if (displayAuthor.isNotEmpty)
                      Text(
                        displayAuthor,
                        style: AppTypography.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Bottom row: Rating + Price
                    Row(
                      children: [
                        if (avgRating > 0) ...[
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFree
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isFree ? 'رایگان' : 'پولی',
                            style: TextStyle(
                              color: isFree ? AppColors.success : AppColors.primary,
                              fontSize: 12,
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
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: AppColors.surfaceLight,
                  image: book['cover_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(book['cover_url'] as String),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: book['cover_url'] == null
                    ? const Center(child: Icon(Icons.auto_stories_rounded, size: 40, color: AppColors.textTertiary))
                    : null,
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (book['title_fa'] as String?) ?? '',
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Author: prefer author_fa, fallback to author_en, then narrator
                    Builder(
                      builder: (context) {
                        final author = (book['author_fa'] as String?) ??
                            (book['author_en'] as String?) ??
                            '';
                        // Check if this book is branded as "پرستو"
                        final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;
                        // Get narrator from book_metadata.narrator_name (actual voice narrator)
                        final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
                        final narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
                        final narrator = isParastoBrand ? 'پرستو' : narratorRaw;
                        final displayText = author.isNotEmpty ? author : narrator;
                        if (displayText.isEmpty) return const SizedBox.shrink();
                        return Text(
                          displayText,
                          style: AppTypography.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          ((book['avg_rating'] as num?) ?? 0).toStringAsFixed(1),
                          style: AppTypography.labelSmall,
                        ),
                        const Spacer(),
                        if (book['is_free'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'رایگان',
                              style: AppTypography.freeBadge,
                            ),
                          ),
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
