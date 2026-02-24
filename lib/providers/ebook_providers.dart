import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/services/ebook_service.dart';
import 'package:myna/services/access_gate_service.dart';
import 'package:myna/services/subscription_service.dart';
import 'package:myna/models/ebook.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/app_strings.dart';

// ============================================
// EBOOK CATALOG PROVIDERS
// ============================================

/// Cache for featured ebooks
List<Map<String, dynamic>>? _ebookFeaturedCache;
DateTime? _ebookFeaturedCacheTime;
const _ebookCacheDuration = Duration(minutes: 5);

/// Provider for featured ebooks on ebooks screen
final ebookFeaturedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_ebookFeaturedCache != null && _ebookFeaturedCacheTime != null) {
    final elapsed = DateTime.now().difference(_ebookFeaturedCacheTime!);
    if (elapsed < _ebookCacheDuration) {
      return _ebookFeaturedCache!;
    }
  }

  try {
    final result = await EbookService().getFeaturedEbooks();
    _ebookFeaturedCache = result;
    _ebookFeaturedCacheTime = DateTime.now();
    return result;
  } catch (e) {
    AppLogger.e('Error fetching featured ebooks', error: e);
    rethrow;
  }
});

/// Provider for new ebook releases
final ebookNewReleasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await EbookService().getNewReleases();
  } catch (e) {
    AppLogger.e('Error fetching new ebooks', error: e);
    rethrow;
  }
});

/// Provider for popular ebooks
final ebookPopularProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await EbookService().getPopularEbooks();
  } catch (e) {
    AppLogger.e('Error fetching popular ebooks', error: e);
    rethrow;
  }
});

/// Provider for all approved ebooks
final ebookAllProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('ebooks')
        .select('''
          id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
          page_count, read_count, status, epub_storage_path,
          categories(name_fa)
        ''')
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching all ebooks', error: e);
    rethrow;
  }
});

/// Provider for ebook details by ID
final ebookDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, ebookId) async {
  return await EbookService().getEbookDetails(ebookId);
});

/// Provider for ebooks by category
final ebooksByCategoryProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, categoryId) async {
  return await EbookService().getEbooksByCategory(categoryId);
});

// ============================================
// USER LIBRARY PROVIDERS
// ============================================

/// Provider for user's owned ebooks
final ownedEbooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await EbookService().getOwnedEbooks();
});

/// Provider for continue reading ebooks
final ebookContinueReadingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return await EbookService().getContinueReading();
});

/// Provider for checking ebook ownership
final ebookOwnershipProvider = FutureProvider.family<bool, int>((ref, ebookId) async {
  return await EbookService().isEbookOwned(ebookId);
});

// ============================================
// READING PROGRESS PROVIDERS
// ============================================

/// Provider for reading progress of a specific ebook
final readingProgressProvider = FutureProvider.family<ReadingProgress?, int>((ref, ebookId) async {
  return await EbookService().getReadingProgress(ebookId);
});

// ============================================
// EBOOK READER STATE
// ============================================

/// Reading settings state
class EbookReaderSettings {
  final double fontSize;
  final String fontFamily;
  final String theme; // 'dark', 'light', 'sepia', 'grey', 'purple', 'pink', 'black'
  final double brightness;
  final double lineHeight;

  const EbookReaderSettings({
    this.fontSize = 18.0,
    this.fontFamily = 'Vazirmatn',
    this.theme = 'dark',
    this.brightness = 0.8,
    this.lineHeight = 1.5,
  });

  EbookReaderSettings copyWith({
    double? fontSize,
    String? fontFamily,
    String? theme,
    double? brightness,
    double? lineHeight,
  }) {
    return EbookReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
      brightness: brightness ?? this.brightness,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

/// Provider for ebook reader settings
final ebookReaderSettingsProvider = StateNotifierProvider<EbookReaderSettingsNotifier, EbookReaderSettings>((ref) {
  return EbookReaderSettingsNotifier();
});

class EbookReaderSettingsNotifier extends StateNotifier<EbookReaderSettings> {
  EbookReaderSettingsNotifier() : super(const EbookReaderSettings());

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(12.0, 32.0));
  }

