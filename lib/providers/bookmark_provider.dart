import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/services/bookmark_service.dart';

/// State for bookmarks
class BookmarkState {
  final List<Bookmark> bookmarks;
  final bool isLoading;
  final String? error;
  final Bookmark? lastCreated;

  const BookmarkState({
    this.bookmarks = const [],
    this.isLoading = false,
    this.error,
    this.lastCreated,
  });

  BookmarkState copyWith({
    List<Bookmark>? bookmarks,
    bool? isLoading,
    String? error,
    Bookmark? lastCreated,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastCreated: lastCreated ?? this.lastCreated,
    );
  }

  /// Get bookmarks for a specific audiobook
  List<Bookmark> forAudiobook(int audiobookId) {
    return bookmarks.where((b) => b.audiobookId == audiobookId).toList();
  }

  /// Get bookmarks for a specific chapter
  List<Bookmark> forChapter(int audiobookId, int chapterId) {
    return bookmarks
        .where((b) => b.audiobookId == audiobookId && b.chapterId == chapterId)
        .toList();
  }

  /// Check if there's a bookmark near a position
  bool hasBookmarkNear(int audiobookId, int chapterId, int positionSeconds, {int tolerance = 30}) {
    return bookmarks.any((b) =>
        b.audiobookId == audiobookId &&
        b.chapterId == chapterId &&
        (b.positionSeconds - positionSeconds).abs() <= tolerance);
  }
}

/// Notifier for managing bookmarks
class BookmarkNotifier extends StateNotifier<BookmarkState> {
  final BookmarkService _service = BookmarkService();
  int? _currentAudiobookId;

  BookmarkNotifier() : super(const BookmarkState());

  /// Load bookmarks for a specific audiobook
  Future<void> loadBookmarks(int audiobookId) async {
    if (_currentAudiobookId == audiobookId && state.bookmarks.isNotEmpty) {
      return; // Already loaded
    }

    state = state.copyWith(isLoading: true, error: null);
    _currentAudiobookId = audiobookId;

    final bookmarks = await _service.getBookmarksForAudiobook(audiobookId);
    state = state.copyWith(bookmarks: bookmarks, isLoading: false);
  }

  /// Load all bookmarks for the user
  Future<void> loadAllBookmarks() async {
    state = state.copyWith(isLoading: true, error: null);
    _currentAudiobookId = null;

    final bookmarks = await _service.getAllBookmarks();
    state = state.copyWith(bookmarks: bookmarks, isLoading: false);
  }

  /// Create a new bookmark
  Future<Bookmark?> createBookmark({
    required int audiobookId,
    required int chapterId,
    required int positionSeconds,
    String? note,
  }) async {
    final bookmark = await _service.createBookmark(
      audiobookId: audiobookId,
      chapterId: chapterId,
      positionSeconds: positionSeconds,
      note: note,
    );

    if (bookmark != null) {
      state = state.copyWith(
        bookmarks: [bookmark, ...state.bookmarks],
        lastCreated: bookmark,
      );
    }

    return bookmark;
  }

  /// Toggle bookmark at position (create if doesn't exist, delete if exists)
  Future<bool> toggleBookmark({
    required int audiobookId,
    required int chapterId,
    required int positionSeconds,
  }) async {
    // Check if a bookmark exists near this position
    final nearbyBookmark = await _service.findNearbyBookmark(
      audiobookId: audiobookId,
      chapterId: chapterId,
      positionSeconds: positionSeconds,
    );

    if (nearbyBookmark != null) {
      // Remove existing bookmark
      final success = await _service.deleteBookmark(nearbyBookmark.id);
      if (success) {
        state = state.copyWith(
          bookmarks: state.bookmarks.where((b) => b.id != nearbyBookmark.id).toList(),
        );
      }
      return false; // Bookmark was removed
    } else {
      // Create new bookmark
      final bookmark = await createBookmark(
        audiobookId: audiobookId,
        chapterId: chapterId,
        positionSeconds: positionSeconds,
      );
      return bookmark != null; // Bookmark was created
    }
  }

  /// Update bookmark note
  Future<bool> updateNote(String bookmarkId, String? note) async {
    final success = await _service.updateBookmarkNote(bookmarkId, note);
    if (success) {
      state = state.copyWith(
        bookmarks: state.bookmarks.map((b) {
          if (b.id == bookmarkId) {
            return b.copyWith(note: note);
          }
          return b;
        }).toList(),
      );
    }
    return success;
  }

  /// Delete a bookmark
  Future<bool> deleteBookmark(String bookmarkId) async {
    final success = await _service.deleteBookmark(bookmarkId);
    if (success) {
      state = state.copyWith(
        bookmarks: state.bookmarks.where((b) => b.id != bookmarkId).toList(),
      );
    }
    return success;
  }

  /// Delete all bookmarks for an audiobook
  Future<bool> deleteAllForAudiobook(int audiobookId) async {
    final success = await _service.deleteAllBookmarksForAudiobook(audiobookId);
    if (success) {
      state = state.copyWith(
        bookmarks: state.bookmarks.where((b) => b.audiobookId != audiobookId).toList(),
      );
    }
    return success;
  }

  /// Clear state (e.g., on logout)
  void clear() {
    _currentAudiobookId = null;
    state = const BookmarkState();
  }
}

/// Provider for bookmark state
final bookmarkProvider = StateNotifierProvider<BookmarkNotifier, BookmarkState>((ref) {
  return BookmarkNotifier();
});

/// Provider to check if current position has a bookmark
final hasBookmarkAtPositionProvider = Provider.family<bool, ({int audiobookId, int chapterId, int positionSeconds})>((ref, params) {
  final state = ref.watch(bookmarkProvider);
  return state.hasBookmarkNear(
    params.audiobookId,
    params.chapterId,
    params.positionSeconds,
  );
});
