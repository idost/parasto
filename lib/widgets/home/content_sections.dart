import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/section_header.dart';
import 'package:myna/widgets/home/content_cards.dart';
/// Section displaying audiobooks in a horizontal list.
class AudiobookSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> books;
  final VoidCallback? onSeeAll;
  final bool showBadges;

  const AudiobookSection({
    super.key,
    required this.title,
    required this.books,
    this.onSeeAll,
    this.showBadges = false,
  });

  @override
  Widget build(BuildContext context) {
    final allBookIds = books.map((b) => b['id'] as int).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return AudiobookCard(
                key: ValueKey(book['id']),
                book: book,
                showBadge: showBadges,
                allBookIds: allBookIds,
                currentIndex: index,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section for mixed content types (audiobooks, podcasts, ebooks).
/// Shows content type badges on each item.
class MixedContentSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;
  final bool showBadges;

  const MixedContentSection({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.showBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    final audiobookItems =
        items.where((i) => i['content_type'] != 'ebook').toList();
    final audiobookIds = audiobookItems.map((b) => b['id'] as int).toList();
    final ebookItems = items.where((i) => i['content_type'] == 'ebook').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final contentType = item['content_type'] as String?;

              if (contentType == 'ebook') {
                final ebookIndex =
                    ebookItems.indexWhere((e) => e['id'] == item['id']);
                return EbookCard(
                  key: ValueKey('ebook_${item['id']}'),
                  ebook: item,
                  showBadge: showBadges,
                  allEbooks: ebookItems,
                  currentIndex: ebookIndex >= 0 ? ebookIndex : null,
                );
              }

              final audiobookIndex =
                  audiobookItems.indexWhere((a) => a['id'] == item['id']);
              return AudiobookCard(
                key: ValueKey(item['id']),
                book: item,
                showBadge: showBadges,
                allBookIds: audiobookIds,
                currentIndex: audiobookIndex >= 0 ? audiobookIndex : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section for music content with square covers.
class MusicSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;

  const MusicSection({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final allMusicIds = items.map((m) => m['id'] as int).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightSquare,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return MusicCard(
                key: ValueKey(item['id']),
                music: item,
                allMusicIds: allMusicIds,
                currentIndex: index,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section for ebook content with 2:3 covers and badge.
class EbookSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;

  const EbookSection({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return EbookCard(
                key: ValueKey('ebook_section_${item['id']}'),
                ebook: item,
                showBadge: true,
                allEbooks: items,
                currentIndex: index,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section for podcast content with 2:3 covers and badge.
class PodcastSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;

  const PodcastSection({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final allPodcastIds = items.map((p) => p['id'] as int).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightSquare,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return AudiobookCard(
                key: ValueKey('podcast_section_${item['id']}'),
                book: item,
                showBadge: true,
                allBookIds: allPodcastIds,
                currentIndex: index,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Wrapper with subtle gradient background for featured/promoted sections.
/// Creates visual hierarchy to distinguish important content.
class FeaturedSectionWrapper extends StatelessWidget {
  final Widget child;

  const FeaturedSectionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.04),
            AppColors.secondary.withValues(alpha: 0.02),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
