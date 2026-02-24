import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/widgets/ebook_cover_image.dart';

/// A card widget for displaying ebook information
class EbookCard extends StatelessWidget {
  final Map<String, dynamic> ebook;
  final VoidCallback? onTap;
  final bool showProgress;
  final double? progressPercentage;

  const EbookCard({
    super.key,
    required this.ebook,
    this.onTap,
    this.showProgress = false,
    this.progressPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final title = ebook['title_fa'] as String? ?? '';
    final author = ebook['author_fa'] as String? ?? '';
    final coverUrl = ebook['cover_url'] as String?;
    final isFree = ebook['is_free'] as bool? ?? false;
    final pageCount = ebook['page_count'] as int? ?? 0;
    final progress = progressPercentage ??
        (ebook['progress'] as Map<String, dynamic>?)?['completion_percentage'] as double?;

    return Semantics(
      label: '$title، $author',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 160,
          margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with progress indicator
            Stack(
              children: [
                // Cover
                Container(
                  height: 240, // 2:3 aspect ratio for book covers
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                    // No box shadow - cleaner look without frames
                  ),
                  child: EbookCoverImage(
                    coverUrl: coverUrl,
                    coverStoragePath: ebook['cover_storage_path'] as String?,
                    height: 240, // 2:3 aspect ratio for book covers
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                // Free badge
                if (isFree)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'رایگان',
                        style: AppTypography.microBadge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Progress indicator
                if (showProgress && progress != null && progress > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        color: AppColors.surface,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerRight,
                        widthFactor: progress / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Title
            Text(
              title,
              style: AppTypography.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Author
            if (author.isNotEmpty)
              Text(
                author,
                style: AppTypography.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            // Page count
            if (pageCount > 0)
              Text(
                '${FarsiUtils.toFarsiDigits(pageCount)} صفحه',
                style: AppTypography.micro,
              ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Horizontal list of ebook cards with a title header
class EbookCardList extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> ebooks;
  final VoidCallback? onSeeAllTap;
  final void Function(Map<String, dynamic>)? onEbookTap;
  final bool showProgress;

  const EbookCardList({
    super.key,
    required this.title,
    required this.ebooks,
    this.onSeeAllTap,
    this.onEbookTap,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    if (ebooks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onSeeAllTap != null)
                TextButton(
                  onPressed: onSeeAllTap,
                  child: Text(
                    'مشاهده همه',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal list
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 16),
            itemCount: ebooks.length,
            itemBuilder: (context, index) {
              final ebook = ebooks[index];
              return EbookCard(
                ebook: ebook,
                showProgress: showProgress,
                onTap: onEbookTap != null ? () => onEbookTap!(ebook) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Large featured ebook card for hero sections
class FeaturedEbookCard extends StatelessWidget {
  final Map<String, dynamic> ebook;
  final VoidCallback? onTap;

  const FeaturedEbookCard({
    super.key,
    required this.ebook,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = ebook['title_fa'] as String? ?? '';
    final author = ebook['author_fa'] as String? ?? '';
    final description = ebook['description_fa'] as String?;
    final coverUrl = ebook['cover_url'] as String?;
    final isFree = ebook['is_free'] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.2),
              AppColors.surface,
            ],
          ),
        ),
        child: Row(
          children: [
            // Cover (2:3 aspect ratio)
            Container(
              width: 100,
              height: 150, // 100×150 = 2:3 ratio
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                // No box shadow - cleaner look without frames
              ),
              child: EbookCoverImage(
                coverUrl: coverUrl,
                coverStoragePath: ebook['cover_storage_path'] as String?,
                width: 100,
                height: 150, // 2:3 ratio
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFree)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'رایگان',
                        style: AppTypography.microBadge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (author.isNotEmpty)
                    Text(
                      author,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('شروع مطالعه'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