  void increaseFontSize() {
    setFontSize(state.fontSize + 2);
  }

  void decreaseFontSize() {
    setFontSize(state.fontSize - 2);
  }

  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
  }

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
  }

  void setBrightness(double brightness) {
    state = state.copyWith(brightness: brightness.clamp(0.1, 1.0));
  }

  void setLineHeight(double height) {
    state = state.copyWith(lineHeight: height.clamp(1.0, 2.5));
  }
}

// ============================================
// EBOOK READER STATE (Active Reading Session)
// ============================================

/// State for active ebook reading session
class EbookReaderState {
  final Map<String, dynamic>? ebook;
  final int currentChapterIndex;
  final int totalChapters;
  final double completionPercentage;
  final bool isLoading;
  final bool isOwned;
  final String? localFilePath;
  final String? errorMessage;
  final List<EbookBookmark> bookmarks;
  final DateTime? sessionStartTime;

  const EbookReaderState({
    this.ebook,
    this.currentChapterIndex = 0,
    this.totalChapters = 0,
    this.completionPercentage = 0.0,
    this.isLoading = false,
    this.isOwned = false,
    this.localFilePath,
    this.errorMessage,
    this.bookmarks = const [],
    this.sessionStartTime,
  });

  EbookReaderState copyWith({
    Map<String, dynamic>? ebook,
    int? currentChapterIndex,
    int? totalChapters,
    double? completionPercentage,
    bool? isLoading,
    bool? isOwned,
    String? localFilePath,
    String? errorMessage,
    List<EbookBookmark>? bookmarks,
    DateTime? sessionStartTime,
  }) {
    return EbookReaderState(
      ebook: ebook ?? this.ebook,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      totalChapters: totalChapters ?? this.totalChapters,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      isLoading: isLoading ?? this.isLoading,
      isOwned: isOwned ?? this.isOwned,
      localFilePath: localFilePath ?? this.localFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      bookmarks: bookmarks ?? this.bookmarks,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    );
  }

  /// Get unique book ID for CosmosEpub
  String get cosmosBookId => 'parasto_ebook_${ebook?['id'] ?? 0}';
}

/// Provider for active ebook reading state
final ebookReaderProvider = StateNotifierProvider<EbookReaderNotifier, EbookReaderState>((ref) {
  return EbookReaderNotifier(ref);
});

class EbookReaderNotifier extends StateNotifier<EbookReaderState> {
  final Ref ref;
  final EbookService _service = EbookService();

  EbookReaderNotifier(this.ref) : super(const EbookReaderState());

  /// Load an ebook for reading
  Future<bool> loadEbook(Map<String, dynamic> ebook) async {
    final ebookId = ebook['id'] as int;
    AppLogger.d('loadEbook() called for id: $ebookId');

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      ebook: ebook,
    );

    try {
      // Fetch fresh ebook details to ensure we have all required fields
      AppLogger.d('Fetching fresh ebook details...');
      final freshEbook = await _service.getEbookDetails(ebookId);
      if (freshEbook == null) {
        AppLogger.e('Could not fetch ebook details for $ebookId');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'خطا در بارگذاری اطلاعات کتاب',
        );
        return false;
      }
      AppLogger.d('Fresh ebook loaded: ${freshEbook['title_fa']}');

      // Update state with fresh ebook data
      state = state.copyWith(ebook: freshEbook);

      // Check ownership
      AppLogger.d('Checking ownership...');
      final isOwned = await _service.isEbookOwned(ebookId);
      AppLogger.d('isOwned: $isOwned, is_free: ${freshEbook['is_free']}');

