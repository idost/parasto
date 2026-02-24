import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/ebook_detail_screen.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/widgets/section_header.dart';
import 'package:myna/widgets/swipeable_audiobook_detail.dart';

/// Section showing all incomplete content (audiobooks, ebooks, podcasts).
/// Sorted by last activity (most recent first).
/// Uses horizontal carousel layout (Netflix/Spotify style).
class ContinueSection extends ConsumerWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>>? allItems;

  const ContinueSection({super.key, required this.items, this.allItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final audiobookItems =
        items.where((i) => i['content_type'] != 'ebook').toList();
    final audiobookIds = audiobookItems.map((b) => b['id'] as int).toList();
    final ebookItems = items.where((i) => i['content_type'] == 'ebook').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'ادامه',
          onSeeAll: allItems != null && allItems!.length > items.length
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ContinueAllScreen(items: allItems!),
                    ),
                  )
              : null,
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 16, start: 4),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final contentType = item['content_type'] as String?;

              if (contentType == 'ebook') {
                final ebookIndex =
                    ebookItems.indexWhere((e) => e['id'] == item['id']);
                return ContinueCard(
                  key: ValueKey('continue_ebook_${item['id']}'),
                  item: item,
                  allEbooks: ebookItems,
                  ebookIndex: ebookIndex >= 0 ? ebookIndex : null,
                );
              } else {
                final audiobookIndex =
                    audiobookItems.indexWhere((a) => a['id'] == item['id']);
                return ContinueCard(
                  key: ValueKey('continue_${contentType}_${item['id']}'),
                  item: item,
                  allAudiobookIds: audiobookIds,
                  audiobookIndex: audiobookIndex >= 0 ? audiobookIndex : null,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Full screen for viewing all "Continue" items.
class ContinueAllScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const ContinueAllScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ادامه'),
        backgroundColor: AppColors.background,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return ContinueListTile(item: items[index]);
        },
      ),
    );
  }
}

/// List tile for "See All" screen.
class ContinueListTile extends ConsumerWidget {
  final Map<String, dynamic> item;

  const ContinueListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentType = (item['content_type'] as String?) ?? 'audiobook';
    final isEbook = contentType == 'ebook';
    final title =
        (item['title_fa'] as String?) ?? (item['title'] as String?) ?? '';
    final coverUrl = item['cover_url'] as String?;
    final progress = item['progress'] as Map<String, dynamic>?;
    final completionPercentage =
        (progress?['completion_percentage'] as num?)?.toInt() ?? 0;
    final author = (item['author_fa'] as String?) ?? '';

    IconData placeholderIcon;
    switch (contentType) {
      case 'ebook':
        placeholderIcon = Icons.menu_book_rounded;
      case 'podcast':
        placeholderIcon = Icons.podcasts_rounded;
      default:
        placeholderIcon = Icons.headphones_rounded;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceLight, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isEbook) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EbookDetailScreen(ebook: item),
                ),
              );
            } else {
              final id = item['id'] as int?;
              if (id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AudiobookDetailScreen(audiobookId: id),
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 99,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 132, // 66 * 2x DPR
                            memCacheHeight: 198, // 99 * 2x DPR
                            placeholder: (_, __) => ColoredBox(
                              color: AppColors.surfaceLight,
                              child: Icon(placeholderIcon,
                                  color: AppColors.textTertiary),
                            ),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: AppColors.surfaceLight,
                              child: Icon(placeholderIcon,
                                  color: AppColors.textTertiary),
                            ),
                          )
                        : ColoredBox(
                            color: AppColors.surfaceLight,
                            child: Icon(placeholderIcon,
                                color: AppColors.textTertiary),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.localize(title),
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.localize(author),
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: completionPercentage / 100,
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${FarsiUtils.toFarsiDigits(completionPercentage)}٪',
                        style: AppTypography.meta
                            .copyWith(color: AppColors.textTertiary, fontSize: 11),
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
}

