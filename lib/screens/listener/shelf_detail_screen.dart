import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/promotion_providers.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/widgets/skeleton_loaders.dart';

String _formatPriceUsd(num price) {
  // Price is stored as USD
  if (price < 1) {
    return '\$${price.toStringAsFixed(2)}';
  }
  return '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
}

class ShelfDetailScreen extends ConsumerStatefulWidget {
  final int shelfId;
  final String? shelfTitle;

  const ShelfDetailScreen({
    super.key,
    required this.shelfId,
    this.shelfTitle,
  });

  @override
  ConsumerState<ShelfDetailScreen> createState() => _ShelfDetailScreenState();
}

class _ShelfDetailScreenState extends ConsumerState<ShelfDetailScreen> {
  bool _isGridView = true; // Default to grid view

  @override
  Widget build(BuildContext context) {
    final shelfAsync = ref.watch(shelfDetailProvider(widget.shelfId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(widget.shelfTitle ?? 'قفسه'),
          centerTitle: true,
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
          ],
        ),
        body: shelfAsync.when(
          loading: () => const BookGridSkeleton(itemCount: 6),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text('خطا در بارگذاری قفسه', style: TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(shelfDetailProvider(widget.shelfId)),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
          data: (shelf) {
            if (shelf == null) {
              return const Center(
                child: Text('قفسه یافت نشد', style: TextStyle(color: AppColors.textSecondary)),
              );
            }

            final audiobooks = shelf['audiobooks'] as List<dynamic>? ?? [];

            if (audiobooks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text('کتابی در این قفسه نیست', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(shelfDetailProvider(widget.shelfId)),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description if available
                  if (shelf['description_fa'] != null && (shelf['description_fa'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        shelf['description_fa'] as String,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),

                  // Books Grid or List
                  Expanded(
                    child: _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.50, // Account for title + author text below 2:3 cover
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: audiobooks.length,
                            itemBuilder: (context, index) {
                              final book = audiobooks[index] as Map<String, dynamic>;
                              return _buildBookCard(context, book);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: audiobooks.length,
                            itemBuilder: (context, index) {
                              final book = audiobooks[index] as Map<String, dynamic>;
                              return _buildBookListCard(context, book);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookListCard(BuildContext context, Map<String, dynamic> book) {
    final title = (book['title_fa'] as String?) ?? '';
    final author = (book['author_fa'] as String?) ?? (book['author_en'] as String?) ?? '';
    final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;
    final contentType = (book['content_type'] as String?) ?? 'audiobook';
    final isMusic = contentType == 'music';
    String narratorRaw = '';
    if (isMusic) {
      final musicMeta = book['music_metadata'] as Map<String, dynamic>?;
      narratorRaw = (musicMeta?['artist_name'] as String?) ?? '';
    } else {
      final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
      narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
    }
    final narrator = isParastoBrand ? 'پرستو' : narratorRaw;
    final displayAuthor = author.isNotEmpty ? author : narrator;
    final isFree = book['is_free'] == true;
    final avgRating = (book['avg_rating'] as num?)?.toDouble() ?? 0.0;

    // Choose placeholder icon based on content type
    final IconData placeholderIcon = switch (contentType) {
      'music' => Icons.music_note,
      'podcast' => Icons.podcasts,
      'article' => Icons.article,
      _ => Icons.book,
    };

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
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              placeholderIcon,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            placeholderIcon,
                            color: AppColors.textTertiary,
                          ),
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
                        if (isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'رایگان',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Text(
                            _formatPriceUsd((book['price_toman'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(color: AppColors.primary, fontSize: 12),
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

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book) {
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
                    // Author: prefer author_fa, fallback to author_en, then narrator from book_metadata
                    Builder(
                      builder: (context) {
                        final author = (book['author_fa'] as String?) ??
                            (book['author_en'] as String?) ??
                            '';
                        // Check if this book is branded as "پرستو"
                        final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;
                        final contentType = (book['content_type'] as String?) ?? 'audiobook';
                        // Get narrator/artist from correct metadata table (not profiles which is the uploader account)
                        String narratorRaw = '';
                        if (contentType == 'music') {
                          final musicMeta = book['music_metadata'] as Map<String, dynamic>?;
                          narratorRaw = (musicMeta?['artist_name'] as String?) ?? '';
                        } else {
                          final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
                          narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
                        }
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
                        if (book['avg_rating'] != null) ...[
                          const Icon(Icons.star, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            ((book['avg_rating'] as num?) ?? 0).toStringAsFixed(1),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
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
                          )
                        else
                          Text(
                            _formatPriceUsd((book['price_toman'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(color: AppColors.primary, fontSize: 10),
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
