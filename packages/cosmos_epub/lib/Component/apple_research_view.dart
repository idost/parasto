import 'package:flutter/material.dart';
import '../Model/highlight_model.dart';
import 'theme_colors.dart';

/// Apple Books-style Notes & Highlights view
/// Clean, minimal design with clear visual hierarchy
class AppleResearchView extends StatefulWidget {
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final String fontFamily;
  final List<HighlightModel> highlights;
  final List<Map<String, dynamic>> bookmarks;
  final List<String> chapterNames;
  final Function(HighlightModel) onHighlightTap;
  final Function(HighlightModel) onHighlightEdit;
  final Function(HighlightModel) onHighlightDelete;
  final Function(int chapterIndex, int pageIndex) onBookmarkTap;
  final Function(int chapterIndex, int pageIndex) onBookmarkDelete;

  const AppleResearchView({
    super.key,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    required this.fontFamily,
    required this.highlights,
    required this.bookmarks,
    required this.chapterNames,
    required this.onHighlightTap,
    required this.onHighlightEdit,
    required this.onHighlightDelete,
    required this.onBookmarkTap,
    required this.onBookmarkDelete,
  });

  @override
  State<AppleResearchView> createState() => _AppleResearchViewState();
}

class _AppleResearchViewState extends State<AppleResearchView> {
  int _selectedTab = 0; // 0 = Notes, 1 = Bookmarks

