import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/category_screen.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/providers/category_affinity_provider.dart';

/// Section showing new content from authors the user follows.
class NewFromFollowedSection extends StatelessWidget {
  final List<Map<String, dynamic>> books;

  const NewFromFollowedSection({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  size: 16,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تازه از نویسندگانی که دنبال می‌کنید',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Padding(
                padding: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 12),
                child: RecommendationCard(book: book),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section showing top content from user's favorite category.
class FavoriteCategorySection extends StatelessWidget {
  final FavoriteCategoryContent data;

  const FavoriteCategorySection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'برتر در',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      data.category.categoryName,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CategoryScreen(
                        categoryId: data.category.categoryId,
                        categoryName: data.category.categoryName,
                      ),
                    ),
                  );
                },
                child: Text(
                  AppStrings.seeAll,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.topBooks.length,
            itemBuilder: (context, index) {
              final book = data.topBooks[index];
              return Padding(
                padding: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 12),
                child: RecommendationCard(book: book),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Card for individual recommendation (used by multiple sections).
/// Aspect-ratio-aware: 2:3 portrait for books/ebooks, 1:1 square for music/podcast/article.
class RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const RecommendationCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final title =
        (book['title_fa'] as String?) ?? (book['title_en'] as String?) ?? '';
    final author = book['author_fa'] as String? ?? '';
    final coverUrl = book['cover_url'] as String?;
    final id = book['id'] as int?;
    final contentType = (book['content_type'] as String?) ?? 'audiobook';
    final isSquare = ['music', 'podcast', 'article'].contains(contentType);

    const double cardWidth = 110;
    final double coverHeight = isSquare ? cardWidth : cardWidth * 1.5; // 1:1 or 2:3

    return GestureDetector(
      onTap: () {
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AudiobookDetailScreen(audiobookId: id),
            ),
          );
        }
      },
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: cardWidth,
              height: coverHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(
                          color: AppColors.surfaceLight,
                          child: Icon(Icons.headphones_rounded,
                              size: 32, color: AppColors.textTertiary),
                        ),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: AppColors.surfaceLight,
                          child: Icon(Icons.headphones_rounded,
                              size: 32, color: AppColors.textTertiary),
                        ),
                      )
                    : const ColoredBox(
                        color: AppColors.surfaceLight,
                        child: Icon(Icons.headphones_rounded,
                            size: 32, color: AppColors.textTertiary),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (author.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                author,
                style: AppTypography.meta.copyWith(
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
