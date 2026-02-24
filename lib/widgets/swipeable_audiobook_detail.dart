import 'package:flutter/material.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';

/// Displays audiobook detail with left/right swipe navigation between books.
/// Wraps [AudiobookDetailScreen] in a [PageView] so the user can swipe
/// to adjacent items in a list (e.g. featured shelf, search results).
class SwipeableAudiobookDetail extends StatefulWidget {
  const SwipeableAudiobookDetail({
    super.key,
    required this.audiobookIds,
    required this.initialIndex,
  });

  final List<int> audiobookIds;
  final int initialIndex;

  @override
  State<SwipeableAudiobookDetail> createState() =>
      _SwipeableAudiobookDetailState();
}

class _SwipeableAudiobookDetailState extends State<SwipeableAudiobookDetail> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.audiobookIds.length,
      itemBuilder: (context, index) => AudiobookDetailScreen(
        audiobookId: widget.audiobookIds[index],
      ),
    );
  }
}