  @override
  Widget build(BuildContext context) {
    final isDark = widget.backgroundColor.computeLuminance() < 0.5;
    final sheetBg = isDark ? cParastoSurface : const Color(0xFFF2F2F7);
    final cardBg = isDark ? cParastoSurfaceLight : Colors.white;
    // Improved visibility: higher alpha values for better contrast
    final subtleText = widget.textColor.withAlpha(178); // Was 128, now 70%
    final dividerColor = widget.textColor.withAlpha(38); // Was 25, now 15%

    // Count items
    final notesCount = widget.highlights.where((h) => h.hasNote).length;
    final highlightsCount = widget.highlights.where((h) => !h.hasNote).length;
    final bookmarksCount = widget.bookmarks.length;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Drag handle - improved visibility
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: widget.textColor.withAlpha(89), // Was 51, now 35%
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const SizedBox(width: 44), // Balance for close button
                Expanded(
                  child: Text(
                    'یادداشت‌ها',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: widget.textColor,
                      fontFamily: widget.fontFamily,
                      package: 'cosmos_epub',
                    ),
                  ),
                ),
                // Close button with better visibility
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(31)
                          : Colors.black.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.textColor.withAlpha(76),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: widget.textColor.withAlpha(230),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Segmented control - Apple style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? cParastoSurfaceElevated : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildSegment(
                    'یادداشت‌ها و هایلایت',
                    0,
                    notesCount + highlightsCount,
                    isDark,
                  ),
                  _buildSegment(
                    'نشانه‌ها',
                    1,
                    bookmarksCount,
                    isDark,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _selectedTab == 0
                ? _buildHighlightsList(cardBg, subtleText, dividerColor, isDark)
                : _buildBookmarksList(cardBg, subtleText, dividerColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, int index, int count, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? cParastoSurfaceElevated : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                // Improved visibility: higher alpha for unselected state
                color: isSelected
                    ? widget.textColor
                    : widget.textColor.withAlpha(204), // Was 153, now 80%
                fontFamily: widget.fontFamily,
                package: 'cosmos_epub',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsList(
      Color cardBg, Color subtleText, Color dividerColor, bool isDark) {
    if (widget.highlights.isEmpty) {
      return _buildEmptyState(
        Icons.format_quote_rounded,
        'هنوز یادداشت یا هایلایتی ندارید',
        'متن را انتخاب کنید و هایلایت بزنید',
      );
    }

    // Group by chapter
    final grouped = <int, List<HighlightModel>>{};
    for (final h in widget.highlights) {
      grouped.putIfAbsent(h.chapterIndex, () => []);
      grouped[h.chapterIndex]!.add(h);
    }

    final sortedChapters = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedChapters.length,
      itemBuilder: (context, groupIndex) {
        final chapterIndex = sortedChapters[groupIndex];
        final items = grouped[chapterIndex]!;
        final chapterName = chapterIndex < widget.chapterNames.length
            ? widget.chapterNames[chapterIndex]
            : 'فصل ${chapterIndex + 1}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter header
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, right: 4),
              child: Text(
                chapterName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subtleText,
                  fontFamily: widget.fontFamily,
                  package: 'cosmos_epub',
                ),
              ),
            ),
            // Items
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final highlight = entry.value;
                  final isLast = index == items.length - 1;
                  return _buildHighlightItem(
                      highlight, cardBg, subtleText, dividerColor, isLast);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightItem(HighlightModel highlight, Color cardBg,
      Color subtleText, Color dividerColor, bool isLast) {
    final highlightColor = Color(HighlightColors.parseHex(highlight.colorHex));

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onHighlightTap(highlight);
      },
      onLongPress: () => _showHighlightActions(highlight),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color indicator
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Highlighted text
                  Text(
                    highlight.highlightedText.length > 100
                        ? '${highlight.highlightedText.substring(0, 100)}...'
                        : highlight.highlightedText,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.textColor,
                      height: 1.4,
                      fontFamily: widget.fontFamily,
                      package: 'cosmos_epub',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Note (if exists)
                  if (highlight.hasNote) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: highlightColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: highlightColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              highlight.noteText!,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.textColor.withAlpha(204),
                                height: 1.4,
                                fontFamily: widget.fontFamily,
                                package: 'cosmos_epub',
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Chevron - improved visibility
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: widget.textColor.withAlpha(153), // Better contrast
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarksList(
      Color cardBg, Color subtleText, Color dividerColor, bool isDark) {
    if (widget.bookmarks.isEmpty) {
      return _buildEmptyState(
        Icons.bookmark_outline_rounded,
        'هنوز نشانه‌ای ندارید',
        'برای نشانه‌گذاری از منوی پایین استفاده کنید',
      );
    }

    // Group by chapter
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final b in widget.bookmarks) {
      final chapterIndex = b['chapter'] ?? 0;
      grouped.putIfAbsent(chapterIndex, () => []);
      grouped[chapterIndex]!.add(b);
    }

    final sortedChapters = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedChapters.length,
      itemBuilder: (context, groupIndex) {
        final chapterIndex = sortedChapters[groupIndex];
        final items = grouped[chapterIndex]!;
        final chapterName = chapterIndex < widget.chapterNames.length
            ? widget.chapterNames[chapterIndex]
            : 'فصل ${chapterIndex + 1}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter header
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, right: 4),
              child: Text(
                chapterName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subtleText,
                  fontFamily: widget.fontFamily,
                  package: 'cosmos_epub',
                ),
              ),
            ),
            // Items
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final bookmark = entry.value;
                  final isLast = index == items.length - 1;
                  return _buildBookmarkItem(
                      bookmark, chapterIndex, subtleText, dividerColor, isLast);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBookmarkItem(Map<String, dynamic> bookmark, int chapterIndex,
      Color subtleText, Color dividerColor, bool isLast) {
    final pageIndex = bookmark['page'] ?? 0;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onBookmarkTap(chapterIndex, pageIndex);
      },
      onLongPress: () => _showBookmarkActions(chapterIndex, pageIndex),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            // Bookmark icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.bookmark_rounded,
                size: 18,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Text(
                'صفحه ${pageIndex + 1}',
                style: TextStyle(
                  fontSize: 15,
                  color: widget.textColor,
                  fontFamily: widget.fontFamily,
                  package: 'cosmos_epub',
                ),
              ),
            ),
            // Chevron - improved visibility
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: widget.textColor.withAlpha(153), // Better contrast
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            // Improved visibility: was 51, now 102 (40%)
            color: widget.textColor.withAlpha(102),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              // Improved visibility: was 128, now 178 (70%)
              color: widget.textColor.withAlpha(178),
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              // Improved visibility: was 102, now 153 (60%)
              color: widget.textColor.withAlpha(153),
              fontFamily: widget.fontFamily,
              package: 'cosmos_epub',
            ),
          ),
        ],
      ),
    );
  }

  void _showHighlightActions(HighlightModel highlight) {
    final isDark = widget.backgroundColor.computeLuminance() < 0.5;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? cParastoSurfaceLight : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_rounded, color: widget.accentColor),
                title: Text(
                  highlight.hasNote ? 'ویرایش یادداشت' : 'افزودن یادداشت',
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    package: 'cosmos_epub',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onHighlightEdit(highlight);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: widget.fontFamily,
                    package: 'cosmos_epub',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onHighlightDelete(highlight);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookmarkActions(int chapterIndex, int pageIndex) {
    final isDark = widget.backgroundColor.computeLuminance() < 0.5;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? cParastoSurfaceLight : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: Text(
                  'حذف نشانه',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: widget.fontFamily,
                    package: 'cosmos_epub',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onBookmarkDelete(chapterIndex, pageIndex);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show the Apple Research View as a modal bottom sheet
void showAppleResearchView({
  required BuildContext context,
  required Color backgroundColor,
  required Color textColor,
  required Color accentColor,
  required String fontFamily,
  required List<HighlightModel> highlights,
  required List<Map<String, dynamic>> bookmarks,
  required List<String> chapterNames,
  required Function(HighlightModel) onHighlightTap,
  required Function(HighlightModel) onHighlightEdit,
  required Function(HighlightModel) onHighlightDelete,
  required Function(int chapterIndex, int pageIndex) onBookmarkTap,
  required Function(int chapterIndex, int pageIndex) onBookmarkDelete,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => AppleResearchView(
          backgroundColor: backgroundColor,
          textColor: textColor,
          accentColor: accentColor,
          fontFamily: fontFamily,
          highlights: highlights,
          bookmarks: bookmarks,
          chapterNames: chapterNames,
          onHighlightTap: onHighlightTap,
          onHighlightEdit: onHighlightEdit,
          onHighlightDelete: onHighlightDelete,
          onBookmarkTap: onBookmarkTap,
          onBookmarkDelete: onBookmarkDelete,
        ),
      ),
    ),
  );
}
