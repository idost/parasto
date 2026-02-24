library cosmos_epub;

import 'dart:io';

import 'package:cosmos_epub/Component/constants.dart';
import 'package:cosmos_epub/Component/theme_colors.dart';
import 'package:cosmos_epub/Helpers/isar_service.dart';
import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:cosmos_epub/Helpers/highlights_manager.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';

import 'package:http/http.dart' as http;

///TODO: Optimize with isolates

class CosmosEpub {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;

  static Future<void> openLocalBook(
      {required String localPath,
      required BuildContext context,
      required String bookId,
      Color accentColor = cParastoPrimary,
      Function(int currentPage, int totalPages)? onPageFlip,
      Function(int lastPageIndex)? onLastPage,
      Future<void> Function(HighlightModel highlight, SyncOperation operation)? onHighlightSync,
      String chapterListTitle = 'فهرست مطالب',
      bool shouldOpenDrawer = false,
      int starterChapter = -1}) async {
    // ignore: avoid_print
    print('[COSMOS_EPUB] openLocalBook called');
    // ignore: avoid_print
    print('[COSMOS_EPUB] localPath: $localPath');
    // ignore: avoid_print
    print('[COSMOS_EPUB] bookId: $bookId');
    debugPrint('COSMOS_EPUB: openLocalBook called');
    debugPrint('COSMOS_EPUB: localPath: $localPath');
    debugPrint('COSMOS_EPUB: bookId: $bookId');
    debugPrint('COSMOS_EPUB: starterChapter: $starterChapter');

    try {
      final totalStopwatch = Stopwatch()..start();

      debugPrint('COSMOS_EPUB: Reading file bytes...');
      final readStopwatch = Stopwatch()..start();
      var bytes = File(localPath).readAsBytesSync();
      readStopwatch.stop();
      debugPrint('COSMOS_EPUB: File read in ${readStopwatch.elapsedMilliseconds}ms, size: ${bytes.length} bytes');

      debugPrint('COSMOS_EPUB: Parsing EPUB...');
      final parseStopwatch = Stopwatch()..start();
      EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());
      parseStopwatch.stop();
      debugPrint('COSMOS_EPUB: EPUB parsed in ${parseStopwatch.elapsedMilliseconds}ms');
      debugPrint('COSMOS_EPUB: Title: ${epubBook.Title}');
      debugPrint('COSMOS_EPUB: Chapters: ${epubBook.Chapters?.length ?? 0}');
      debugPrint('COSMOS_EPUB: Total open time so far: ${totalStopwatch.elapsedMilliseconds}ms');

      if (!context.mounted) {
        // ignore: avoid_print
        print('[COSMOS_EPUB] ERROR: Context not mounted, returning');
        debugPrint('COSMOS_EPUB: Context not mounted, returning');
        return;
      }

      // ignore: avoid_print
      print('[COSMOS_EPUB] Calling _openBook...');
      debugPrint('COSMOS_EPUB: Calling _openBook...');
      // IMPORTANT: await _openBook so we wait for ShowEpub to be closed
      await _openBook(
          context: context,
          epubBook: epubBook,
          bookId: bookId,
          shouldOpenDrawer: shouldOpenDrawer,
          starterChapter: starterChapter,
          chapterListTitle: chapterListTitle,
          onPageFlip: onPageFlip,
          onLastPage: onLastPage,
          onHighlightSync: onHighlightSync,
          accentColor: accentColor);
      // ignore: avoid_print
      print('[COSMOS_EPUB] _openBook returned (ShowEpub was closed)');
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[COSMOS_EPUB] ERROR in openLocalBook: $e');
      // ignore: avoid_print
      print('[COSMOS_EPUB] Stack trace: $stackTrace');
      debugPrint('COSMOS_EPUB: ERROR in openLocalBook: $e');
      debugPrint('COSMOS_EPUB: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> openFileBook(
      {required Uint8List bytes,
      required BuildContext context,
      required String bookId,
      Color accentColor = cParastoPrimary,
      Function(int currentPage, int totalPages)? onPageFlip,
      Function(int lastPageIndex)? onLastPage,
      String chapterListTitle = 'فهرست مطالب',
      bool shouldOpenDrawer = false,
      int starterChapter = -1}) async {
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());

    if (!context.mounted) return;
    await _openBook(
        context: context,
        epubBook: epubBook,
        bookId: bookId,
        shouldOpenDrawer: shouldOpenDrawer,
        starterChapter: starterChapter,
        chapterListTitle: chapterListTitle,
        onPageFlip: onPageFlip,
        onLastPage: onLastPage,
        accentColor: accentColor);
  }

