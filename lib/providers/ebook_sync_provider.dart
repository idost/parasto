import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/services/ebook_sync_service.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for EbookSyncService
final ebookSyncServiceProvider = Provider<EbookSyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EbookSyncService(client);
});

/// Provider for checking if user is logged in
final isEbookSyncAvailableProvider = Provider<bool>((ref) {
  final service = ref.watch(ebookSyncServiceProvider);
  return service.isLoggedIn;
});

/// Provider for fetching highlights for a specific book
final ebookHighlightsProvider = FutureProvider.family<List<HighlightModel>, String>(
  (ref, bookId) async {
    final service = ref.watch(ebookSyncServiceProvider);
    if (!service.isLoggedIn) return [];
    return service.fetchHighlights(bookId);
  },
);

/// Provider for fetching reading progress
final ebookProgressProvider = FutureProvider.family<EbookReadingProgress?, String>(
  (ref, bookId) async {
    final service = ref.watch(ebookSyncServiceProvider);
    if (!service.isLoggedIn) return null;
    return service.fetchProgress(bookId);
  },
);

/// Provider for fetching bookmarks
final ebookBookmarksProvider = FutureProvider.family<List<EbookBookmark>, String>(
  (ref, bookId) async {
    final service = ref.watch(ebookSyncServiceProvider);
    if (!service.isLoggedIn) return [];
    return service.fetchBookmarks(bookId);
  },
);

/// Notifier for managing highlight sync state
class HighlightSyncNotifier extends StateNotifier<HighlightSyncState> {
  final EbookSyncService _service;

  HighlightSyncNotifier(this._service) : super(const HighlightSyncState());

  /// Sync highlights for a book
  Future<List<HighlightModel>> syncHighlights(
    String bookId,
    List<HighlightModel> localHighlights,
  ) async {
    state = state.copyWith(isSyncing: true, error: null);

    try {
      final merged = await _service.syncHighlights(bookId, localHighlights);
      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
      );
      return merged;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
      return localHighlights;
    }
  }

  /// Upload a single highlight
  Future<bool> uploadHighlight(HighlightModel highlight) async {
    return _service.uploadHighlight(highlight);
  }

  /// Delete a highlight from remote
  Future<bool> deleteHighlight(String highlightId) async {
    return _service.deleteHighlight(highlightId);
  }
}

/// State for highlight sync
class HighlightSyncState {
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? error;

  const HighlightSyncState({
    this.isSyncing = false,
    this.lastSyncAt,
    this.error,
  });

  HighlightSyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? error,
  }) {
    return HighlightSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      error: error,
    );
  }
}

/// Provider for highlight sync notifier
final highlightSyncNotifierProvider =
    StateNotifierProvider<HighlightSyncNotifier, HighlightSyncState>((ref) {
  final service = ref.watch(ebookSyncServiceProvider);
  return HighlightSyncNotifier(service);
});

/// Notifier for managing reading progress sync
class ProgressSyncNotifier extends StateNotifier<EbookReadingProgress?> {
  final EbookSyncService _service;

  ProgressSyncNotifier(this._service) : super(null);

  /// Load progress from remote
  Future<void> loadProgress(String bookId) async {
    final progress = await _service.fetchProgress(bookId);
    state = progress;
  }

  /// Save progress to remote
  Future<bool> saveProgress(EbookReadingProgress progress) async {
    state = progress;
    return _service.saveProgress(progress);
  }

  /// Update progress locally and sync
  Future<void> updateProgress({
    required String bookId,
    required int chapterIndex,
    required int pageIndex,
    required double progressPercent,
    int additionalReadingTime = 0,
  }) async {
    final newProgress = EbookReadingProgress(
      id: state?.id,
      bookId: bookId,
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
      progressPercent: progressPercent,
      lastReadAt: DateTime.now(),
      totalReadingTimeSeconds:
          (state?.totalReadingTimeSeconds ?? 0) + additionalReadingTime,
    );

    state = newProgress;

    // Sync in background — fire-and-forget but log errors
    _service.saveProgress(newProgress).catchError((e) {
      AppLogger.e('Failed to sync ebook progress in background', error: e);
      return false;
    });
  }
}

/// Provider for progress sync notifier
final progressSyncNotifierProvider =
    StateNotifierProvider.family<ProgressSyncNotifier, EbookReadingProgress?, String>(
  (ref, bookId) {
    final service = ref.watch(ebookSyncServiceProvider);
    final notifier = ProgressSyncNotifier(service);
    // Load initial progress
    notifier.loadProgress(bookId);
    return notifier;
  },
);

/// Invalidate all ebook sync providers (call after auth changes)
void invalidateEbookSyncProviders(WidgetRef ref, String bookId) {
  ref.invalidate(ebookHighlightsProvider(bookId));
  ref.invalidate(ebookProgressProvider(bookId));
  ref.invalidate(ebookBookmarksProvider(bookId));
}
