import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/widgets/error_view.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/utils/app_logger.dart';

/// =============================================================================
/// MUSIC LIST SCREEN (Generic)
/// =============================================================================
///
/// A reusable screen that displays music items in a grid based on the list type.
/// Used for "مشاهده همه" (View All) functionality from music screen sections.
///
/// List Types:
/// - 'new': جدیدترین‌ها (New Releases)
/// - 'featured': موسیقی ویژه (Featured Music)
/// - 'popular': پرشنونده‌ترین‌ها (Popular Music)
/// - 'recent': ادامه‌ی شنیدن (Continue Listening / Recently Played)
/// =============================================================================

enum MusicListType {
  newReleases,
  featured,
  popular,
  continueListening,
}

class MusicListScreen extends ConsumerStatefulWidget {
  final String title;
  final MusicListType listType;

  const MusicListScreen({
    super.key,
    required this.title,
    required this.listType,
  });

  @override
  ConsumerState<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends ConsumerState<MusicListScreen> {
  List<Map<String, dynamic>> _musicItems = [];
  bool _isLoading = true;
  String _sortBy = 'default'; // 'default' uses list-type specific sorting
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMusic();
  }

  Future<void> _loadMusic() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _fetchMusic();
      if (mounted) {
        setState(() {
          _musicItems = response;
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      AppLogger.e('MusicList Supabase error', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطا در بارگذاری موسیقی';
        });
      }
    } catch (e) {
      AppLogger.e('Error loading music', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _isNetworkError(e)
              ? 'خطا در اتصال به اینترنت'
              : 'خطا در بارگذاری موسیقی';
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMusic() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    switch (widget.listType) {
      case MusicListType.newReleases:
        return _fetchNewReleases();
      case MusicListType.featured:
        return _fetchFeatured();
      case MusicListType.popular:
        return _fetchPopular();
      case MusicListType.continueListening:
        if (userId == null) return [];
        return _fetchContinueListening(userId);
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

    // PERFORMANCE: Select only needed columns instead of *
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
          author_fa, play_count, avg_rating, created_at,
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('is_music', true)
        .order(orderColumn, ascending: ascending)
        .limit(100);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchFeatured() async {
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

    // PERFORMANCE: Select only needed columns instead of *
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
          author_fa, play_count, avg_rating, created_at,
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('is_music', true)
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

    // PERFORMANCE: Select only needed columns instead of *
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
          author_fa, play_count, avg_rating, created_at,
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('is_music', true)
        .order(orderColumn, ascending: ascending)
        .limit(100);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchContinueListening(String userId) async {
    // Get user's listening progress for music, ordered by last played
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

    // Fetch music details (is_music = true)
    // PERFORMANCE: Select only needed columns instead of *
    final musicResponse = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, is_music, is_free, is_parasto_brand,
          author_fa, play_count, avg_rating,
          music_metadata(artist_name, featured_artists)
        ''')
        .inFilter('id', audiobookIds)
        .eq('status', 'approved')
        .eq('is_music', true);

    // Sort by the order from listening_progress
    final musicMap = <int, Map<String, dynamic>>{};
    for (final item in musicResponse) {
      musicMap[item['id'] as int] = item;
    }

    final result = <Map<String, dynamic>>[];
    for (final id in audiobookIds) {
      if (musicMap.containsKey(id)) {
        result.add(musicMap[id]!);
      }
    }

    return result;
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
      case MusicListType.newReleases:
        defaultLabel = 'جدیدترین';
        break;
      case MusicListType.featured:
        defaultLabel = 'پیشنهادی';
        break;
      case MusicListType.popular:
        defaultLabel = 'محبوب‌ترین';
        break;
      case MusicListType.continueListening:
        defaultLabel = 'آخرین شنیده شده';
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

    // Add other sort options (except for continueListening which has fixed order)
    if (widget.listType != MusicListType.continueListening) {
      if (widget.listType != MusicListType.newReleases) {
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

      if (widget.listType != MusicListType.popular) {
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
            if (widget.listType != MusicListType.continueListening)
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (value) {
                  setState(() => _sortBy = value);
                  _loadMusic();
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
                    onRetry: _loadMusic,
                  )
                : _musicItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_off, size: 64, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              _getEmptyMessage(),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMusic,
                        color: AppColors.primary,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _musicItems.length,
                          itemBuilder: (context, index) => _buildMusicCard(_musicItems[index]),
                        ),
                      ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (widget.listType) {
      case MusicListType.newReleases:
        return 'موسیقی جدیدی یافت نشد';
      case MusicListType.featured:
        return 'موسیقی ویژه‌ای یافت نشد';
      case MusicListType.popular:
        return 'موسیقی‌ای یافت نشد';
      case MusicListType.continueListening:
        return 'هنوز موسیقی‌ای گوش نداده‌اید';
    }
  }

  Widget _buildMusicCard(Map<String, dynamic> item) {
    final title = (item['title_fa'] as String?) ?? '';
    final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
    // Get artist from music_metadata (not profiles which is the uploader account)
    final musicMeta = item['music_metadata'] as Map<String, dynamic>?;
    final artistRaw = (musicMeta?['artist_name'] as String?) ?? '';
    final artist = isParastoBrand ? 'پرستو' : artistRaw;
    final coverUrl = item['cover_url'] as String?;
    final isFree = item['is_free'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AudiobookDetailScreen(audiobookId: item['id'] as int),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover with shadow (square for music)
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                    // Play icon overlay
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 20,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    // Free badge
                    if (isFree)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Artist
          if (artist.isNotEmpty)
            Text(
              artist,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.music_note, color: AppColors.textTertiary, size: 40),
      ),
    );
  }
}