      // ── Access Gate check ──────────────────────────────────────
      final subService = SubscriptionService();
      final subStatus = await subService.getSubscriptionStatus();
      final accessResult = AccessGateService.checkAccess(
        isOwned: isOwned,
        isFree: freshEbook['is_free'] == true,
        isSubscriptionActive: subStatus.isActive,
        isSubscriptionAvailable: subService.isSubscriptionAvailable,
      );

      if (!accessResult.canAccess) {
        final message = accessResult.needsSubscription
            ? AppStrings.subscriptionExpiredLockMessage
            : 'برای خواندن این کتاب باید آن را خریداری کنید';
        AppLogger.d('Access denied: ${accessResult.type}');
        state = state.copyWith(
          isLoading: false,
          isOwned: false,
          errorMessage: message,
        );
        return false;
      }

      // If free + access granted but no entitlement row yet, auto-claim
      if (!isOwned && freshEbook['is_free'] == true) {
        AppLogger.d('Claiming free ebook...');
        await _service.claimFreeEbook(ebookId);
      }

      // Get local file path or download
      AppLogger.d('Getting local file path...');
      String? localPath = await _service.getLocalEbookPath(ebookId);
      AppLogger.d('Local path: $localPath');
      if (localPath == null) {
        final epubPath = freshEbook['epub_storage_path'] as String?;
        AppLogger.d('epub_storage_path: $epubPath');
        if (epubPath == null || epubPath.isEmpty) {
          AppLogger.e('No epub_storage_path for ebook $ebookId, data: $freshEbook');
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'فایل کتاب در سرور موجود نیست',
          );
          return false;
        }
        AppLogger.d('Downloading ebook...');
        localPath = await _service.downloadEbook(ebookId, epubPath);
        AppLogger.d('Downloaded to: $localPath');
      }

      if (localPath == null) {
        AppLogger.e('localPath is null after download attempt');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'خطا در دانلود کتاب. لطفاً اتصال اینترنت خود را بررسی کنید.',
        );
        return false;
      }

      // Load bookmarks
      final bookmarks = await _service.getBookmarks(ebookId);

      // Get existing progress
      final progress = await _service.getReadingProgress(ebookId);

      // Increment read count
      _service.incrementReadCount(ebookId);

      state = state.copyWith(
        isLoading: false,
        isOwned: true,
        localFilePath: localPath,
        bookmarks: bookmarks,
        currentChapterIndex: progress?.currentChapterIndex ?? 0,
        completionPercentage: progress?.completionPercentage ?? 0.0,
        sessionStartTime: DateTime.now(),
      );

      AppLogger.i('Ebook loaded: ${freshEbook['title_fa']}, path: $localPath');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error loading ebook: $e', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'خطا در بارگذاری کتاب: $e',
      );
      return false;
    }
  }

  /// Update reading progress
  Future<void> updateProgress({
    required int chapterIndex,
    String? cfiPosition,
    required double scrollPercentage,
    required double completionPercentage,
  }) async {
    final ebookId = state.ebook?['id'] as int?;
    if (ebookId == null) return;

    state = state.copyWith(
      currentChapterIndex: chapterIndex,
      completionPercentage: completionPercentage,
    );

    // Calculate read time since session start
    int additionalSeconds = 0;
    if (state.sessionStartTime != null) {
      additionalSeconds = DateTime.now().difference(state.sessionStartTime!).inSeconds;
    }

    await _service.saveReadingProgress(
      ebookId: ebookId,
      chapterIndex: chapterIndex,
      cfiPosition: cfiPosition,
      scrollPercentage: scrollPercentage,
      completionPercentage: completionPercentage,
      additionalReadTimeSeconds: additionalSeconds,
    );

    // Reset session timer
    state = state.copyWith(sessionStartTime: DateTime.now());
  }

  /// Add a bookmark
  Future<void> addBookmark({
    required int chapterIndex,
    String? cfiPosition,
    String? highlightedText,
    String? note,
    String? color,
  }) async {
    final ebookId = state.ebook?['id'] as int?;
    if (ebookId == null) return;

    final bookmark = await _service.createBookmark(
      ebookId: ebookId,
      chapterIndex: chapterIndex,
      cfiPosition: cfiPosition,
      highlightedText: highlightedText,
      note: note,
      color: color,
    );

    if (bookmark != null) {
      state = state.copyWith(
        bookmarks: [bookmark, ...state.bookmarks],
      );
    }
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String bookmarkId) async {
    final success = await _service.deleteBookmark(bookmarkId);
    if (success) {
      state = state.copyWith(
        bookmarks: state.bookmarks.where((b) => b.id != bookmarkId).toList(),
      );
    }
  }

  /// Set total chapters (called from reader)
  void setTotalChapters(int count) {
    state = state.copyWith(totalChapters: count);
  }

  /// Close the reader
  void closeReader() {
    // Save final progress before closing
    if (state.ebook != null && state.sessionStartTime != null) {
      final additionalSeconds = DateTime.now().difference(state.sessionStartTime!).inSeconds;
      _service.saveReadingProgress(
        ebookId: state.ebook!['id'] as int,
        chapterIndex: state.currentChapterIndex,
        scrollPercentage: state.completionPercentage,
        completionPercentage: state.completionPercentage,
        additionalReadTimeSeconds: additionalSeconds,
      );
    }

    state = const EbookReaderState();
  }
}

