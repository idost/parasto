import 'dart:ui';

import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html_reborn/flutter_html_reborn.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PagingTextHandler {
  final Function paginate;

  PagingTextHandler({required this.paginate});
}

/// Represents the text range for each paginated page
class PageRange {
  final int startOffset;
  final int endOffset;

  const PageRange(this.startOffset, this.endOffset);

  bool containsOffset(int offset) => offset >= startOffset && offset < endOffset;
}

/// Selection data for creating highlights
class TextSelectionData {
  final String selectedText;
  final int startOffset;
  final int endOffset;

  const TextSelectionData({
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
  });
}

class PagingWidget extends StatefulWidget {
  final String textContent;
  final String? innerHtmlContent;
  final String chapterTitle;
  final int totalChapters;
  final int starterPageIndex;
  final TextStyle style;
  final Function handlerCallback;
  final VoidCallback onTextTap;
  final Function(int, int) onPageFlip;
  final Function(int, int) onLastPage;
  final Widget? lastWidget;
  final bool isRightToLeft;

  // Highlight System Parameters
  final List<HighlightModel> highlights;
  final Color accentColor;
  final String? searchQuery;
  final Function(String text, int start, int end, String colorHex)? onHighlight;
  final Function(String text, int start, int end)? onAddNote;
  final Function(HighlightModel highlight)? onHighlightTap;
  final int chapterIndex;

  const PagingWidget(
    this.textContent,
    this.innerHtmlContent, {
    super.key,
    this.style = const TextStyle(color: Colors.black, fontSize: 30),
    required this.handlerCallback(PagingTextHandler handler),
    required this.onTextTap,
    required this.onPageFlip,
    required this.onLastPage,
    this.starterPageIndex = 0,
    required this.chapterTitle,
    required this.totalChapters,
    this.lastWidget,
    this.isRightToLeft = false,
    this.highlights = const [],
    this.accentColor = Colors.blue,
    this.searchQuery,
    this.onHighlight,
    this.onAddNote,
    this.onHighlightTap,
    this.chapterIndex = 0,
  });

  @override
  _PagingWidgetState createState() => _PagingWidgetState();
}

class _PagingWidgetState extends State<PagingWidget> {
  final List<String> _pageTexts = [];
  final List<PageRange> _pageRanges = [];
  List<Widget> pages = [];
  int _currentPageIndex = 0;
  Future<void> paginateFuture = Future.value(true);
  late RenderBox _initializedRenderBox;

  final _pageKey = GlobalKey();
  final _pageController = GlobalKey<PageFlipWidgetState>();

  @override
  void initState() {
    rePaginate();
    var handler = PagingTextHandler(paginate: rePaginate);
    widget.handlerCallback(handler);
    super.initState();
  }

