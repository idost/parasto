import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for syncing EPUB highlights, bookmarks, and reading progress with Supabase
/// Follows local-first pattern: changes saved locally immediately, synced in background
class EbookSyncService {
  final SupabaseClient _client;

  EbookSyncService(this._client);

  // ============================================================================
  // HIGHLIGHTS
  // ============================================================================

  /// Fetch all highlights for a book from Supabase
  Future<List<HighlightModel>> fetchHighlights(String bookId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('ebook_highlights')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HighlightModel.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Failed to fetch highlights', error: e);
      return [];
    }
  }

  /// Upload a single highlight to Supabase
  Future<bool> uploadHighlight(HighlightModel highlight) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final data = highlight.toSupabase();
      data['user_id'] = userId;

      await _client.from('ebook_highlights').upsert(data);
      return true;
    } catch (e) {
      AppLogger.e('Failed to upload highlight', error: e);
      return false;
    }
  }

  /// Delete a highlight from Supabase
  Future<bool> deleteHighlight(String highlightId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('ebook_highlights')
          .delete()
          .eq('id', highlightId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      AppLogger.e('Failed to delete highlight', error: e);
      return false;
    }
  }

  /// Sync local highlights with Supabase
  /// Returns list of merged highlights
  Future<List<HighlightModel>> syncHighlights(
    String bookId,
    List<HighlightModel> localHighlights,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return localHighlights;

      // Fetch remote highlights
      final remoteHighlights = await fetchHighlights(bookId);

      // Build maps for merging
      final localMap = {for (final h in localHighlights) h.id: h};
      final remoteMap = {for (final h in remoteHighlights) h.id: h};

      final merged = <HighlightModel>[];
      final toUpload = <HighlightModel>[];

      // Process local highlights
      for (final local in localHighlights) {
        final remote = remoteMap[local.id];

        if (remote == null) {
          // Local only - upload to remote
          if (local.isPendingSync) {
            toUpload.add(local.copyWith(userId: userId));
          }
          merged.add(local.copyWith(userId: userId).markSynced());
        } else {
          // Exists in both - resolve conflict by timestamp
          final localTime = local.updatedAt ?? local.createdAt;
          final remoteTime = remote.updatedAt ?? remote.createdAt;

          if (local.isPendingSync && localTime.isAfter(remoteTime)) {
            // Local is newer - use local and upload
            toUpload.add(local.copyWith(userId: userId));
            merged.add(local.copyWith(userId: userId).markSynced());
          } else {
            // Remote is newer or same - use remote
            merged.add(remote);
          }
        }
      }

      // Process remote-only highlights
      for (final remote in remoteHighlights) {
        if (!localMap.containsKey(remote.id)) {
          merged.add(remote);
        }
      }

      // Upload pending changes
      for (final highlight in toUpload) {
        await uploadHighlight(highlight);
      }

      return merged;
    } catch (e) {
      AppLogger.e('Failed to sync highlights', error: e);
      return localHighlights;
    }
  }

  // ============================================================================
  // READING PROGRESS
  // ============================================================================

  /// Fetch reading progress for a book
  Future<EbookReadingProgress?> fetchProgress(String bookId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('ebook_reading_progress')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      if (response == null) return null;
      return EbookReadingProgress.fromSupabase(response);
    } catch (e) {
      AppLogger.e('Failed to fetch progress', error: e);
      return null;
    }
  }

  /// Save reading progress
  Future<bool> saveProgress(EbookReadingProgress progress) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final data = progress.toSupabase();
      data['user_id'] = userId;

      await _client.from('ebook_reading_progress').upsert(data);
      return true;
    } catch (e) {
      AppLogger.e('Failed to save progress', error: e);
      return false;
    }
  }

  // ============================================================================
  // BOOKMARKS
  // ============================================================================

  /// Fetch bookmarks for a book
  Future<List<EbookBookmark>> fetchBookmarks(String bookId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('ebook_bookmarks')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EbookBookmark.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Failed to fetch bookmarks', error: e);
      return [];
    }
  }

  /// Add a bookmark
  Future<bool> addBookmark(EbookBookmark bookmark) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final data = bookmark.toSupabase();
      data['user_id'] = userId;

      await _client.from('ebook_bookmarks').upsert(data);
      return true;
    } catch (e) {
      AppLogger.e('Failed to add bookmark', error: e);
      return false;
    }
  }

  /// Delete a bookmark
  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('ebook_bookmarks')
          .delete()
          .eq('id', bookmarkId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      AppLogger.e('Failed to delete bookmark', error: e);
      return false;
    }
  }

  /// Check if user is logged in
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Get current user ID
  String? get userId => _client.auth.currentUser?.id;
}

// ============================================================================
// MODELS
// ============================================================================

/// E-book reading progress model
class EbookReadingProgress {
  final String? id;
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final double progressPercent;
  final DateTime lastReadAt;
  final int totalReadingTimeSeconds;

  EbookReadingProgress({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.progressPercent,
    required this.lastReadAt,
    this.totalReadingTimeSeconds = 0,
  });

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'page_index': pageIndex,
      'progress_percent': progressPercent,
      'last_read_at': lastReadAt.toIso8601String(),
      'total_reading_time_seconds': totalReadingTimeSeconds,
    };
  }

  factory EbookReadingProgress.fromSupabase(Map<String, dynamic> json) {
    return EbookReadingProgress(
      id: json['id'] as String?,
      bookId: json['book_id'] as String,
      chapterIndex: json['chapter_index'] as int? ?? 0,
      pageIndex: json['page_index'] as int? ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0,
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
      totalReadingTimeSeconds: json['total_reading_time_seconds'] as int? ?? 0,
    );
  }

  EbookReadingProgress copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    int? pageIndex,
    double? progressPercent,
    DateTime? lastReadAt,
    int? totalReadingTimeSeconds,
  }) {
    return EbookReadingProgress(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      progressPercent: progressPercent ?? this.progressPercent,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      totalReadingTimeSeconds: totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
    );
  }
}

/// E-book bookmark model
class EbookBookmark {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final String? note;
  final DateTime createdAt;

  EbookBookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'page_index': pageIndex,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EbookBookmark.fromSupabase(Map<String, dynamic> json) {
    return EbookBookmark(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      chapterIndex: json['chapter_index'] as int,
      pageIndex: json['page_index'] as int,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String generateId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch.toRadixString(16)}-${now.microsecondsSinceEpoch.toRadixString(16)}';
  }
}
