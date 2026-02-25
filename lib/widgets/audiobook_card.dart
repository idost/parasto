import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/common/optimized_cover_image.dart';
import 'package:myna/widgets/content_type_micro_label.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/utils/app_strings.dart';

/// =============================================================================
/// AUDIOBOOK CARD - Reusable Card Widget
/// =============================================================================
///
/// A versatile card for displaying audiobook/music items in horizontal lists
/// and grid views. Used across home, search, library, and recommendation screens.
///
/// Features:
/// - Cover image with shadow and Hero animation (list→detail transition)
/// - Optional progress overlay bar at bottom of cover
/// - Optional download badge (checkmark at bottom-end)
/// - Music/Podcast type badges (top-end)
/// - Title (2 lines max) + Author/Narrator + optional Price badge
/// - RTL-safe: uses EdgeInsetsDirectional and Positioned.directional
/// =============================================================================

class AudiobookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final double width;
  final double coverHeight;
  final bool showPrice;
  final VoidCallback? onTap;

  /// Reading progress (0.0 – 1.0). If non-null, a thin accent bar shows at the
  /// bottom of the cover image. Pass `null` to hide.
  final double? progress;

  /// If true, shows a small checkmark badge at the bottom-end of the cover.
  final bool isDownloaded;

  const AudiobookCard({
    super.key,
    required this.book,
    this.width = AppDimensions.cardWidth,
    this.coverHeight = AppDimensions.cardCoverHeight,
    this.showPrice = true,
    this.onTap,
    this.progress,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = (book['title_fa'] as String?) ?? '';
    final contentType = (book['content_type'] as String?) ?? 'audiobook';
    final isMusic = contentType == 'music';
    final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;

    // Aspect-ratio-aware cover: square for music/podcast/article, portrait otherwise
    final bool isSquareCover = ['music', 'podcast', 'article'].contains(contentType);
    final double effectiveCoverHeight =
        isSquareCover ? width : coverHeight; // 1:1 or passed 2:3

    // Narrator/Artist derivation
    String narratorOrArtist = '';
    if (isMusic) {
      final musicMeta = book['music_metadata'] as Map<String, dynamic>?;
      narratorOrArtist = (musicMeta?['artist_name'] as String?) ??
          (book['author_fa'] as String?) ??
          '';
    } else {
      final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
      narratorOrArtist = (bookMeta?['narrator_name'] as String?) ?? '';
    }
    final narrator = isParastoBrand ? AppStrings.appName : narratorOrArtist;
    final author =
        (book['author_fa'] as String?) ?? (book['author_en'] as String?) ?? '';
    final isFree = book['is_free'] == true;
    final price = (book['price_toman'] as num?) ?? 0;
    final coverUrl = book['cover_url'] as String?;
    final bookId = book['id'];

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    AudiobookDetailScreen(audiobookId: bookId as int),
              ),
            );
          },
      child: Container(
        width: width,
        margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover with shadow, Hero animation, and overlays
            Container(
              height: effectiveCoverHeight,
              width: width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Hero(
                tag: 'cover_$bookId',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image (optimized with server-side resizing for Supabase URLs)
                      coverUrl != null
                          ? OptimizedCoverImage(
                              coverUrl: coverUrl,
                              width: width,
                              height: effectiveCoverHeight,
                              fit: BoxFit.cover,
                            )
                          : _buildPlaceholder(),

                      // Micro text label (bottom-start)
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        bottom: 6,
                        start: 6,
                        child: ContentTypeMicroLabel.fromData(book),
                      ),

                      // Download badge (bottom-end)
                      if (isDownloaded)
                        Positioned.directional(
                          textDirection: Directionality.of(context),
                          bottom: 6,
                          end: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),

                      // Progress bar (bottom of cover, thin)
                      if (progress != null && progress! > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: progress!.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Title (fixed height, 2 lines max)
            SizedBox(
              height: 40,
              child: Text(
                AppStrings.localize(title),
                style: AppTypography.cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),

            // Author/Narrator (fixed height, single line)
            SizedBox(
              height: 20,
              child: Text(
                AppStrings.localize(
                    author.isNotEmpty ? author : narrator),
                style: AppTypography.cardSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (showPrice) ...[
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFree
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  isFree ? AppStrings.free : _formatPrice(price),
                  style: AppTypography.badge.copyWith(
                    color: isFree ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.headphones_rounded,
            color: AppColors.textTertiary, size: 40),
      ),
    );
  }

  String _formatPrice(num price) {
    if (price < 1) {
      return '\$${price.toStringAsFixed(2)}';
    }
    return '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
  }
}

/// Compact version of AudiobookCard for smaller spaces (e.g., search results)
class AudiobookCardCompact extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback? onTap;

  const AudiobookCardCompact({
    super.key,
    required this.book,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentType = (book['content_type'] as String?) ?? 'audiobook';
    final isSquareCover = ['music', 'podcast', 'article'].contains(contentType);

    return AudiobookCard(
      book: book,
      width: AppDimensions.cardWidthSmall,
      coverHeight: isSquareCover
          ? AppDimensions.cardWidthSmall // 1:1
          : AppDimensions.cardCoverHeightSmall, // 2:3
      showPrice: false,
      onTap: onTap,
    );
  }
}
