import 'package:cosmos_epub/Helpers/context_extensions.dart';
import 'package:cosmos_epub/Helpers/farsi_helper.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Helpers/highlights_manager.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'Component/constants.dart';
import 'Component/highlight_popup.dart';
import 'Component/theme_colors.dart';
import 'Helpers/chapters.dart';
import 'Helpers/custom_toast.dart';
import 'Helpers/pagination.dart';
import 'Helpers/progress_singleton.dart';
import 'Model/chapter_model.dart';

///TODO: Change Future to more controllable timer to control show/hide elements
///  BUG-1: https://github.com/Mamasodikov/cosmos_epub/issues/2
///- Add sub chapters support
///- Add image support
///- Add text style attributes / word-break support

late BookProgressSingleton bookProgress;

const double DESIGN_WIDTH = 375;
const double DESIGN_HEIGHT = 812;

/// Default font for Parasto EPUB reader - Abar (licensed Farsi font)
String selectedFont = 'Abar';

/// Available fonts for EPUB reader
/// Abar is first (Parasto primary), Vazirmatn is fallback
List<String> fontNames = [
  "Abar",       // Parasto primary - licensed premium Farsi font
  "Vazirmatn",  // Fallback - free open-source Farsi font
  "Alegreya",
  "Amazon Ember",
  "Atkinson Hyperlegible",
  "Bitter Pro",
  "Bookerly",
  "Droid Sans",
  "EB Garamond",
  "Gentium Book Plus",
  "Halant",
  "IBM Plex Sans",
  "LinLibertine",
  "Literata",
  "Lora",
  "Ubuntu"
];

/// Line spacing options (height multiplier)
const List<double> lineSpacingOptions = [1.0, 1.25, 1.5, 2.0];
double selectedLineSpacing = 1.5; // Default line spacing

Color backColor = cParastoBackground;  // Default to Parasto theme
Color fontColor = cParastoTextPrimary;
int staticThemeId = 6;  // Default to Parasto theme

// ignore: must_be_immutable
class ShowEpub extends StatefulWidget {
  EpubBook epubBook;
  bool shouldOpenDrawer;
  int starterChapter;
  final String bookId;
  final String chapterListTitle;
  final Function(int currentPage, int totalPages)? onPageFlip;
  final Function(int lastPageIndex)? onLastPage;
  final Color accentColor;

  /// Callback for syncing highlights to cloud (Supabase)
  /// Called whenever a highlight is added, updated, or deleted
  final Future<void> Function(HighlightModel highlight, SyncOperation operation)? onHighlightSync;

  ShowEpub({
    super.key,
    required this.epubBook,
    required this.accentColor,
    this.starterChapter = 0,
    this.shouldOpenDrawer = false,
    required this.bookId,
    required this.chapterListTitle,
    this.onPageFlip,
    this.onLastPage,
    this.onHighlightSync,
  });

  @override
  State<StatefulWidget> createState() => ShowEpubState();
}

class ShowEpubState extends State<ShowEpub> {
  String htmlContent = '';
  String? innerHtmlContent;
  String textContent = '';
  // Removed showBrightnessWidget - brightness is now in the menu
  final controller = ScrollController();
  Future<void> loadChapterFuture = Future.value(true);
  List<LocalChapterModel> chaptersList = [];
  double _fontSizeProgress = 17.0;
  double _fontSize = 17.0;
  TextDirection currentTextDirection = TextDirection.ltr;

  late EpubBook epubBook;
  late String bookId;
  String bookTitle = '';
  String chapterTitle = '';
  double brightnessLevel = 0.5;

  // late Map<String, String> allFonts;

  // Initialize with the first font in the list
  late String selectedTextStyle;

  bool showHeader = false; // Minimalist mode: menu icon only, no header/footer by default
  bool isLastPage = false;

  // Apple Books-style: overlay visibility (tap to show/hide)
  bool _showOverlay = false;
  bool _showMenuPanel = false; // Secondary menu panel (Contents, Search, Settings)
  int lastSwipe = 0;
  int prevSwipe = 0;
  bool showPrevious = false;
  bool showNext = false;
  var dropDownFontItems;

  // Page progress tracking for visual indicator
  int _currentPageInChapter = 0;
  int _totalPagesInChapter = 1;

  // Line spacing (height multiplier for text)
  double _lineSpacing = 1.5;

  // Overall book progress percentage
  int get _overallProgressPercent {
    if (chaptersList.isEmpty) return 0;
    final currentChapter = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final totalChapters = chaptersList.length;
    if (totalChapters == 0) return 0;
    // Calculate based on chapter position + page position within chapter
    final chapterProgress = currentChapter / totalChapters;
    final pageProgress = _totalPagesInChapter > 0
        ? (_currentPageInChapter / _totalPagesInChapter) / totalChapters
        : 0;
    return ((chapterProgress + pageProgress) * 100).round().clamp(0, 100);
  }

  GetStorage gs = GetStorage();

  PagingTextHandler controllerPaging = PagingTextHandler(
    paginate: () {},
  );

  // Bookmark state - simple local bookmarks list (chapter + page)
  List<Map<String, int>> _bookmarks = [];
  bool get _isCurrentPageBookmarked {
    final currentChapter = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    return _bookmarks.any((b) =>
        b['chapter'] == currentChapter && b['page'] == _currentPageInChapter);
  }

  // Search state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchHighlightQuery; // Query to highlight when navigating from search

  // Highlights and notes state
  final HighlightsManager _highlightsManager = HighlightsManager();
  String _selectedHighlightColor = HighlightColors.yellow; // Default color

  @override
  void initState() {
    try {
      // ignore: avoid_print
      print('[COSMOS_EPUB] ShowEpub.initState() called');
      // ignore: avoid_print
      print('[COSMOS_EPUB] bookId: ${widget.bookId}');
      // ignore: avoid_print
      print('[COSMOS_EPUB] epubBook title: ${widget.epubBook.Title}');
      debugPrint('COSMOS_EPUB: ShowEpub.initState() called');
      debugPrint('COSMOS_EPUB: bookId: ${widget.bookId}');
      debugPrint('COSMOS_EPUB: epubBook title: ${widget.epubBook.Title}');
      debugPrint('COSMOS_EPUB: starterChapter: ${widget.starterChapter}');

      loadThemeSettings();
      _loadBookmarks();

      // Wire up sync callback for cloud sync
      if (widget.onHighlightSync != null) {
        _highlightsManager.onSyncRequired = widget.onHighlightSync;
      }

      bookId = widget.bookId;
      epubBook = widget.epubBook;
      // allFonts = GoogleFonts.asMap().cast<String, String>();
      // fontNames = allFonts.keys.toList();
      // selectedTextStyle = GoogleFonts.getFont(selectedFont).fontFamily!;
      selectedTextStyle =
          fontNames.where((element) => element == selectedFont).first;

      debugPrint('COSMOS_EPUB: About to call getTitleFromXhtml()');
      getTitleFromXhtml();
      debugPrint('COSMOS_EPUB: About to call reLoadChapter()');
      reLoadChapter(init: true);
      // ignore: avoid_print
      print('[COSMOS_EPUB] ShowEpub.initState() complete');
      debugPrint('COSMOS_EPUB: ShowEpub.initState() complete');
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[COSMOS_EPUB] ERROR in ShowEpub.initState(): $e');
      // ignore: avoid_print
      print('[COSMOS_EPUB] Stack trace: $stackTrace');
    }

    super.initState();
  }

  loadThemeSettings() {
    selectedFont = gs.read(libFont) ?? selectedFont;
    var themeId = gs.read(libTheme) ?? staticThemeId;
    updateTheme(themeId, isInit: true);
    _fontSize = gs.read(libFontSize) ?? _fontSize;
    _fontSizeProgress = _fontSize;
    _lineSpacing = gs.read(libLineSpacing) ?? _lineSpacing;
  }

