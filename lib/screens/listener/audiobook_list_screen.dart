import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/widgets/error_view.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/utils/app_logger.dart';

/// =============================================================================
/// AUDIOBOOK LIST SCREEN (Generic)
/// =============================================================================
///
/// A reusable screen that displays audiobooks in a grid based on the list type.
/// Used for "مشاهده همه" (View All) functionality from home screen sections.
///
/// List Types:
/// - 'new': جدیدترین کتاب‌ها (New Releases)
/// - 'featured': پیشنهاد کتاب‌ها (Featured Books)
/// - 'popular': پرشنونده‌ترین کتاب‌ها (Popular Books)
/// - 'recent': اخیراً شنیده شده (Recently Played)
/// =============================================================================

enum AudiobookListType {
  newReleases,
  featured,
  popular,
  recentlyPlayed,
  podcasts,
  articles,
}

class AudiobookListScreen extends ConsumerStatefulWidget {
  final String title;
  final AudiobookListType listType;

  const AudiobookListScreen({
    super.key,
    required this.title,
    required this.listType,
  });

  @override
  ConsumerState<AudiobookListScreen> createState() => _AudiobookListScreenState();
}

class _AudiobookListScreenState extends ConsumerState<AudiobookListScreen> {
  List<Map<String, dynamic>> _audiobooks = [];
  bool _isLoading = true;
  String _sortBy = 'default'; // 'default' uses list-type specific sorting
  String? _errorMessage;
  bool _isGridView = true; // Default to grid view

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _fetchAudiobooks();
      if (mounted) {
        setState(() {
          _audiobooks = response;
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      AppLogger.e('AudiobookList Supabase error', error: e);
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

  Future<List<Map<String, dynamic>>> _fetchAudiobooks() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    switch (widget.listType) {
      case AudiobookListType.newReleases:
        return _fetchNewReleases();
      case AudiobookListType.featured:
        return _fetchFeatured();
      case AudiobookListType.popular:
        return _fetchPopular();
      case AudiobookListType.recentlyPlayed:
        if (userId == null) return [];
        return _fetchRecentlyPlayed(userId);
      case AudiobookListType.podcasts:
        return _fetchPodcasts();
      case AudiobookListType.articles:
        return _fetchArticles();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNewReleases() async {
    String orderColumn = 'created_at';
    bool ascending = false;

    if (_sortBy != 'default') {
      switch (_sortBy) {
        case 'popular':
          orderColumn = 'play_count';
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }
    }

    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('*, book_metadata(narrator_name)')
        .eq('status', 'approved')
        .eq('is_music', false)
        .order(orderColumn, ascending: ascending)
        .limit(100);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchFeatured() async {
    // Default sort by created_at (featured_at column doesn't exist in schema)
    String orderColumn = 'created_at';
    bool ascending = false;

    if (_sortBy != 'default') {
      switch (_sortBy) {
        case 'newest':
          orderColumn = 'created_at';
          break;
        case 'popular':
          orderColumn = 'play_count';
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }
    }

    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('*, book_metadata(narrator_name)')
        .eq('status', 'approved')
        .eq('is_music', false)
        .eq('is_featured', true)
        .order(orderColumn, ascending: ascending)
        .limit(100);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchPopular() async {
    String orderColumn = 'play_count';
    bool ascending = false;

    if (_sortBy != 'default') {
      switch (_sortBy) {
        case 'newest':
          orderColumn = 'created_at';
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }
    }

    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('*, book_metadata(narrator_name)')
        .eq('status', 'approved')
        .eq('is_music', false)
        .order(orderColumn, ascending: ascending)
        .limit(100);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchRecentlyPlayed(String userId) async {
    // Get user's listening progress ordered by last played
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select('audiobook_id, updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(50);

    if (progressResponse.isEmpty) return [];

    final audiobookIds = (progressResponse as List)
        .map((p) => p['audiobook_id'] as int)
        .toList();

    // Fetch audiobook details
    final audiobooksResponse = await Supabase.instance.client
        .from('audiobooks')
        .select('*, book_metadata(narrator_name)')
        .inFilter('id', audiobookIds)
        .eq('status', 'approved')
        .eq('is_music', false);

    // Sort by the order from listening_progress
    final audiobooksMap = <int, Map<String, dynamic>>{};
    for (final book in audiobooksResponse) {
      audiobooksMap[book['id'] as int] = book;
    }

    final result = <Map<String, dynamic>>[];
    for (final id in audiobookIds) {
      if (audiobooksMap.containsKey(id)) {
        result.add(audiobooksMap[id]!);
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchPodcasts() async {
    String orderColumn = 'created_at';
    bool ascending = false;

    if (_sortBy != 'default') {
      switch (_sortBy) {
        case 'popular':
          orderColumn = 'play_count';
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }
    }

    try {
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('*, book_metadata(narrator_name)')
          .eq('status', 'approved')
          .eq('is_podcast', true)
          .order(orderColumn, ascending: ascending)
          .limit(100);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      // Return empty list if is_podcast column doesn't exist yet
      if (e.message.contains('is_podcast') || e.message.contains('is-podcast') || e.code == '42703' || e.code == '400') {
        return [];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchArticles() async {
    String orderColumn = 'created_at';
    bool ascending = false;

    if (_sortBy != 'default') {
      switch (_sortBy) {
        case 'popular':
          orderColumn = 'play_count';
          break;
        case 'rating':
          orderColumn = 'avg_rating';
          break;
        case 'title':
          orderColumn = 'title_fa';
          ascending = true;
          break;
      }
    }

    try {
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('*, book_metadata(narrator_name)')
          .eq('status', 'approved')
          .eq('is_article', true)
          .order(orderColumn, ascending: ascending)
          .limit(100);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      if (e.message.contains('is_article') || e.message.contains('is-article') || e.code == '42703' || e.code == '400') {
        return [];
      }
      rethrow;
    }
  }

  bool _isNetworkError(dynamic e) {
    final message = e.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('timeout');
  }

  List<PopupMenuItem<String>> _buildSortMenuItems() {
    final items = <PopupMenuItem<String>>[];

    // Default option based on list type
    String defaultLabel;
    switch (widget.listType) {
      case AudiobookListType.newReleases:
        defaultLabel = 'جدیدترین';
        break;
      case AudiobookListType.featured:
        defaultLabel = 'پیشنهادی';
        break;
      case AudiobookListType.popular:
        defaultLabel = 'محبوب‌ترین';
        break;
      case AudiobookListType.recentlyPlayed:
        defaultLabel = 'آخرین شنیده شده';
        break;
      case AudiobookListType.podcasts:
        defaultLabel = 'جدیدترین';
        break;
      case AudiobookListType.articles:
        defaultLabel = 'جدیدترین';
        break;
    }

    items.add(PopupMenuItem(
      value: 'default',
      child: Row(
        children: [
          if (_sortBy == 'default') const Icon(Icons.check, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(defaultLabel),
        ],
      ),
    ));

    // Add other sort options (except for recentlyPlayed which has fixed order)
    if (widget.listType != AudiobookListType.recentlyPlayed) {
      if (widget.listType != AudiobookListType.newReleases) {
        items.add(PopupMenuItem(
          value: 'newest',
          child: Row(
            children: [
              if (_sortBy == 'newest') const Icon(Icons.check, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('جدیدترین'),
            ],
          ),
        ));
      }

      if (widget.listType != AudiobookListType.popular) {
        items.add(PopupMenuItem(
          value: 'popular',
          child: Row(
            children: [
              if (_sortBy == 'popular') const Icon(Icons.check, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('محبوب‌ترین'),
            ],
          ),
        ));
      }

      items.add(PopupMenuItem(
        value: 'rating',
        child: Row(
          children: [
            if (_sortBy == 'rating') const Icon(Icons.check, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('بالاترین امتیاز'),
          ],
        ),
      ));

      items.add(PopupMenuItem(
        value: 'title',
        child: Row(
          children: [
            if (_sortBy == 'title') const Icon(Icons.check, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('الفبایی'),
          ],
        ),
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(widget.title),
          actions: [
            // Search icon
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textSecondary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              ),
              tooltip: 'جستجو',
            ),
            // Grid/List view toggle
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView ? 'نمایش لیستی' : 'نمایش شبکه‌ای',
            ),
            if (widget.listType != AudiobookListType.recentlyPlayed)
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (value) {
                  setState(() => _sortBy = value);
                  _loadAudiobooks();
                },
                itemBuilder: (context) => _buildSortMenuItems(),
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
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.library_books_outlined, size: 64, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              _getEmptyMessage(),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAudiobooks,
                        color: AppColors.primary,
                        child: _isGridView
                            ? GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.58,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _audiobooks.length,
                                itemBuilder: (context, index) {
                                  final book = _audiobooks[index];
                                  return KeyedSubtree(
                                    key: ValueKey(book['id']),
                                    child: _buildBookCard(book),
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _audiobooks.length,
                                itemBuilder: (context, index) {
                                  final book = _audiobooks[index];
                                  return KeyedSubtree(
                                    key: ValueKey(book['id']),
                                    child: _buildBookListCard(book),
                                  );
                                },
                              ),
                      ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (widget.listType) {
      case AudiobookListType.newReleases:
        return 'کتاب جدیدی یافت نشد';
      case AudiobookListType.featured:
        return 'کتاب پیشنهادی یافت نشد';
      case AudiobookListType.popular:
        return 'کتابی یافت نشد';
      case AudiobookListType.recentlyPlayed:
        return 'هنوز کتابی گوش نداده‌اید';
      case AudiobookListType.podcasts:
        return 'پادکستی یافت نشد';
      case AudiobookListType.articles:
        return 'مقاله‌ای یافت نشد';
    }
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
      margin: const EdgeInsets.only(bottom: 12),
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
                  width: 60,
                  height: 80,
                  color: AppColors.surfaceLight,
                  child: book['cover_url'] != null
                      ? Image.network(
                          book['cover_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.book, color: AppColors.textTertiary),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.book, color: AppColors.textTertiary),
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (displayAuthor.isNotEmpty)
                      Text(
                        displayAuthor,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Bottom row: Rating + Price
                    Row(
                      children: [
                        if (avgRating > 0) ...[
                          const Icon(Icons.star, size: 14, color: AppColors.warning),
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
              flex: 3,
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
                    ? const Center(child: Icon(Icons.book, size: 40, color: AppColors.textTertiary))
                    : null,
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (book['title_fa'] as String?) ?? '',
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
                        final author = (book['author_fa'] as String?) ??
                            (book['author_en'] as String?) ??
                            '';
                        final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;
                        // Get narrator from book_metadata.narrator_name (actual voice narrator)
                        final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
                        final narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
                        final narrator = isParastoBrand ? 'پرستو' : narratorRaw;
                        final displayText = author.isNotEmpty ? author : narrator;
                        if (displayText.isEmpty) return const SizedBox.shrink();
                        return Text(
                          displayText,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          ((book['avg_rating'] as num?) ?? 0).toStringAsFixed(1),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                              style: TextStyle(color: AppColors.success, fontSize: 10),
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