  @override
  void didUpdateWidget(PagingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlights != widget.highlights ||
        oldWidget.searchQuery != widget.searchQuery) {
      _rebuildPageWidgets();
    }
  }

  rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final renderObject = context.findRenderObject();
        if (renderObject == null) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) rePaginate();
          });
          return;
        }
        setState(() {
          _initializedRenderBox = renderObject as RenderBox;
          paginateFuture = _paginate();
        });
      } catch (e) {
        debugPrint('COSMOS_EPUB: Error in rePaginate: $e');
      }
    });
  }

  int findLastHtmlTagIndex(String input) {
    RegExp regex = RegExp(r'<[^>]');
    Iterable<Match> matches = regex.allMatches(input);
    if (matches.isNotEmpty) {
      return matches.last.end;
    } else {
      return -1;
    }
  }

  Future<void> _paginate() async {
    final pageSize = _initializedRenderBox.size;
    _pageTexts.clear();
    _pageRanges.clear();

    final textDirection = RTLHelper.getTextDirection(widget.textContent);
    final textSpan = TextSpan(text: widget.textContent, style: widget.style);
    final textPainter = TextPainter(text: textSpan, textDirection: textDirection);
    textPainter.layout(minWidth: 0, maxWidth: pageSize.width);

    List<LineMetrics> lines = textPainter.computeLineMetrics();
    double currentPageBottom = pageSize.height;
    int currentPageStartIndex = 0;
    int currentPageEndIndex = 0;

    for (final line in lines) {
      final left = line.left;
      final top = line.baseline - line.ascent;
      final bottom = line.baseline + line.descent;
      var innerHtml = widget.innerHtmlContent;

      if (currentPageBottom < bottom) {
        currentPageEndIndex = textPainter
            .getPositionForOffset(Offset(left, top - (innerHtml != null ? 0 : 100.h)))
            .offset;

        var pageText = widget.textContent.substring(currentPageStartIndex, currentPageEndIndex);
        var index = findLastHtmlTagIndex(pageText) + currentPageStartIndex;

        if (index != -1) {
          int difference = currentPageEndIndex - index;
          if (difference < 4) {
            currentPageEndIndex = index - 2;
          }
          pageText = widget.textContent.substring(currentPageStartIndex, currentPageEndIndex);
        }

        _pageTexts.add(pageText);
        _pageRanges.add(PageRange(currentPageStartIndex, currentPageEndIndex));

        currentPageStartIndex = currentPageEndIndex;
        currentPageBottom = top + pageSize.height - (innerHtml != null ? 120.h : 150.h);
      }
    }

    final lastPageText = widget.textContent.substring(currentPageStartIndex);
    _pageTexts.add(lastPageText);
    _pageRanges.add(PageRange(currentPageStartIndex, widget.textContent.length));

    await _rebuildPageWidgets();
  }

  Future<void> _rebuildPageWidgets() async {
    List<Widget> newPages = [];
    for (int i = 0; i < _pageTexts.length; i++) {
      newPages.add(_buildPageWidget(i, _pageTexts[i]));
    }
    pages = newPages;
    if (mounted) setState(() {});
  }

  Widget _buildPageWidget(int pageIndex, String text) {
    final scrollController = ScrollController();
    final pageTextDirection = RTLHelper.getTextDirection(text);
    final pageRange = pageIndex < _pageRanges.length
        ? _pageRanges[pageIndex]
        : PageRange(0, text.length);

    if (widget.innerHtmlContent != null) {
      return InkWell(
        onTap: widget.onTextTap,
        child: Container(
          color: widget.style.backgroundColor,
          child: FadingEdgeScrollView.fromSingleChildScrollView(
            gradientFractionOnEnd: 0.2,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.h, top: 60.h, left: 10.w, right: 10.w),
                child: Directionality(
                  textDirection: pageTextDirection,
                  child: Html(
                    data: text,
                    style: {
                      "*": Style(
                        textAlign: TextAlign.justify,
                        fontSize: FontSize(widget.style.fontSize ?? 0),
                        fontFamily: widget.style.fontFamily,
                        color: widget.style.color,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _SelectablePageContent(
      text: text,
      pageRange: pageRange,
      style: widget.style,
      textDirection: pageTextDirection,
      highlights: widget.highlights,
      searchQuery: widget.searchQuery,
      accentColor: widget.accentColor,
      chapterIndex: widget.chapterIndex,
      onTap: widget.onTextTap,
      onHighlight: widget.onHighlight,
      onAddNote: widget.onAddNote,
      onHighlightTap: widget.onHighlightTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: paginateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CupertinoActivityIndicator(
              color: Theme.of(context).primaryColor,
              radius: 30.r,
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                key: _pageKey,
                child: PageFlipWidget(
                  key: _pageController,
                  initialIndex: widget.starterPageIndex != 0
                      ? (pages.isNotEmpty && widget.starterPageIndex < pages.length
                          ? widget.starterPageIndex
                          : 0)
                      : widget.starterPageIndex,
                  isRightSwipe: widget.isRightToLeft,
                  onTap: widget.onTextTap,
                  onPageFlip: (pageIndex) {
                    _currentPageIndex = pageIndex;
                    widget.onPageFlip(pageIndex, pages.length);
                    if (_currentPageIndex == pages.length - 1) {
                      widget.onLastPage(pageIndex, pages.length);
                    }
                  },
                  backgroundColor: widget.style.backgroundColor ?? Colors.white,
                  lastPage: widget.lastWidget,
                  children: pages,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// SELECTABLE PAGE CONTENT
// ============================================================================

class _SelectablePageContent extends StatefulWidget {
  final String text;
  final PageRange pageRange;
  final TextStyle style;
  final TextDirection textDirection;
  final List<HighlightModel> highlights;
  final String? searchQuery;
  final Color accentColor;
  final int chapterIndex;
  final VoidCallback onTap;
  final Function(String, int, int, String)? onHighlight;
  final Function(String, int, int)? onAddNote;
  final Function(HighlightModel)? onHighlightTap;

  const _SelectablePageContent({
    required this.text,
    required this.pageRange,
    required this.style,
    required this.textDirection,
    required this.highlights,
    this.searchQuery,
    required this.accentColor,
    required this.chapterIndex,
    required this.onTap,
    this.onHighlight,
    this.onAddNote,
    this.onHighlightTap,
  });

  @override
  State<_SelectablePageContent> createState() => _SelectablePageContentState();
}

class _SelectablePageContentState extends State<_SelectablePageContent> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<HighlightModel> get _pageHighlights {
    return widget.highlights.where((h) {
      return h.chapterIndex == widget.chapterIndex &&
          h.startOffset < widget.pageRange.endOffset &&
          h.endOffset > widget.pageRange.startOffset;
    }).toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));
  }

  TextSpan _buildHighlightedTextSpan() {
    final List<InlineSpan> spans = [];
    final pageStart = widget.pageRange.startOffset;
    final text = widget.text;
    final List<_HRange> ranges = [];

    // Use style WITHOUT backgroundColor to prevent white selection overlay on iOS
    // Background is handled by the outer Container
    final baseStyle = widget.style.copyWith(backgroundColor: null);

    for (final h in _pageHighlights) {
      final rs = (h.startOffset - pageStart).clamp(0, text.length);
      final re = (h.endOffset - pageStart).clamp(0, text.length);
      if (rs < re) {
        ranges.add(_HRange(rs, re, Color(HighlightColors.parseHex(h.colorHex)).withOpacity(0.4), h));
      }
    }

    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      final q = widget.searchQuery!.toLowerCase();
      final lt = text.toLowerCase();
      int si = 0;
      while (true) {
        final idx = lt.indexOf(q, si);
        if (idx == -1) break;
        ranges.add(_HRange(idx, idx + widget.searchQuery!.length, widget.accentColor.withOpacity(0.3), null));
        si = idx + 1;
      }
    }

    ranges.sort((a, b) => a.s.compareTo(b.s));
    int cur = 0;

    for (final r in ranges) {
      if (r.e <= cur) continue;
      final es = r.s < cur ? cur : r.s;
      if (es > cur) {
        spans.add(TextSpan(text: text.substring(cur, es), style: baseStyle));
      }
      final ht = text.substring(es, r.e);
      if (r.h != null) {
        spans.add(TextSpan(
          text: ht,
          style: baseStyle.copyWith(backgroundColor: r.c),
          recognizer: TapGestureRecognizer()..onTap = () => widget.onHighlightTap?.call(r.h!),
        ));
      } else {
        spans.add(TextSpan(text: ht, style: baseStyle.copyWith(backgroundColor: r.c)));
      }
      cur = r.e;
    }

    if (cur < text.length) {
      spans.add(TextSpan(text: text.substring(cur), style: baseStyle));
    }

    if (spans.isEmpty) return TextSpan(text: text, style: baseStyle);
    return TextSpan(children: spans);
  }

  TextSelectionData? _getSelectionData(TextSelection sel) {
    if (sel.isCollapsed) return null;
    final s = sel.start;
    final e = sel.end;
    if (s < 0 || e > widget.text.length || s >= e) return null;
    return TextSelectionData(
      selectedText: widget.text.substring(s, e),
      startOffset: widget.pageRange.startOffset + s,
      endOffset: widget.pageRange.startOffset + e,
    );
  }

  Widget _buildToolbar(BuildContext ctx, EditableTextState state) {
    final sel = state.textEditingValue.selection;
    final data = _getSelectionData(sel);
    if (data == null) return const SizedBox.shrink();

    return _AppleToolbar(
      accentColor: widget.accentColor,
      bgColor: widget.style.backgroundColor ?? Colors.white,
      textColor: widget.style.color ?? Colors.black,
      onHighlight: (c) {
        widget.onHighlight?.call(data.selectedText, data.startOffset, data.endOffset, c);
        state.hideToolbar();
        _focusNode.unfocus();
      },
      onNote: () {
        widget.onAddNote?.call(data.selectedText, data.startOffset, data.endOffset);
        state.hideToolbar();
        _focusNode.unfocus();
      },
      onCopy: () {
        Clipboard.setData(ClipboardData(text: data.selectedText));
        state.hideToolbar();
        _focusNode.unfocus();
      },
      anchor: state.contextMenuAnchors.primaryAnchor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = ScrollController();
    final bgColor = widget.style.backgroundColor ?? Colors.white;

    // Create a modified style WITHOUT backgroundColor to prevent selection overlay issues
    // The background is handled by the outer Container instead
    final textStyleWithoutBg = widget.style.copyWith(backgroundColor: null);

    return Theme(
      // Set proper selection colors at the top level to prevent white overlay on iOS
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: widget.accentColor.withOpacity(0.3),
          cursorColor: widget.accentColor,
          selectionHandleColor: widget.accentColor,
        ),
      ),
      child: Container(
        color: bgColor,
        child: SingleChildScrollView(
          controller: sc,
          physics: const BouncingScrollPhysics(),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.h, top: 60.h, left: 10.w, right: 10.w),
              child: Directionality(
                textDirection: widget.textDirection,
                child: SelectableText.rich(
                  _buildHighlightedTextSpan(),
                  focusNode: _focusNode,
                  textAlign: TextAlign.justify,
                  textDirection: widget.textDirection,
                  style: textStyleWithoutBg,
                  contextMenuBuilder: _buildToolbar,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HRange {
  final int s, e;
  final Color c;
  final HighlightModel? h;
  _HRange(this.s, this.e, this.c, this.h);
}

// ============================================================================
// APPLE BOOKS-STYLE TOOLBAR
// ============================================================================

class _AppleToolbar extends StatelessWidget {
  final Color accentColor, bgColor, textColor;
  final Function(String) onHighlight;
  final VoidCallback onNote, onCopy;
  final Offset anchor;

  const _AppleToolbar({
    required this.accentColor,
    required this.bgColor,
    required this.textColor,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
    required this.anchor,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final tw = 280.w;
    double left = (anchor.dx - tw / 2).clamp(16.w, sw - tw - 16.w);
    double top = anchor.dy - 80.h;
    if (top < 100.h) top = anchor.dy + 20.h;

    final isDark = bgColor.computeLuminance() < 0.5;
    final tbBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final tbText = isDark ? Colors.white : Colors.black87;

    return Positioned(
      left: left,
      top: top,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        builder: (_, v, child) => Transform.scale(
          scale: 0.8 + 0.2 * v,
          child: Opacity(opacity: v, child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: tbBg.withOpacity(0.98),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _colorBtn(HighlightColors.yellow),
                      SizedBox(width: 8.w),
                      _colorBtn(HighlightColors.green),
                      SizedBox(width: 8.w),
                      _colorBtn(HighlightColors.blue),
                      SizedBox(width: 8.w),
                      _colorBtn(HighlightColors.pink),
                      SizedBox(width: 8.w),
                      _colorBtn(HighlightColors.orange),
                    ],
                  ),
                ),
                Container(height: 1, color: tbText.withOpacity(0.1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionBtn(Icons.copy_rounded, 'کپی', onCopy, tbText),
                      Container(width: 1, height: 24.h, color: tbText.withOpacity(0.1), margin: EdgeInsets.symmetric(horizontal: 4.w)),
                      _actionBtn(Icons.note_add_rounded, 'یادداشت', onNote, tbText),
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

  Widget _colorBtn(String hex) {
    final c = Color(HighlightColors.parseHex(hex));
    return GestureDetector(
      onTap: () => onHighlight(hex),
      child: Container(
        width: 32.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, Color txtColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18.sp, color: txtColor.withOpacity(0.8)),
            SizedBox(width: 6.w),
            Text(label, style: TextStyle(fontSize: 13.sp, color: txtColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