  static Future<void> openURLBook(
      {required String urlPath,
      required BuildContext context,
      Color accentColor = cParastoPrimary,
      Function(int currentPage, int totalPages)? onPageFlip,
      Function(int lastPageIndex)? onLastPage,
      required String bookId,
      String chapterListTitle = 'فهرست مطالب',
      bool shouldOpenDrawer = false,
      int starterChapter = -1}) async {
    final result = await http.get(Uri.parse(urlPath));
    final bytes = result.bodyBytes;
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());

    if (!context.mounted) return;
    await _openBook(
        context: context,
        epubBook: epubBook,
        bookId: bookId,
        shouldOpenDrawer: shouldOpenDrawer,
        starterChapter: starterChapter,
        chapterListTitle: chapterListTitle,
        onPageFlip: onPageFlip,
        onLastPage: onLastPage,
        accentColor: accentColor);
  }

  static Future<void> openAssetBook(
      {required String assetPath,
      required BuildContext context,
      Color accentColor = cParastoPrimary,
      Function(int currentPage, int totalPages)? onPageFlip,
      Function(int lastPageIndex)? onLastPage,
      required String bookId,
      String chapterListTitle = 'فهرست مطالب',
      bool shouldOpenDrawer = false,
      int starterChapter = -1}) async {
    var bytes = await rootBundle.load(assetPath);
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());

    if (!context.mounted) return;
    await _openBook(
        context: context,
        epubBook: epubBook,
        bookId: bookId,
        shouldOpenDrawer: shouldOpenDrawer,
        starterChapter: starterChapter,
        chapterListTitle: chapterListTitle,
        onPageFlip: onPageFlip,
        onLastPage: onLastPage,
        accentColor: accentColor);
  }

  static _openBook(
      {required BuildContext context,
      required EpubBook epubBook,
      required String bookId,
      required bool shouldOpenDrawer,
      required Color accentColor,
      required int starterChapter,
      required String chapterListTitle,
      Function(int currentPage, int totalPages)? onPageFlip,
      Function(int lastPageIndex)? onLastPage,
      Future<void> Function(HighlightModel highlight, SyncOperation operation)? onHighlightSync}) async {
    // ignore: avoid_print
    print('[COSMOS_EPUB] _openBook called');
    debugPrint('COSMOS_EPUB: _openBook called');
    debugPrint('COSMOS_EPUB: shouldOpenDrawer: $shouldOpenDrawer');
    debugPrint('COSMOS_EPUB: starterChapter: $starterChapter');

    try {
      _checkInitialization();
      // ignore: avoid_print
      print('[COSMOS_EPUB] Initialization checked OK');
      debugPrint('COSMOS_EPUB: Initialization checked OK');
    } catch (e) {
      // ignore: avoid_print
      print('[COSMOS_EPUB] Initialization check FAILED: $e');
      debugPrint('COSMOS_EPUB: Initialization check FAILED: $e');
      rethrow;
    }

    ///Set starter chapter as current
    if (starterChapter != -1) {
      debugPrint('COSMOS_EPUB: Setting starter chapter to $starterChapter');
      await bookProgress.setCurrentChapterIndex(bookId, starterChapter);
      await bookProgress.setCurrentPageIndex(bookId, 0);
    }

    final savedProgress = bookProgress.getBookProgress(bookId);
    final effectiveStartChapter = starterChapter >= 0
        ? starterChapter
        : savedProgress.currentChapterIndex ?? 0;
    // ignore: avoid_print
    print('[COSMOS_EPUB] effectiveStartChapter: $effectiveStartChapter');
    debugPrint('COSMOS_EPUB: effectiveStartChapter: $effectiveStartChapter');

    var route = MaterialPageRoute(
      builder: (context) {
        // ignore: avoid_print
        print('[COSMOS_EPUB] Building ShowEpub widget');
        debugPrint('COSMOS_EPUB: Building ShowEpub widget');
        return ShowEpub(
          epubBook: epubBook,
          starterChapter: effectiveStartChapter,
          shouldOpenDrawer: shouldOpenDrawer,
          bookId: bookId,
          accentColor: accentColor,
          chapterListTitle: chapterListTitle,
          onPageFlip: onPageFlip,
          onLastPage: onLastPage,
          onHighlightSync: onHighlightSync,
        );
      },
    );

    // Navigate directly without postFrameCallback to avoid context issues
    if (context.mounted) {
      // ignore: avoid_print
      print('[COSMOS_EPUB] Context is mounted, navigating with Navigator.push...');
      debugPrint('COSMOS_EPUB: Context is mounted, navigating...');
      // Always use push to avoid replacing the EpubReaderScreen
      // IMPORTANT: await the push so openLocalBook doesn't return until ShowEpub is closed
      debugPrint('COSMOS_EPUB: Using Navigator.push (awaited)');
      await Navigator.push(context, route);
      // ignore: avoid_print
      print('[COSMOS_EPUB] ShowEpub closed, Navigator.push returned');
      debugPrint('COSMOS_EPUB: ShowEpub closed, Navigator.push returned');
    } else {
      // ignore: avoid_print
      print('[COSMOS_EPUB] ERROR: Context NOT mounted, cannot navigate');
      debugPrint('COSMOS_EPUB: Context NOT mounted, cannot navigate');
    }
  }

  static Future<bool> initialize() async {
    await ScreenUtil.ensureScreenSize();
    await GetStorage.init();
    bookProgress = await IsarService.buildIsarService();
    _initialized = true;
    return true;
  }

  static _checkInitialization() {
    if (!_initialized) {
      throw Exception(
          'CosmosEpub is not initialized. Please call initialize() before using other methods. For more info pls read the docs');
    }
  }

  static Future<bool> clearThemeCache() async {
    if (await GetStorage().initStorage) {
      var get = GetStorage();
      await get.remove(libTheme);
      await get.remove(libFont);
      await get.remove(libFontSize);
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> setCurrentPageIndex(String bookId, int index) async {
    return await bookProgress.setCurrentPageIndex(bookId, index);
  }

  static Future<bool> setCurrentChapterIndex(String bookId, int index) async {
    return await bookProgress.setCurrentChapterIndex(bookId, index);
  }

  static BookProgressModel getBookProgress(String bookId) {
    return bookProgress.getBookProgress(bookId);
  }

  static Future<bool> deleteBookProgress(String bookId) async {
    return await bookProgress.deleteBookProgress(bookId);
  }

  static Future<bool> deleteAllBooksProgress() async {
    return await bookProgress.deleteAllBooksProgress();
  }

  /// Called when app goes to background to release Isar file locks.
  /// This prevents iOS 0xdead10cc crash (holding file locks while suspended).
  static Future<void> onAppPaused() async {
    if (!_initialized) return;
    await IsarService.closeDatabase();
  }

  /// Called when app returns to foreground to reopen Isar database.
  static Future<void> onAppResumed() async {
    if (!_initialized) return;
    final singleton = await IsarService.reopenDatabase();
    if (singleton != null) {
      bookProgress = singleton;
    }
  }
}