/// Compact card for horizontal carousel in Continue section.
/// Shows cover, title, chapter info, time remaining, and play/read button.
class ContinueCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final List<int>? allAudiobookIds;
  final int? audiobookIndex;
  final List<Map<String, dynamic>>? allEbooks;
  final int? ebookIndex;

  const ContinueCard({
    super.key,
    required this.item,
    this.allAudiobookIds,
    this.audiobookIndex,
    this.allEbooks,
    this.ebookIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentType = (item['content_type'] as String?) ?? 'audiobook';
    final isEbook = contentType == 'ebook';
    final title =
        (item['title_fa'] as String?) ?? (item['title'] as String?) ?? '';
    final author = (item['author_fa'] as String?) ?? '';
    final coverUrl = item['cover_url'] as String?;
    final progress = item['progress'] as Map<String, dynamic>?;
    final completionPercentage =
        (progress?['completion_percentage'] as num?)?.toInt() ?? 0;

    String chapterInfo = '';
    String timeRemaining = '';
    if (!isEbook) {
      final chapters = (item['chapters'] as List<dynamic>?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          [];
      final currentChapterIndex =
          (progress?['current_chapter_index'] as num?)?.toInt() ?? 0;
      final positionSeconds =
          (progress?['position_seconds'] as num?)?.toInt() ?? 0;

      if (chapters.isNotEmpty && currentChapterIndex < chapters.length) {
        final chapterTitle =
            chapters[currentChapterIndex]['title_fa'] as String?;
        if (chapterTitle != null && chapterTitle.isNotEmpty) {
          chapterInfo = chapterTitle;
        } else {
          chapterInfo = 'فصل ${FarsiUtils.toFarsiDigits(currentChapterIndex + 1)}';
        }
      }
      timeRemaining =
          _calcTimeRemaining(chapters, currentChapterIndex, positionSeconds);
    } else {
      final currentPage = (progress?['current_page'] as num?)?.toInt() ?? 0;
      final totalPages = (item['page_count'] as num?)?.toInt() ?? 0;
      if (totalPages > 0) {
        chapterInfo =
            'صفحه ${FarsiUtils.toFarsiDigits(currentPage)} از ${FarsiUtils.toFarsiDigits(totalPages)}';
      }
    }

    IconData placeholderIcon;
    IconData actionIcon;
    switch (contentType) {
      case 'ebook':
        placeholderIcon = Icons.menu_book_rounded;
        actionIcon = Icons.auto_stories_rounded;
      case 'podcast':
        placeholderIcon = Icons.podcasts_rounded;
        actionIcon = Icons.play_arrow_rounded;
      default:
        placeholderIcon = Icons.headphones_rounded;
        actionIcon = Icons.play_arrow_rounded;
    }

    return Container(
      width: 280,
      margin: const EdgeInsetsDirectional.only(start: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToDetail(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildCoverWithProgress(
                  coverUrl: coverUrl,
                  completionPercentage: completionPercentage,
                  placeholderIcon: placeholderIcon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.localize(title),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          author,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${FarsiUtils.toFarsiDigits(completionPercentage)}٪',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (timeRemaining.isNotEmpty ||
                              chapterInfo.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                timeRemaining.isNotEmpty
                                    ? '$timeRemaining ${AppStrings.remaining}'
                                    : chapterInfo,
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      Icon(actionIcon, color: AppColors.textOnPrimary, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverWithProgress({
    required String? coverUrl,
    required int completionPercentage,
    required IconData placeholderIcon,
  }) {
    const double width = 70;
    const double height = 105;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(
                        color: AppColors.surfaceLight,
                        child: Icon(placeholderIcon,
                            size: 24, color: AppColors.textTertiary),
                      ),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: AppColors.surfaceLight,
                        child: Icon(placeholderIcon,
                            size: 24, color: AppColors.textTertiary),
                      ),
                    )
                  : ColoredBox(
                      color: AppColors.surfaceLight,
                      child: Icon(placeholderIcon,
                          size: 24, color: AppColors.textTertiary),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: LinearProgressIndicator(
                value: completionPercentage / 100,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    final contentType = (item['content_type'] as String?) ?? 'audiobook';
    final isEbook = contentType == 'ebook';

    if (isEbook) {
      if (allEbooks != null && allEbooks!.length > 1 && ebookIndex != null) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SwipeableEbookDetail(
              ebooks: allEbooks!,
              initialIndex: ebookIndex!,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => EbookDetailScreen(ebook: item),
          ),
        );
      }
    } else {
      final id = item['id'] as int?;
      if (id != null) {
        if (allAudiobookIds != null &&
            allAudiobookIds!.length > 1 &&
            audiobookIndex != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SwipeableAudiobookDetail(
                audiobookIds: allAudiobookIds!,
                initialIndex: audiobookIndex!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AudiobookDetailScreen(audiobookId: id),
            ),
          );
        }
      }
    }
  }

  String _calcTimeRemaining(
    List<Map<String, dynamic>> chapters,
    int currentChapterIndex,
    int positionSeconds,
  ) {
    if (chapters.isEmpty) return '';

    int totalRemaining = 0;
    for (int i = currentChapterIndex; i < chapters.length; i++) {
      final chapterDuration =
          (chapters[i]['duration_seconds'] as num?)?.toInt() ?? 0;
      if (i == currentChapterIndex) {
        totalRemaining +=
            (chapterDuration - positionSeconds).clamp(0, chapterDuration);
      } else {
        totalRemaining += chapterDuration;
      }
    }

    if (totalRemaining <= 0) return '';

    final hours = totalRemaining ~/ 3600;
    final minutes = (totalRemaining % 3600) ~/ 60;

    if (hours > 0) {
      return '${FarsiUtils.toFarsiDigits(hours)}:${FarsiUtils.toFarsiDigits(minutes.toString().padLeft(2, '0'))}';
    }
    return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
  }
}