// ============================================
// DOWNLOAD STATE PROVIDERS
// ============================================

/// Provider for checking if an ebook is downloaded
final ebookDownloadedProvider = FutureProvider.family<bool, int>((ref, ebookId) async {
  return await EbookService().isEbookDownloaded(ebookId);
});

/// Provider for total downloaded ebooks size
final ebookDownloadsSizeProvider = FutureProvider<int>((ref) async {
  return await EbookService().getDownloadedEbooksSize();
});

// ============================================
// READING STATISTICS PROVIDERS
// ============================================

/// Reading statistics for profile page
class ReadingStats {
  final int totalReadTimeSeconds;
  final int daysReading;
  final int currentStreak;
  final int longestStreak;
  final int booksCompleted;

  const ReadingStats({
    this.totalReadTimeSeconds = 0,
    this.daysReading = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.booksCompleted = 0,
  });

  int get totalMinutes => totalReadTimeSeconds ~/ 60;
  int get totalHours => totalReadTimeSeconds ~/ 3600;
}

/// Provider for user reading statistics
final readingStatsProvider = FutureProvider<ReadingStats>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const ReadingStats();

  try {
    final response = await Supabase.instance.client
        .from('reading_progress')
        .select('total_read_time_seconds, completion_percentage')
        .eq('user_id', user.id);

    int totalTime = 0;
    int completed = 0;

    for (final record in response as List) {
      totalTime += (record['total_read_time_seconds'] as num?)?.toInt() ?? 0;
      final completion = (record['completion_percentage'] as num?)?.toDouble() ?? 0;
      if (completion >= 100) {
        completed++;
      }
    }

    return ReadingStats(
      totalReadTimeSeconds: totalTime,
      booksCompleted: completed,
    );
  } catch (e) {
    AppLogger.e('Error fetching reading stats', error: e);
    return const ReadingStats();
  }
});

// ============================================
// INVALIDATION
// ============================================

/// Invalidate all ebook-related providers
void invalidateEbookProviders(WidgetRef ref) {
  _ebookFeaturedCache = null;
  _ebookFeaturedCacheTime = null;

  ref.invalidate(ebookFeaturedProvider);
  ref.invalidate(ebookNewReleasesProvider);
  ref.invalidate(ebookPopularProvider);
  ref.invalidate(ebookAllProvider);
  ref.invalidate(ownedEbooksProvider);
  ref.invalidate(ebookContinueReadingProvider);
  ref.invalidate(readingStatsProvider);
}