  /// Load bookmarks from local storage
  void _loadBookmarks() {
    final stored = gs.read<List?>('bookmarks_${widget.bookId}');
    if (stored != null) {
      _bookmarks = stored.map((e) => Map<String, int>.from(e as Map)).toList();
    }
  }

  /// Save bookmarks to local storage
  void _saveBookmarks() {
    gs.write('bookmarks_${widget.bookId}', _bookmarks);
  }


  /// Show dialog for adding a note to selected text
  void _showAddNoteDialog(String text, int start, int end, int chapterIndex) {
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'یادداشت',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
              ),
              SizedBox(height: 12.h),
              // Show selected text preview
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.h),
                decoration: BoxDecoration(
                  color: fontColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: (widget.accentColor ?? Colors.blue).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  text.length > 100 ? '${text.substring(0, 100)}...' : text,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: fontColor.withOpacity(0.8),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 16.h),
              // Note input
              TextField(
                controller: noteController,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                autofocus: true,
                style: TextStyle(
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
                decoration: InputDecoration(
                  hintText: 'یادداشت خود را اینجا بنویسید…',
                  hintStyle: TextStyle(
                    color: fontColor.withOpacity(0.4),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                  filled: true,
                  fillColor: fontColor.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: widget.accentColor ?? Colors.blue,
                      width: 1,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'لغو',
                        style: TextStyle(
                          color: fontColor.withOpacity(0.5),
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final noteText = noteController.text.trim();
                        if (noteText.isEmpty) {
                          CustomToast.showToast('لطفاً یادداشت خود را بنویسید');
                          return;
                        }
                        Navigator.pop(context);
                        // Create highlight with note
                        _saveHighlightWithNote(
                          text, start, end, chapterIndex,
                          HighlightColors.yellow, // Default yellow for notes
                          noteText,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'ذخیره',
                        style: TextStyle(
                          color: backColor,
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Create a highlight with an attached note (internal helper)
  void _saveHighlightWithNote(String text, int start, int end, int chapterIndex, String colorHex, String noteText) async {
    final highlight = HighlightModel(
      id: HighlightModel.generateId(),
      bookId: widget.bookId,
      chapterIndex: chapterIndex,
      startOffset: start,
      endOffset: end,
      highlightedText: text,
      anchorText: HighlightsManager.generateAnchorText(textContent, start, end),
      colorHex: colorHex,
      noteText: noteText,
      createdAt: DateTime.now(),
    );

    await _highlightsManager.addHighlight(highlight);
    // Highlights loading disabled
    controllerPaging.paginate(); // Re-render with highlight
    updateUI();
    CustomToast.showToast('یادداشت ذخیره شد');
  }

  /// Show color picker for new highlight
  void _showHighlightColorPicker(String text, int start, int end, int chapterIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.all(20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رنگ هایلایت را انتخاب کنید',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
              ),
              SizedBox(height: 16.h),
              // Color options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: HighlightColors.all.map((colorHex) {
                  final color = Color(HighlightColors.parseHex(colorHex));
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _createHighlight(text, start, end, chapterIndex, colorHex);
                    },
                    child: Container(
                      width: 44.h,
                      height: 44.h,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: fontColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16.h),
              // Preview text
              Container(
                padding: EdgeInsets.all(12.h),
                decoration: BoxDecoration(
                  color: fontColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  text.length > 100 ? '${text.substring(0, 100)}...' : text,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: fontColor.withOpacity(0.7),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 16.h),
              // Cancel button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'انصراف',
                    style: TextStyle(
                      color: fontColor.withOpacity(0.5),
                      fontFamily: selectedTextStyle,
                      package: 'cosmos_epub',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Create a new highlight
  void _createHighlight(String text, int start, int end, int chapterIndex, String colorHex) async {
    final highlight = HighlightModel(
      id: HighlightModel.generateId(),
      bookId: widget.bookId,
      chapterIndex: chapterIndex,
      startOffset: start,
      endOffset: end,
      highlightedText: text,
      anchorText: HighlightsManager.generateAnchorText(textContent, start, end),
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );

    await _highlightsManager.addHighlight(highlight);
    // Highlights loading disabled
    controllerPaging.paginate(); // Re-render with highlight
    updateUI();
    CustomToast.showToast('هایلایت اضافه شد');
  }

  /// Remove a highlight
  void _removeHighlight(HighlightModel highlight) async {
    await _highlightsManager.removeHighlight(widget.bookId, highlight.id);
    // Highlights loading disabled
    controllerPaging.paginate(); // Re-render without highlight
    updateUI();
    CustomToast.showToast('هایلایت حذف شد');
  }

  /// Add/edit note for a highlight
  void _showNoteEditor(HighlightModel highlight) {
    final noteController = TextEditingController(text: highlight.noteText ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                highlight.hasNote ? 'ویرایش یادداشت' : 'افزودن یادداشت',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
              ),
              SizedBox(height: 8.h),
              // Show highlighted text
              Container(
                padding: EdgeInsets.all(8.h),
                decoration: BoxDecoration(
                  color: Color(HighlightColors.parseHex(highlight.colorHex)).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  highlight.highlightedText.length > 80
                      ? '${highlight.highlightedText.substring(0, 80)}...'
                      : highlight.highlightedText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: fontColor.withOpacity(0.8),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Note input
              TextField(
                controller: noteController,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
                decoration: InputDecoration(
                  hintText: 'یادداشت خود را بنویسید...',
                  hintStyle: TextStyle(
                    color: fontColor.withOpacity(0.4),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                  filled: true,
                  fillColor: fontColor.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'انصراف',
                        style: TextStyle(
                          color: fontColor.withOpacity(0.5),
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final note = noteController.text.trim();
                        final updated = highlight.copyWith(
                          noteText: note.isEmpty ? null : note,
                        );
                        await _highlightsManager.updateHighlight(updated);
                        // Highlights loading disabled
                        Navigator.pop(context);
                        CustomToast.showToast(note.isEmpty ? 'یادداشت حذف شد' : 'یادداشت ذخیره شد');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'ذخیره',
                        style: TextStyle(
                          color: backColor,
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show popup for tapped highlight (Apple Books style)
  void _showHighlightPopup(HighlightModel highlight) {
    showHighlightPopup(
      context: context,
      highlight: highlight,
      backgroundColor: backColor,
      textColor: fontColor,
      onEdit: (h) {
        _showNoteEditor(h);
      },
      onDelete: (h) {
        _removeHighlight(h);
      },
      onColorChange: (h, colorHex) async {
        final updated = h.copyWith(colorHex: colorHex);
        await _highlightsManager.updateHighlight(updated);
        controllerPaging.paginate();
        updateUI();
      },
    );
  }

  /// Wrapper to create highlight with note dialog
  void _createHighlightWithNote(String text, int start, int end, int chapterIndex) {
    // First create a highlight with default color
    final highlight = HighlightModel(
      id: HighlightModel.generateId(),
      bookId: widget.bookId,
      chapterIndex: chapterIndex,
      startOffset: start,
      endOffset: end,
      highlightedText: text,
      anchorText: HighlightsManager.generateAnchorText(textContent, start, end),
      colorHex: _selectedHighlightColor,
      createdAt: DateTime.now(),
    );

    // Then show note editor
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'افزودن یادداشت',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
              ),
              SizedBox(height: 8.h),
              // Show selected text
              Container(
                padding: EdgeInsets.all(8.h),
                decoration: BoxDecoration(
                  color: Color(HighlightColors.parseHex(_selectedHighlightColor)).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  text.length > 80 ? '${text.substring(0, 80)}...' : text,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: fontColor.withOpacity(0.8),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Note input
              TextField(
                controller: noteController,
                maxLines: 4,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: fontColor,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
                decoration: InputDecoration(
                  hintText: 'یادداشت خود را بنویسید...',
                  hintStyle: TextStyle(
                    color: fontColor.withOpacity(0.4),
                    fontFamily: selectedTextStyle,
                    package: 'cosmos_epub',
                  ),
                  filled: true,
                  fillColor: fontColor.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'انصراف',
                        style: TextStyle(
                          color: fontColor.withOpacity(0.5),
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final note = noteController.text.trim();
                        final highlightWithNote = highlight.copyWith(
                          noteText: note.isEmpty ? null : note,
                        );
                        await _highlightsManager.addHighlight(highlightWithNote);
                        controllerPaging.paginate();
                        Navigator.pop(context);
                        updateUI();
                        CustomToast.showToast(note.isEmpty ? 'هایلایت اضافه شد' : 'یادداشت ذخیره شد');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'ذخیره',
                        style: TextStyle(
                          color: backColor,
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle bookmark at current position
  void _toggleBookmark() {
    final currentChapter = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final existing = _bookmarks.indexWhere(
      (b) => b['chapter'] == currentChapter && b['page'] == _currentPageInChapter,
    );

    setState(() {
      if (existing >= 0) {
        _bookmarks.removeAt(existing);
        CustomToast.showToast('نشانه حذف شد');
      } else {
        _bookmarks.add({
          'chapter': currentChapter,
          'page': _currentPageInChapter,
        });
        CustomToast.showToast('نشانه افزوده شد');
      }
    });
    _saveBookmarks();
  }

  /// Show highlights and notes list with search functionality
  void _showHighlightsSheet() {
    final allHighlights = _highlightsManager.getHighlights(widget.bookId);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Filter highlights based on search query
          final filteredHighlights = searchQuery.isEmpty
              ? allHighlights
              : allHighlights.where((h) {
                  final query = searchQuery.toLowerCase();
                  final matchesText = h.highlightedText.toLowerCase().contains(query);
                  final matchesNote = h.noteText?.toLowerCase().contains(query) ?? false;
                  return matchesText || matchesNote;
                }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) => Container(
                padding: EdgeInsets.all(16.h),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'هایلایت‌ها و یادداشت‌ها',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: fontColor,
                            fontFamily: selectedTextStyle,
                            package: 'cosmos_epub',
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: fontColor),
                        ),
                      ],
                    ),
                    // Search input field
                    if (allHighlights.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Container(
                        decoration: BoxDecoration(
                          color: fontColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: fontColor.withOpacity(0.1),
                          ),
                        ),
                        child: TextField(
                          onChanged: (value) {
                            setSheetState(() {
                              searchQuery = value;
                            });
                          },
                          style: TextStyle(
                            color: fontColor,
                            fontSize: 14.sp,
                            fontFamily: selectedTextStyle,
                            package: 'cosmos_epub',
                          ),
                          decoration: InputDecoration(
                            hintText: 'جستجو در یادداشت‌ها…',
                            hintStyle: TextStyle(
                              color: fontColor.withOpacity(0.4),
                              fontSize: 14.sp,
                              fontFamily: selectedTextStyle,
                              package: 'cosmos_epub',
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: fontColor.withOpacity(0.4),
                              size: 20.h,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      setSheetState(() {
                                        searchQuery = '';
                                      });
                                    },
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: fontColor.withOpacity(0.4),
                                      size: 18.h,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                      ),
                    ],
                    Divider(color: fontColor.withOpacity(0.2)),
                    if (allHighlights.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.highlight_outlined,
                                size: 48.h,
                                color: fontColor.withOpacity(0.3),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'هنوز هایلایتی نساخته‌اید',
                                style: TextStyle(
                                  color: fontColor.withOpacity(0.5),
                                  fontSize: 14.sp,
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'متن را انتخاب و هایلایت کنید',
                                style: TextStyle(
                                  color: fontColor.withOpacity(0.4),
                                  fontSize: 12.sp,
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (filteredHighlights.isEmpty)
                      // No search results
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48.h,
                                color: fontColor.withOpacity(0.3),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'نتیجه‌ای یافت نشد',
                                style: TextStyle(
                                  color: fontColor.withOpacity(0.5),
                                  fontSize: 14.sp,
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'عبارت دیگری را جستجو کنید',
                                style: TextStyle(
                                  color: fontColor.withOpacity(0.4),
                                  fontSize: 12.sp,
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filteredHighlights.length,
                          separatorBuilder: (_, __) => Divider(
                            color: fontColor.withOpacity(0.1),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final highlight = filteredHighlights[index];
                            final chapterName = highlight.chapterIndex < chaptersList.length
                                ? chaptersList[highlight.chapterIndex].chapter
                                : 'فصل ${FarsiHelper.toFarsiDigits(highlight.chapterIndex + 1)}';
                            final highlightColor = Color(HighlightColors.parseHex(highlight.colorHex));

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                              leading: Container(
                                width: 4.w,
                                height: 50.h,
                                decoration: BoxDecoration(
                                  color: highlightColor,
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              title: Text(
                                highlight.highlightedText.length > 60
                                    ? '${highlight.highlightedText.substring(0, 60)}...'
                                    : highlight.highlightedText,
                                style: TextStyle(
                                  color: fontColor,
                                  fontSize: 13.sp,
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4.h),
                                  Text(
                                    chapterName,
                                    style: TextStyle(
                                      color: widget.accentColor,
                                      fontSize: 11.sp,
                                      fontFamily: selectedTextStyle,
                                      package: 'cosmos_epub',
                                    ),
                                  ),
                                  if (highlight.hasNote) ...[
                                    SizedBox(height: 4.h),
                                    Container(
                                      padding: EdgeInsets.all(6.h),
                                      decoration: BoxDecoration(
                                        color: fontColor.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.note_outlined,
                                            size: 12.h,
                                            color: fontColor.withOpacity(0.5),
                                          ),
                                          SizedBox(width: 4.w),
                                          Expanded(
                                            child: Text(
                                              highlight.noteText!,
                                              style: TextStyle(
                                                color: fontColor.withOpacity(0.7),
                                                fontSize: 11.sp,
                                                fontStyle: FontStyle.italic,
                                                fontFamily: selectedTextStyle,
                                                package: 'cosmos_epub',
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: fontColor.withOpacity(0.5),
                                ),
                                color: backColor,
                                onSelected: (value) {
                                  if (value == 'note') {
                                    Navigator.pop(context);
                                    _showNoteEditor(highlight);
                                  } else if (value == 'delete') {
                                    final originalIndex = allHighlights.indexOf(highlight);
                                    if (originalIndex != -1) {
                                      setSheetState(() {
                                        allHighlights.removeAt(originalIndex);
                                      });
                                      _removeHighlight(highlight);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'note',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, size: 18.h, color: fontColor),
                                        SizedBox(width: 8.w),
                                        Text(
                                          highlight.hasNote ? 'ویرایش یادداشت' : 'افزودن یادداشت',
                                          style: TextStyle(
                                            color: fontColor,
                                            fontFamily: selectedTextStyle,
                                            package: 'cosmos_epub',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18.h, color: Colors.red),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'حذف هایلایت',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontFamily: selectedTextStyle,
                                            package: 'cosmos_epub',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                // Navigate to the highlight's chapter
                                final currentChapter = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

                                if (currentChapter != highlight.chapterIndex) {
                                  // Different chapter - load that chapter
                                  await bookProgress.setCurrentPageIndex(bookId, 0);
                                  reLoadChapter(index: highlight.chapterIndex);
                                }
                                CustomToast.showToast(chapterName);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Show bookmarks sheet
  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.all(16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'نشانه‌های من',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: fontColor,
                      fontFamily: selectedTextStyle,
                      package: 'cosmos_epub',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: fontColor),
                  ),
                ],
              ),
              Divider(color: fontColor.withOpacity(0.2)),
              if (_bookmarks.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bookmark_outline_rounded,
                        size: 48.h,
                        color: fontColor.withOpacity(0.3),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'هنوز نشانه‌ای نگذاشته‌اید',
                        style: TextStyle(
                          color: fontColor.withOpacity(0.5),
                          fontSize: 14.sp,
                          fontFamily: selectedTextStyle,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _bookmarks.length,
                    separatorBuilder: (_, __) => Divider(
                      color: fontColor.withOpacity(0.1),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final bookmark = _bookmarks[index];
                      final chapterIndex = bookmark['chapter'] ?? 0;
                      final pageIndex = bookmark['page'] ?? 0;
                      final chapterName = chapterIndex < chaptersList.length
                          ? chaptersList[chapterIndex].chapter
                          : 'فصل ${FarsiHelper.toFarsiDigits(chapterIndex + 1)}';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.bookmark_rounded,
                          color: widget.accentColor,
                        ),
                        title: Text(
                          chapterName,
                          style: TextStyle(
                            color: fontColor,
                            fontSize: 14.sp,
                            fontFamily: selectedTextStyle,
                            package: 'cosmos_epub',
                          ),
                        ),
                        subtitle: Text(
                          'صفحه ${FarsiHelper.toFarsiDigits(pageIndex + 1)}',
                          style: TextStyle(
                            color: fontColor.withOpacity(0.6),
                            fontSize: 12.sp,
                            fontFamily: selectedTextStyle,
                            package: 'cosmos_epub',
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: fontColor.withOpacity(0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _bookmarks.removeAt(index);
                            });
                            _saveBookmarks();
                            Navigator.pop(context);
                            _showBookmarksSheet();
                          },
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          // Navigate to bookmarked position
                          await bookProgress.setCurrentPageIndex(bookId, pageIndex);
                          reLoadChapter(index: chapterIndex);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show search sheet
  void _showSearchSheet() {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              padding: EdgeInsets.all(16.h),
              child: Column(
                children: [
                  // Search input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: fontColor,
                            fontFamily: selectedTextStyle,
                            package: 'cosmos_epub',
                          ),
                          decoration: InputDecoration(
                            hintText: 'جستجو در کتاب...',
                            hintStyle: TextStyle(
                              color: fontColor.withOpacity(0.5),
                              fontFamily: selectedTextStyle,
                              package: 'cosmos_epub',
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: widget.accentColor,
                            ),
                            filled: true,
                            fillColor: fontColor.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (query) {
                            if (query.trim().isNotEmpty) {
                              setSheetState(() => _isSearching = true);
                              _performSearch(query.trim()).then((results) {
                                setSheetState(() {
                                  _searchResults = results;
                                  _isSearching = false;
                                });
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: fontColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Results
                  if (_isSearching)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoActivityIndicator(
                              color: widget.accentColor,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'در حال جستجو...',
                              style: TextStyle(
                                color: fontColor.withOpacity(0.6),
                                fontFamily: selectedTextStyle,
                                package: 'cosmos_epub',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_searchResults.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 48.h,
                              color: fontColor.withOpacity(0.3),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              searchController.text.isEmpty
                                  ? 'عبارت مورد نظر را وارد کنید'
                                  : 'نتیجه‌ای یافت نشد',
                              style: TextStyle(
                                color: fontColor.withOpacity(0.5),
                                fontSize: 14.sp,
                                fontFamily: selectedTextStyle,
                                package: 'cosmos_epub',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${FarsiHelper.toFarsiDigits(_searchResults.length)} نتیجه یافت شد',
                            style: TextStyle(
                              color: fontColor.withOpacity(0.6),
                              fontSize: 12.sp,
                              fontFamily: selectedTextStyle,
                              package: 'cosmos_epub',
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Expanded(
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(
                                color: fontColor.withOpacity(0.1),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                final chapterNum = result['chapterNumber'] as int;
                                final totalChapters = result['totalChapters'] as int;
                                final positionPercent = result['positionPercent'] as int;
                                final snippet = result['snippet'] as String? ?? '';
                                final query = result['query'] as String? ?? '';

                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 4.h,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          result['chapterTitle'] ?? '',
                                          style: TextStyle(
                                            color: widget.accentColor,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: selectedTextStyle,
                                            package: 'cosmos_epub',
                                          ),
                                        ),
                                      ),
                                      // Location indicator
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.w,
                                          vertical: 2.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: widget.accentColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          'فصل ${FarsiHelper.toFarsiDigits(chapterNum)} • ${FarsiHelper.toFarsiDigits(positionPercent)}٪',
                                          style: TextStyle(
                                            color: widget.accentColor,
                                            fontSize: 10.sp,
                                            fontFamily: selectedTextStyle,
                                            package: 'cosmos_epub',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: _buildHighlightedSnippet(
                                    snippet,
                                    query,
                                    fontColor,
                                    widget.accentColor,
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final chapterIndex = result['chapterIndex'] as int;
                                    // Store the search query for potential highlighting
                                    _searchHighlightQuery = query;
                                    await bookProgress.setCurrentPageIndex(bookId, 0);
                                    reLoadChapter(index: chapterIndex);
                                    CustomToast.showToast(
                                      'فصل ${FarsiHelper.toFarsiDigits(chapterNum)} از ${FarsiHelper.toFarsiDigits(totalChapters)}',
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build a text widget with the search query highlighted in the snippet
  Widget _buildHighlightedSnippet(
    String snippet,
    String query,
    Color textColor,
    Color highlightColor,
  ) {
    if (query.isEmpty) {
      return Text(
        snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor.withOpacity(0.8),
          fontSize: 12.sp,
          fontFamily: selectedTextStyle,
          package: 'cosmos_epub',
        ),
      );
    }

    // Find the query in the snippet (case-insensitive)
    final lowerSnippet = FarsiHelper.normalizeForSearch(snippet);
    final lowerQuery = FarsiHelper.normalizeForSearch(query);
    final matchIndex = lowerSnippet.indexOf(lowerQuery);

    if (matchIndex == -1) {
      // Query not found in snippet, return plain text
      return Text(
        snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor.withOpacity(0.8),
          fontSize: 12.sp,
          fontFamily: selectedTextStyle,
          package: 'cosmos_epub',
        ),
      );
    }

    // Build spans with highlighted query
    final beforeMatch = snippet.substring(0, matchIndex);
    final matchText = snippet.substring(matchIndex, matchIndex + query.length);
    final afterMatch = snippet.substring(matchIndex + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: TextStyle(
          color: textColor.withOpacity(0.8),
          fontSize: 12.sp,
          fontFamily: selectedTextStyle,
          package: 'cosmos_epub',
        ),
        children: [
          TextSpan(text: beforeMatch),
          TextSpan(
            text: matchText,
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.bold,
              backgroundColor: highlightColor.withOpacity(0.2),
            ),
          ),
          TextSpan(text: afterMatch),
        ],
      ),
    );
  }

  /// Perform search across all chapters
  /// Returns results with chapter index, position info, and snippets
  Future<List<Map<String, dynamic>>> _performSearch(String query) async {
    final results = <Map<String, dynamic>>[];
    final normalizedQuery = FarsiHelper.normalizeForSearch(query);

    final chapters = epubBook.Chapters;
    if (chapters == null) return results;

    final totalChapters = chapters.length;

    for (int i = 0; i < chapters.length && results.length < 50; i++) {
      final chapter = chapters[i];
      final content = chapter.HtmlContent ?? '';
      final parsed = parse(content);
      final text = parsed.documentElement?.text ?? '';
      final normalizedText = FarsiHelper.normalizeForSearch(text);

      // Find all matches in this chapter
      int searchStart = 0;
      while (searchStart < normalizedText.length && results.length < 50) {
        final matchIndex = normalizedText.indexOf(normalizedQuery, searchStart);
        if (matchIndex == -1) break;

        // Calculate approximate position as percentage within the chapter
        final positionPercent = ((matchIndex / normalizedText.length) * 100).round();

        // Find snippet around the match - use original text for display
        final start = (matchIndex - 50).clamp(0, text.length);
        final end = (matchIndex + query.length + 50).clamp(0, text.length);
        var snippet = text.substring(start, end);
        if (start > 0) snippet = '...$snippet';
        if (end < text.length) snippet = '$snippet...';

        results.add({
          'chapterIndex': i,
          'chapterNumber': i + 1, // Human-readable chapter number
          'totalChapters': totalChapters,
          'chapterTitle': chapter.Title ?? 'فصل ${FarsiHelper.toFarsiDigits(i + 1)}',
          'snippet': snippet.trim(),
          'matchPosition': matchIndex, // Position in plain text (for future highlighting)
          'positionPercent': positionPercent, // Approximate position in chapter as %
          'query': query, // Original query for highlighting
        });

        // Move to find next match (skip past current match)
        searchStart = matchIndex + normalizedQuery.length;
      }
    }

    return results;
  }

  getTitleFromXhtml() {
    ///Listener for slider
    // controller.addListener(() {
    //   if (controller.position.userScrollDirection == ScrollDirection.forward &&
    //       showHeader == false) {
    //     showHeader = true;
    //     update();
    //   } else if (controller.position.userScrollDirection ==
    //           ScrollDirection.reverse &&
    //       showHeader) {
    //     showHeader = false;
    //     update();
    //   }
    // });

    if (epubBook.Title != null) {
      bookTitle = epubBook.Title!;
      updateUI();
    }
  }

  reLoadChapter({bool init = false, int index = -1}) async {
    int currentIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    setState(() {
      loadChapterFuture = loadChapter(
          index: init
              ? -1
              : index == -1
                  ? currentIndex
                  : index);
    });
  }

  /// Load chapter list and content - OPTIMIZED
  /// Building chapter list is synchronous (just reading titles)
  loadChapter({int index = -1}) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('COSMOS_EPUB: loadChapter called with index: $index');

    chaptersList = [];

    final chapters = epubBook.Chapters;
    debugPrint('COSMOS_EPUB: chapters count: ${chapters?.length ?? 0}');

    if (chapters == null || chapters.isEmpty) {
      debugPrint('COSMOS_EPUB: No chapters found!');
      chaptersList.add(LocalChapterModel(chapter: 'بدون فصل', isSubChapter: false));
      textContent = 'این کتاب فاقد محتوا است';
      return;
    }

    // Build chapter list synchronously - no need for async
    for (final chapter in chapters) {
      chaptersList.add(LocalChapterModel(
        chapter: chapter.Title ?? '...',
        isSubChapter: false,
      ));

      // Add sub-chapters
      final subs = chapter.SubChapters;
      if (subs != null) {
        for (final sub in subs) {
          chaptersList.add(LocalChapterModel(
            chapter: sub.Title ?? '...',
            isSubChapter: true,
          ));
        }
      }
    }

    if (chaptersList.isEmpty) {
      chaptersList.add(LocalChapterModel(chapter: 'بدون فصل', isSubChapter: false));
    }

    debugPrint('COSMOS_EPUB: Built chapter list with ${chaptersList.length} entries');

    // Choose initial chapter
    final effectiveIndex = index == -1 ? widget.starterChapter : index;
    if (effectiveIndex >= 0 && effectiveIndex < chaptersList.length) {
      setupNavButtons();
      await updateContentAccordingChapter(effectiveIndex);
    } else {
      setupNavButtons();
      await updateContentAccordingChapter(0);
      CustomToast.showToast('شماره فصل نامعتبر است');
    }

    stopwatch.stop();
    debugPrint('COSMOS_EPUB: loadChapter completed in ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Update content for the specified chapter - OPTIMIZED
  /// Only loads content for the specific chapter, not all chapters
  updateContentAccordingChapter(int chapterIndex) async {
    final stopwatch = Stopwatch()..start();

    // Set current chapter index (async but fast)
    await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);

    String content = '';

    final chapters = epubBook.Chapters;
    if (chapters == null || chapters.isEmpty) {
      content = '<p>محتوای کتاب یافت نشد</p>';
    } else {
      final safeIndex = chapterIndex.clamp(0, chapters.length - 1);
      final chapter = chapters[safeIndex];

      // Get main chapter content
      content = chapter.HtmlContent ?? '';

      // Add sub-chapter content only for this chapter (not all chapters!)
      final subChapters = chapter.SubChapters;
      if (subChapters != null && subChapters.isNotEmpty) {
        final subContent = StringBuffer(content);
        for (final sub in subChapters) {
          if (sub.HtmlContent != null) {
            subContent.write(sub.HtmlContent!);
          }
        }
        content = subContent.toString();
      }
    }

    htmlContent = content;
    debugPrint('COSMOS_EPUB: htmlContent length: ${htmlContent.length}');

    // Parse HTML to text
    final parsed = parse(htmlContent);
    textContent = parsed.documentElement?.text ?? '';
    debugPrint('COSMOS_EPUB: textContent length after parse: ${textContent.length}');

    if (textContent.isEmpty) {
      textContent = 'محتوای این فصل خالی است';
      debugPrint('COSMOS_EPUB: textContent was empty, set default');
    } else if (isHTML(textContent)) {
      innerHtmlContent = textContent;
      debugPrint('COSMOS_EPUB: content is HTML');
    } else {
      textContent = textContent.replaceAll('Unknown', '').trim();
      debugPrint('COSMOS_EPUB: cleaned textContent length: ${textContent.length}');
    }

    // Detect text direction for the current content
    currentTextDirection = RTLHelper.getTextDirection(textContent);
    debugPrint('COSMOS_EPUB: textDirection: $currentTextDirection');

    // Load highlights for this chapter
    // Highlights loading disabled

    controllerPaging.paginate();
    setupNavButtons();

    stopwatch.stop();
    debugPrint('COSMOS_EPUB: updateContentAccordingChapter took ${stopwatch.elapsedMilliseconds}ms');
  }

  bool isHTML(String str) {
    final RegExp htmlRegExp =
        RegExp('<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlRegExp.hasMatch(str);
  }

  setupNavButtons() {
    int index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    setState(() {
      if (index == 0) {
        showPrevious = false;
      } else {
        showPrevious = true;
      }
      if (index == chaptersList.length - 1) {
        showNext = false;
      } else {
        showNext = true;
      }
    });
  }

  Future<bool> backPress() async {
    // Navigator.of(context).pop();
    return true;
  }

  void setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
  }

  /// Apple Books-style settings sheet
  updateFontSettings() {
    // Local state for the sheet
    double localFontSize = _fontSizeProgress;
    double localLineSpacing = _lineSpacing;

    return showModalBottomSheet(
        context: context,
        elevation: 10,
        clipBehavior: Clip.antiAlias,
        backgroundColor: backColor,
        enableDrag: true,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.r),
                topRight: Radius.circular(24.r))),
        builder: (context) {
          return SingleChildScrollView(
              child: StatefulBuilder(
                  builder: (BuildContext context, setState) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: Container(
                          padding: EdgeInsets.only(
                            top: 12.h,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Drag handle
                              Container(
                                width: 36.w,
                                height: 4.h,
                                decoration: BoxDecoration(
                                  color: fontColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // Header
                              Text(
                                'تنظیمات نمایش',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: fontColor,
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // ===== THEMES SECTION =====
                              // Only calm, paper-like themes (Apple Books style)
                              _buildSectionLabel('پوسته'),
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Original (Parasto warm navy) - default
                                    _buildThemeCircle(
                                      themeId: 6,
                                      bgColor: cParastoBackground,
                                      fgColor: cParastoTextPrimary,
                                      label: 'اصلی',
                                    ),
                                    // Calm (sepia/paper)
                                    _buildThemeCircle(
                                      themeId: 1,
                                      bgColor: cVioletishColor,
                                      fgColor: Colors.black,
                                      label: 'آرام',
                                    ),
                                    // Focus (clean white)
                                    _buildThemeCircle(
                                      themeId: 3,
                                      bgColor: Colors.white,
                                      fgColor: Colors.black,
                                      label: 'متمرکز',
                                    ),
                                    // Bold (higher contrast blue)
                                    _buildThemeCircle(
                                      themeId: 2,
                                      bgColor: cBluishColor,
                                      fgColor: Colors.black,
                                      label: 'پررنگ',
                                    ),
                                  ],
                                ),
                              ),

                              _buildDivider(),

                              // ===== FONT SECTION =====
                              _buildSectionLabel('قلم'),
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 20.w),
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: fontColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(canvasColor: backColor),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                        value: selectedFont,
                                        isExpanded: true,
                                        menuMaxHeight: 300.h,
                                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: fontColor),
                                        onChanged: (newValue) {
                                          selectedFont = newValue ?? 'Abar';
                                          selectedTextStyle = fontNames
                                              .where((element) => element == selectedFont)
                                              .first;
                                          gs.write(libFont, selectedFont);
                                          setState(() {});
                                          controllerPaging.paginate();
                                          updateUI();
                                        },
                                        items: fontNames.map<DropdownMenuItem<String>>((String font) {
                                          return DropdownMenuItem<String>(
                                            value: font,
                                            child: Text(
                                              font,
                                              style: TextStyle(
                                                  color: selectedFont == font
                                                      ? widget.accentColor
                                                      : fontColor,
                                                  package: 'cosmos_epub',
                                                  fontSize: context.isTablet ? 10.sp : 14.sp,
                                                  fontWeight: selectedFont == font
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  fontFamily: font),
                                            ),
                                          );
                                        }).toList()),
                                  ),
                                ),
                              ),

                              _buildDivider(),

                              // ===== FONT SIZE SECTION =====
                              _buildSectionLabel('اندازه متن'),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Row(
                                  children: [
                                    Text(
                                      "آ",
                                      style: TextStyle(
                                          fontSize: 14.sp,
                                          color: fontColor.withOpacity(0.6),
                                          fontFamily: selectedTextStyle,
                                          package: 'cosmos_epub'),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4.h,
                                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
                                        ),
                                        child: Slider(
                                          activeColor: widget.accentColor,
                                          inactiveColor: fontColor.withOpacity(0.15),
                                          value: localFontSize,
                                          min: 14.0,
                                          max: 32.0,
                                          onChangeEnd: (double value) {
                                            _fontSize = value;
                                            _fontSizeProgress = value;
                                            gs.write(libFontSize, _fontSize);
                                            updateUI();
                                            controllerPaging.paginate();
                                          },
                                          onChanged: (double value) {
                                            setState(() {
                                              localFontSize = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "آ",
                                      style: TextStyle(
                                          color: fontColor.withOpacity(0.6),
                                          fontSize: 22.sp,
                                          fontFamily: selectedTextStyle,
                                          package: 'cosmos_epub'),
                                    )
                                  ],
                                ),
                              ),

                              _buildDivider(),

                              // ===== LINE SPACING SECTION =====
                              _buildSectionLabel('فاصله خطوط'),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: lineSpacingOptions.map((spacing) {
                                    final isSelected = (localLineSpacing - spacing).abs() < 0.01;
                                    String label;
                                    if (spacing == 1.0) {
                                      label = 'فشرده';
                                    } else if (spacing == 1.25) {
                                      label = 'معمولی';
                                    } else if (spacing == 1.5) {
                                      label = 'راحت';
                                    } else {
                                      label = 'باز';
                                    }
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          localLineSpacing = spacing;
                                        });
                                        _lineSpacing = spacing;
                                        selectedLineSpacing = spacing;
                                        gs.write(libLineSpacing, spacing);
                                        controllerPaging.paginate();
                                        updateUI();
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 8.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? widget.accentColor.withOpacity(0.2)
                                              : fontColor.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8.r),
                                          border: isSelected
                                              ? Border.all(color: widget.accentColor, width: 1.5)
                                              : null,
                                        ),
                                        child: Column(
                                          children: [
                                            // Line spacing icon representation
                                            Icon(
                                              Icons.format_line_spacing_rounded,
                                              size: 20.h,
                                              color: isSelected ? widget.accentColor : fontColor.withOpacity(0.5),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: isSelected ? widget.accentColor : fontColor.withOpacity(0.7),
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                fontFamily: selectedTextStyle,
                                                package: 'cosmos_epub',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              SizedBox(height: 8.h),
                            ],
                          ),
                        ),
                      )));
        });
  }

  /// Build a section label for settings sheet
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: fontColor.withOpacity(0.5),
            fontWeight: FontWeight.w600,
            fontFamily: selectedTextStyle,
            package: 'cosmos_epub',
          ),
        ),
      ),
    );
  }

  /// Build a divider for settings sheet
  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Divider(
        thickness: 1.h,
        height: 0,
        indent: 20.w,
        endIndent: 20.w,
        color: fontColor.withOpacity(0.1),
      ),
    );
  }

  /// Build a theme selection circle
  Widget _buildThemeCircle({
    required int themeId,
    required Color bgColor,
    required Color fgColor,
    required String label,
  }) {
    final isSelected = staticThemeId == themeId;
    return GestureDetector(
      onTap: () => updateTheme(themeId),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? widget.accentColor : fgColor.withOpacity(0.3),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                'آ',
                style: TextStyle(
                  color: fgColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: isSelected ? widget.accentColor : fontColor.withOpacity(0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: selectedTextStyle,
              package: 'cosmos_epub',
            ),
          ),
        ],
      ),
    );
  }

  updateTheme(int id, {bool isInit = false}) {
    staticThemeId = id;
    if (id == 1) {
      backColor = cVioletishColor;
      fontColor = Colors.black;
    } else if (id == 2) {
      backColor = cBluishColor;
      fontColor = Colors.black;
    } else if (id == 3) {
      backColor = Colors.white;
      fontColor = Colors.black;
    } else if (id == 4) {
      backColor = Colors.black;
      fontColor = Colors.white;
    } else if (id == 5) {
      backColor = cPinkishColor;
      fontColor = Colors.black;
    } else {
      // id == 6: Parasto theme (warm navy, NOT pure black)
      backColor = cParastoBackground;
      fontColor = cParastoTextPrimary;
    }

    gs.write(libTheme, id);

    if (!isInit) {
      Navigator.of(context).pop();
      controllerPaging.paginate();
      updateUI();
    }
  }

  ///Update widget tree
  updateUI() {
    setState(() {});
  }

  nextChapter() async {
    ///Set page to initial
    await bookProgress.setCurrentPageIndex(bookId, 0);

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    if (index != chaptersList.length - 1) {
      reLoadChapter(index: index + 1);
    }
  }

  prevChapter() async {
    ///Set page to initial
    await bookProgress.setCurrentPageIndex(bookId, 0);

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    if (index != 0) {
      reLoadChapter(index: index - 1);
    }
  }

  /// Show the compact reader menu (Apple Books-style bottom sheet)
  /// Clean, minimal - no redundant info (progress shown in overlay)
  void _showReaderMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 32.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: fontColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),

                // Compact menu - horizontal row of icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // TOC / Chapters
                    _buildCompactMenuButton(
                      icon: Icons.list_rounded,
                      label: 'فهرست',
                      onTap: () {
                        Navigator.pop(context);
                        openTableOfContents();
                      },
                    ),
                    // Search
                    _buildCompactMenuButton(
                      icon: Icons.search_rounded,
                      label: 'جستجو',
                      onTap: () {
                        Navigator.pop(context);
                        _showSearchSheet();
                      },
                    ),
                    // Bookmarks
                    _buildCompactMenuButton(
                      icon: _isCurrentPageBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      label: 'نشانه',
                      isActive: _isCurrentPageBookmarked,
                      onTap: () {
                        _toggleBookmark();
                        setSheetState(() {});
                      },
                      onLongPress: () {
                        Navigator.pop(context);
                        _showBookmarksSheet();
                      },
                    ),
                    // Highlights & Notes
                    _buildCompactMenuButton(
                      icon: Icons.sticky_note_2_rounded,
                      label: 'یادداشت‌ها',
                      isActive: _highlightsManager.getHighlights(widget.bookId).isNotEmpty,
                      onTap: () {
                        Navigator.pop(context);
                        _showHighlightsSheet();
                      },
                    ),
                    // Settings
                    _buildCompactMenuButton(
                      icon: Icons.text_format_rounded,
                      label: 'تنظیمات',
                      onTap: () {
                        Navigator.pop(context);
                        updateFontSettings();
                      },
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Brightness slider (compact)
                Row(
                  children: [
                    Icon(
                      Icons.brightness_low_rounded,
                      size: 16.h,
                      color: fontColor.withOpacity(0.4),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: widget.accentColor,
                          inactiveTrackColor: fontColor.withOpacity(0.15),
                          trackHeight: 3.h,
                          thumbColor: widget.accentColor,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
                        ),
                        child: Slider(
                          value: brightnessLevel,
                          min: 0.1,
                          max: 1.0,
                          onChanged: (value) {
                            setSheetState(() {
                              brightnessLevel = value;
                            });
                            setBrightness(value);
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.brightness_high_rounded,
                      size: 16.h,
                      color: fontColor.withOpacity(0.4),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // Chapter navigation (compact)
                Row(
                  children: [
                    // Previous chapter
                    Expanded(
                      child: GestureDetector(
                        onTap: showPrevious
                            ? () {
                                Navigator.pop(context);
                                prevChapter();
                              }
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: showPrevious
                                ? fontColor.withOpacity(0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20.h,
                            color: showPrevious
                                ? fontColor.withOpacity(0.6)
                                : fontColor.withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                    // Chapter title
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          openTableOfContents();
                        },
                        child: Text(
                          chapterTitle.isNotEmpty ? chapterTitle : 'فصل',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: fontColor.withOpacity(0.7),
                            fontFamily: selectedTextStyle,
                            package: 'cosmos_epub',
                          ),
                        ),
                      ),
                    ),
                    // Next chapter
                    Expanded(
                      child: GestureDetector(
                        onTap: showNext
                            ? () {
                                Navigator.pop(context);
                                nextChapter();
                              }
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: showNext
                                ? fontColor.withOpacity(0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 20.h,
                            color: showNext
                                ? fontColor.withOpacity(0.6)
                                : fontColor.withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a compact menu button for the horizontal menu row
  Widget _buildCompactMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.h,
            height: 44.h,
            decoration: BoxDecoration(
              color: isActive
                  ? widget.accentColor.withOpacity(0.15)
                  : fontColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20.h,
              color: isActive ? widget.accentColor : fontColor.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: isActive ? widget.accentColor : fontColor.withOpacity(0.5),
              fontFamily: selectedTextStyle,
              package: 'cosmos_epub',
            ),
          ),
        ],
      ),
    );
  }

  /// Build Apple Books-style pill button for overlay controls
  Widget _buildOverlayPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.h,
              height: 48.h,
              decoration: BoxDecoration(
                color: isActive
                    ? widget.accentColor.withOpacity(0.15)
                    : fontColor.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24.h,
                color: isActive ? widget.accentColor : fontColor.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: isActive ? widget.accentColor : fontColor.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontFamily: selectedTextStyle,
                package: 'cosmos_epub',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Apple Books-style menu panel item (for popup menu)
  Widget _buildMenuPanelItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180.w,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20.h,
              color: isActive ? widget.accentColor : fontColor.withOpacity(0.7),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isActive ? widget.accentColor : fontColor.withOpacity(0.85),
                  fontFamily: selectedTextStyle,
                  package: 'cosmos_epub',
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a menu button for the reader menu grid
  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? widget.accentColor.withOpacity(0.15)
              : fontColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive
                ? widget.accentColor.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24.h,
              color: isActive ? widget.accentColor : fontColor.withOpacity(0.8),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: isActive ? widget.accentColor : fontColor.withOpacity(0.7),
                fontFamily: selectedTextStyle,
                package: 'cosmos_epub',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a navigation button for prev/next chapter in menu
  Widget _buildMenuNavButton({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isEnabled
              ? widget.accentColor.withOpacity(0.1)
              : fontColor.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20.h,
              color: isEnabled
                  ? widget.accentColor
                  : fontColor.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print('[COSMOS_EPUB] ShowEpub.build() called');
    debugPrint('COSMOS_EPUB: ShowEpub.build() called');
    return ScreenUtilInit(
      designSize: const Size(DESIGN_WIDTH, DESIGN_HEIGHT),
      minTextAdapt: true,
      builder: (context, child) {
        // ignore: avoid_print
        print('[COSMOS_EPUB] ScreenUtilInit.builder called');
        debugPrint('COSMOS_EPUB: ScreenUtilInit.builder called');
        return WillPopScope(
            onWillPop: backPress,
            child: Scaffold(
              backgroundColor: backColor,
              body: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                            child: Stack(
                          children: [
                            FutureBuilder<void>(
                                future: loadChapterFuture,
                                builder: (context, snapshot) {
                                  // ignore: avoid_print
                                  print('[COSMOS_EPUB] FutureBuilder state: ${snapshot.connectionState}');
                                  debugPrint('COSMOS_EPUB: FutureBuilder state: ${snapshot.connectionState}');
                                  if (snapshot.hasError) {
                                    // ignore: avoid_print
                                    print('[COSMOS_EPUB] FutureBuilder ERROR: ${snapshot.error}');
                                    debugPrint('COSMOS_EPUB: FutureBuilder ERROR: ${snapshot.error}');
                                  }
                                  switch (snapshot.connectionState) {
                                    case ConnectionState.waiting:
                                      {
                                        // ignore: avoid_print
                                        print('[COSMOS_EPUB] FutureBuilder waiting...');
                                        debugPrint('COSMOS_EPUB: FutureBuilder waiting...');
                                        // Otherwise, display a loading indicator.
                                        return Center(
                                            child: CupertinoActivityIndicator(
                                          color: Theme.of(context).primaryColor,
                                          radius: 30.r,
                                        ));
                                  }
                                default:
                                  {
                                    if (widget.shouldOpenDrawer) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        openTableOfContents();
                                      });

                                      widget.shouldOpenDrawer = false;
                                    }

                                    var currentChapterIndex = bookProgress
                                            .getBookProgress(bookId)
                                            .currentChapterIndex ??
                                        0;

                                    return PagingWidget(
                                      textContent,
                                      innerHtmlContent,

                                      ///Do we need this to the production
                                      lastWidget: null,
                                      starterPageIndex: bookProgress
                                              .getBookProgress(bookId)
                                              .currentPageIndex ??
                                          0,
                                      chapterTitle: chapterTitle,
                                      totalChapters: chaptersList.length,
                                      // Pass RTL flag for proper swipe direction
                                      // Farsi books: swipe left = next page
                                      isRightToLeft: currentTextDirection == TextDirection.rtl,
                                      style: TextStyle(
                                          backgroundColor: backColor,
                                          fontSize: _fontSize.sp,
                                          height: _lineSpacing, // Line spacing
                                          fontFamily: selectedTextStyle,
                                          package: 'cosmos_epub',
                                          color: fontColor),
                                      // Highlight system parameters
                                      highlights: _highlightsManager.getHighlightsForChapter(bookId, currentChapterIndex),
                                      accentColor: widget.accentColor,
                                      searchQuery: _searchHighlightQuery,
                                      chapterIndex: currentChapterIndex,
                                      onHighlight: (text, start, end, colorHex) {
                                        _createHighlight(text, start, end, currentChapterIndex, colorHex);
                                      },
                                      onAddNote: (text, start, end) {
                                        _createHighlightWithNote(text, start, end, currentChapterIndex);
                                      },
                                      onHighlightTap: (highlight) {
                                        _showHighlightPopup(highlight);
                                      },
                                      handlerCallback: (ctrl) {
                                        controllerPaging = ctrl;
                                      },
                                      onTextTap: () {
                                        // Apple Books style: tap to toggle overlay
                                        setState(() {
                                          _showOverlay = !_showOverlay;
                                        });
                                      },
                                      onPageFlip: (currentPage, totalPages) {
                                        // Update page progress for visual indicator
                                        _currentPageInChapter = currentPage;
                                        _totalPagesInChapter = totalPages;

                                        // Auto-hide overlay on page flip for distraction-free reading
                                        if (_showOverlay) {
                                          setState(() {
                                            _showOverlay = false;
                                            _showMenuPanel = false;
                                          });
                                        }

                                        if (widget.onPageFlip != null) {
                                          widget.onPageFlip!(
                                              currentPage, totalPages);
                                        }

                                        if (currentPage == totalPages - 1) {
                                          bookProgress.setCurrentPageIndex(
                                              bookId, 0);
                                        } else {
                                          bookProgress.setCurrentPageIndex(
                                              bookId, currentPage);
                                        }

                                        // Reset swipe counter when not at boundary
                                        if (!isLastPage) {
                                          lastSwipe = 0;
                                        }

                                        isLastPage = false;

                                        if (currentPage == 0) {
                                          prevSwipe++;
                                          if (prevSwipe > 1) {
                                            prevChapter();
                                          }
                                        } else {
                                          prevSwipe = 0;
                                        }
                                      },
                                      onLastPage: (index, totalPages) async {
                                        if (widget.onLastPage != null) {
                                          widget.onLastPage!(index);
                                        }

                                        if (totalPages > 1) {
                                          lastSwipe++;
                                        } else {
                                          lastSwipe = 2;
                                        }

                                        if (lastSwipe > 1) {
                                          nextChapter();
                                        }

                                        isLastPage = true;
                                      },
                                    );
                                  }
                              }
                            }),
                          ],
                        )),
                      ],
                    ),

                    // APPLE BOOKS STYLE: Tap-to-show overlay
                    // Shows: X (top-left), Title (top-center), Menu (top-right)
                    // Page indicator (bottom-center), Menu button (bottom-right)
                    // All controls are low-profile and only visible when overlay is active
                    if (_showOverlay) ...[
                      // Semi-transparent tap-to-dismiss layer
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showOverlay = false;
                              _showMenuPanel = false;
                            });
                          },
                          behavior: HitTestBehavior.translucent,
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                      // TOP BAR: X button (left) + Title (center) + Menu button (right)
                      Positioned(
                        top: 8.h,
                        left: 12.w,
                        right: 12.w,
                        child: Row(
                          children: [
                            // X button - low profile, 44x44 tap target
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: 44.h,
                                height: 44.h,
                                decoration: BoxDecoration(
                                  color: backColor.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: fontColor.withOpacity(0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: fontColor.withOpacity(0.5),
                                  size: 22.h,
                                ),
                              ),
                            ),
                            // Title - center
                            Expanded(
                              child: Text(
                                bookTitle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: fontColor.withOpacity(0.4),
                                  fontFamily: selectedTextStyle,
                                  package: 'cosmos_epub',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Spacer to balance X button
                            SizedBox(width: 44.h),
                          ],
                        ),
                      ),

                      // BOTTOM CENTER: Page indicator
                      Positioned(
                        bottom: 16.h,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: backColor.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: fontColor.withOpacity(0.08),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              FarsiHelper.formatPageIndicator(_currentPageInChapter + 1, _totalPagesInChapter),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: fontColor.withOpacity(0.5),
                                fontFamily: selectedTextStyle,
                                package: 'cosmos_epub',
                              ),
                            ),
                          ),
                        ),
                      ),

                      // BOTTOM RIGHT: Menu button (three lines) - fixed position
                      Positioned(
                        bottom: 16.h,
                        right: 16.w,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showMenuPanel = !_showMenuPanel;
                            });
                          },
                          child: Container(
                            width: 48.h,
                            height: 48.h,
                            decoration: BoxDecoration(
                              color: backColor.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: fontColor.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.menu_rounded,
                              color: fontColor.withOpacity(0.7),
                              size: 24.h,
                            ),
                          ),
                        ),
                      ),

                      // MENU PANEL: Apple Books-style compact menu
                      if (_showMenuPanel)
                        Positioned(
                          bottom: 80.h,
                          right: 16.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: backColor.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: fontColor.withOpacity(0.1),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Contents (TOC)
                                _buildMenuPanelItem(
                                  icon: Icons.list_rounded,
                                  label: 'فهرست',
                                  onTap: () {
                                    setState(() {
                                      _showOverlay = false;
                                      _showMenuPanel = false;
                                    });
                                    openTableOfContents();
                                  },
                                ),
                                // Search Book
                                _buildMenuPanelItem(
                                  icon: Icons.search_rounded,
                                  label: 'جستجو در کتاب',
                                  onTap: () {
                                    setState(() {
                                      _showOverlay = false;
                                      _showMenuPanel = false;
                                    });
                                    _showSearchSheet();
                                  },
                                ),
                                // Bookmark
                                _buildMenuPanelItem(
                                  icon: _isCurrentPageBookmarked
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  label: _isCurrentPageBookmarked ? 'حذف نشانه' : 'افزودن نشانه',
                                  isActive: _isCurrentPageBookmarked,
                                  onTap: () {
                                    _toggleBookmark();
                                    setState(() {});
                                  },
                                ),
                                // Divider
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                  child: Divider(
                                    height: 1,
                                    color: fontColor.withOpacity(0.1),
                                  ),
                                ),
                                // Themes & Settings
                                _buildMenuPanelItem(
                                  icon: Icons.text_format_rounded,
                                  label: 'تنظیمات نمایش',
                                  onTap: () {
                                    setState(() {
                                      _showOverlay = false;
                                      _showMenuPanel = false;
                                    });
                                    updateFontSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
      },
    );
  }

  openTableOfContents() async {
    bool? shouldUpdate = await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ChaptersList(
                  bookId: bookId,
                  chapters: chaptersList,
                  leadingIcon: null,
                  accentColor: widget.accentColor,
                  chapterListTitle: widget.chapterListTitle,
                ))) ??
        false;
    if (shouldUpdate) {
      var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

      ///Set page to initial and update chapter index with content
      await bookProgress.setCurrentPageIndex(bookId, 0);
      reLoadChapter(index: index);
    }
  }
}

// ignore: must_be_immutable
