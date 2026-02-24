import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/ebook_detail_screen.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/widgets/content_type_micro_label.dart';
import 'package:myna/widgets/content_card_base.dart';
import 'package:myna/widgets/swipeable_audiobook_detail.dart';

/// Audiobook card widget for displaying audiobook items in lists.
/// Used in audiobook sections, promo shelves, and mixed content sections.
class AudiobookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool showBadge;
  final List<int>? allBookIds;
  final int? currentIndex;

  const AudiobookCard({
    super.key,
    required this.book,
    this.showBadge = false,
    this.allBookIds,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final title = (book['title_fa'] as String?) ?? '';
    final isMusic = (book['is_music'] as bool?) ?? false;
    final isPodcast = (book['is_podcast'] as bool?) ?? false;
    final isArticle = (book['is_article'] as bool?) ?? false;
    final bool isSquareCover = isMusic || isPodcast || isArticle;
    final double cardCoverHeight = isSquareCover
        ? AppDimensions.musicCardCoverHeight  // 1:1 square
        : AppDimensions.cardCoverHeight;      // 2:3 portrait
    final isParastoBrand = (book['is_parasto_brand'] as bool?) ?? false;

    String narratorRaw = '';
    if (isMusic) {
      final musicMeta = book['music_metadata'] as Map<String, dynamic>?;
      narratorRaw = (musicMeta?['artist_name'] as String?) ?? '';
    } else {
      final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
      narratorRaw = (bookMeta?['narrator_name'] as String?) ?? '';
    }

    final narrator = isParastoBrand ? AppStrings.appName : narratorRaw;
    final author = (book['author_fa'] as String?) ??
        (book['author_en'] as String?) ??
        '';
    final isFree = book['is_free'] == true;
    final price = (book['price_toman'] as num?) ?? 0;
    final coverUrl = book['cover_url'] as String?;

    final subtitleText = AppStrings.localize(isMusic
        ? (isParastoBrand
            ? AppStrings.appName
            : (author.isNotEmpty
                ? author
                : (narratorRaw.isNotEmpty ? narratorRaw : AppStrings.musicLabel)))
        : (author.isNotEmpty ? author : narrator));

    return ContentCardBase(
      coverUrl: coverUrl,
      coverHeight: cardCoverHeight,
      heroTag: 'cover_${book['id']}',
      title: AppStrings.localize(title),
      subtitle: subtitleText,
      placeholderIcon:
          isMusic ? Icons.music_note_rounded : Icons.headphones_rounded,
      microLabel: ContentTypeMicroLabel.fromData(book),
      bottomWidget: PriceBadge(
        isFree: isFree,
        price: price,
      ),
      onTap: () {
        if (allBookIds != null && allBookIds!.length > 1 && currentIndex != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SwipeableAudiobookDetail(
                audiobookIds: allBookIds!,
                initialIndex: currentIndex!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
            ),
          );
        }
      },
    );
  }
}

/// Music card with 1:1 aspect ratio cover.
class MusicCard extends StatelessWidget {
  final Map<String, dynamic> music;
  final List<int>? allMusicIds;
  final int? currentIndex;

  const MusicCard({
    super.key,
    required this.music,
    this.allMusicIds,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final title = (music['title_fa'] as String?) ?? '';
    final coverUrl = music['cover_url'] as String?;

    final musicMeta = music['music_metadata'] as Map<String, dynamic>?;
    final artist = (musicMeta?['artist_name'] as String?) ??
        (music['author_fa'] as String?) ??
        '';

    return ContentCardBase(
      coverUrl: coverUrl,
      coverHeight: AppDimensions.musicCardCoverHeight,
      heroTag: 'cover_${music['id']}',
      title: AppStrings.localize(title),
      subtitle: artist.isNotEmpty ? AppStrings.localize(artist) : null,
      placeholderIcon: Icons.music_note_rounded,
      microLabel: ContentTypeMicroLabel.fromData(music),
      onTap: () {
        if (allMusicIds != null && allMusicIds!.length > 1 && currentIndex != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SwipeableAudiobookDetail(
                audiobookIds: allMusicIds!,
                initialIndex: currentIndex!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AudiobookDetailScreen(audiobookId: music['id'] as int),
            ),
          );
        }
      },
    );
  }
}

/// Ebook card for mixed content sections.
class EbookCard extends StatelessWidget {
  final Map<String, dynamic> ebook;
  final bool showBadge;
  final List<Map<String, dynamic>>? allEbooks;
  final int? currentIndex;

  const EbookCard({
    super.key,
    required this.ebook,
    this.showBadge = true,
    this.allEbooks,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final title = (ebook['title_fa'] as String?) ?? '';
    final author = (ebook['author_fa'] as String?) ?? '';
    final coverUrl = ebook['cover_url'] as String?;
    final isFree = ebook['is_free'] == true;

    return ContentCardBase(
      coverUrl: coverUrl,
      coverHeight: AppDimensions.cardCoverHeight,
      heroTag: 'ebook_cover_${ebook['id']}',
      title: AppStrings.localize(title),
      subtitle: AppStrings.localize(author),
      placeholderIcon: Icons.menu_book_rounded,
      microLabel: ContentTypeMicroLabel.fromData(ebook),
      bottomWidget: PriceBadge(
        isFree: isFree,
        customText: isFree ? null : 'کتاب',
      ),
      onTap: () {
        if (allEbooks != null && allEbooks!.length > 1 && currentIndex != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SwipeableEbookDetail(
                ebooks: allEbooks!,
                initialIndex: currentIndex!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EbookDetailScreen(ebook: ebook),
            ),
          );
        }
      },
    );
  }
}
