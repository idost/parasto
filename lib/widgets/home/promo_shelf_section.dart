import 'package:flutter/material.dart';
import 'package:myna/screens/listener/shelf_detail_screen.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/widgets/section_header.dart';
import 'package:myna/widgets/home/content_cards.dart';

/// Section displaying a curated promotional shelf with audiobooks.
class PromoShelfSection extends StatelessWidget {
  final Map<String, dynamic> shelf;

  const PromoShelfSection({super.key, required this.shelf});

  @override
  Widget build(BuildContext context) {
    final audiobooks = shelf['audiobooks'] as List<dynamic>? ?? [];
    if (audiobooks.isEmpty) return const SizedBox.shrink();

    final shelfTitle = (shelf['title_fa'] as String?) ?? '';
    final shelfId = shelf['id'] as int;

    final allBookIds =
        audiobooks.map((b) => (b as Map<String, dynamic>)['id'] as int).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.localize(shelfTitle),
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ShelfDetailScreen(
                  shelfId: shelfId,
                  shelfTitle: shelfTitle,
                ),
              ),
            );
          },
        ),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: audiobooks.length,
            itemBuilder: (context, index) {
              final book = audiobooks[index] as Map<String, dynamic>;
              return AudiobookCard(
                key: ValueKey(book['id']),
                book: book,
                showBadge: true,
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
