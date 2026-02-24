import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/audiobook_list_screen.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/utils/farsi_utils.dart';

// ============================================
// RECENTLY PLAYED SHELF (UI-HOME-LIB-003)
// ============================================
//
// This widget was extracted from home_screen.dart and moved to Library
// as part of the UI-HOME-LIB migration (Phase 2).
//
// Shows a horizontal scrolling list of recently played audiobooks
// with progress indicators.
//
// Used in: library_screen.dart (My Items tab)
// Provider: homeRecentlyPlayedProvider (from home_providers.dart)
// ============================================

/// Reusable recently played shelf widget for Library screen
/// Shows horizontal list of recently played audiobooks with progress
class RecentlyPlayedShelf extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final VoidCallback? onSeeAll;

  const RecentlyPlayedShelf({
    super.key,
    required this.books,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecentlyPlayedHeader(onSeeAll: onSeeAll),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _RecentlyPlayedCard(
                key: ValueKey(book['id']),
                book: book,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section header for Recently Played
class _RecentlyPlayedHeader extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const _RecentlyPlayedHeader({this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.recentlyPlayed,
                style: AppTypography.sectionTitle,
              ),
            ],
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    AppStrings.seeAll,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primary,
                    size: 12,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Card for a single recently played audiobook
class _RecentlyPlayedCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _RecentlyPlayedCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final title = (book['title_fa'] as String?) ?? (book['title'] as String?) ?? '';
    final coverUrl = book['cover_url'] as String?;
    final progress = book['progress'] as Map<String, dynamic>?;
    final completionPercentage = (progress?['completion_percentage'] as num?)?.toInt() ?? 0;
    // Check if this book is branded as "پرستو"
    final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;
    // Get narrator from book_metadata.narrator_name (actual voice narrator)
    // NOT from profiles (which is just the uploader account)
    final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
    final narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
    final narrator = isParastoBrand ? AppStrings.appName : narratorRaw;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsetsDirectional.only(start: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 130,
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 200, // 100 * 2x DPR
                        memCacheHeight: 260, // 130 * 2x DPR
                        placeholder: (_, __) => const ColoredBox(
                          color: AppColors.surfaceLight,
                          child: Icon(Icons.headphones_rounded, size: 32, color: AppColors.textTertiary),
                        ),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: AppColors.surfaceLight,
                          child: Icon(Icons.headphones_rounded, size: 32, color: AppColors.textTertiary),
                        ),
                      )
                    : const ColoredBox(
                        color: AppColors.surfaceLight,
                        child: Icon(Icons.headphones_rounded, size: 32, color: AppColors.textTertiary),
                      ),
              ),
            ),
            // Book info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.localize(title),
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (narrator.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.localize(narrator),
                        style: AppTypography.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (completionPercentage.clamp(0, 100)) / 100,
                              backgroundColor: AppColors.surfaceLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${FarsiUtils.toFarsiDigits(completionPercentage.clamp(0, 100).round())}٪',
                            style: AppTypography.progressText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Play button indicator
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Helper function to navigate to the full Recently Played list
void navigateToRecentlyPlayedList(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AudiobookListScreen(
        title: AppStrings.recentlyPlayed,
        listType: AudiobookListType.recentlyPlayed,
      ),
    ),
  );
}
