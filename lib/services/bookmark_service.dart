import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// A bookmark represents a saved position in an audiobook chapter
class Bookmark {
  final String id;
  final String userId;
  final int audiobookId;
  final int chapterId;
  final int positionSeconds;
  final String? note;
  final DateTime createdAt;
  final String? chapterTitle;
  final String? audiobookTitle;

  Bookmark({
    required this.id,
    required this.userId,
    required this.audiobookId,
    required this.chapterId,
    required this.positionSeconds,
    this.note,
    required this.createdAt,
    this.chapterTitle,
    this.audiobookTitle,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      audiobookId: json['audiobook_id'] as int,
      chapterId: json['chapter_id'] as int,
      positionSeconds: json['position_seconds'] as int,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      chapterTitle: json['chapters']?['title_fa'] as String?,
      audiobookTitle: json['audiobooks']?['title_fa'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'audiobook_id': audiobookId,
    'chapter_id': chapterId,
    'position_seconds': positionSeconds,
    'note': note,
  };

  /// Format position as readable time
  String get formattedPosition {
    final hours = positionSeconds ~/ 3600;
    final minutes = (positionSeconds % 3600) ~/ 60;
    final seconds = positionSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Bookmark copyWith({
    String? id,
    String? userId,
    int? audiobookId,
    int? chapterId,
    int? positionSeconds,
    String? note,
    DateTime? createdAt,
    String? chapterTitle,
    String? audiobookTitle,
  }) {
    return Bookmark(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      audiobookId: audiobookId ?? this.audiobookId,
      chapterId: chapterId ?? this.chapterId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      audiobookTitle: audiobookTitle ?? this.audiobookTitle,
    );
  }
}

/// Service for managing audiobook bookmarks
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Create a new bookmark
  Future<Bookmark?> createBookmark({
    required int audiobookId,
    required int chapterId,
    required int positionSeconds,
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      AppLogger.w('Cannot create bookmark: user not logged in');
      return null;
    }

    try {
      final response = await _client
          .from('bookmarks')
          .insert({
            'user_id': user.id,
            'audiobook_id': audiobookId,
            'chapter_id': chapterId,
            'position_seconds': positionSeconds,
            'note': note,
          })
          .select('*, chapters(title_fa), audiobooks(title_fa)')
          .maybeSingle();

      if (response == null) {
        AppLogger.e('Bookmark insert returned null');
        return null;
      }
      AppLogger.i('Bookmark created at ${positionSeconds}s');
      return Bookmark.fromJson(response);
    } catch (e) {
      AppLogger.e('Error creating bookmark', error: e);
      return null;
    }
  }

  /// Get all bookmarks for an audiobook
  Future<List<Bookmark>> getBookmarksForAudiobook(int audiobookId) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('bookmarks')
          .select('*, chapters(title_fa), audiobooks(title_fa)')
          .eq('user_id', user.id)
          .eq('audiobook_id', audiobookId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching bookmarks for audiobook', error: e);
      return [];
    }
  }

  /// Get all bookmarks for the current user
  Future<List<Bookmark>> getAllBookmarks() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('bookmarks')
          .select('*, chapters(title_fa), audiobooks(title_fa)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching all bookmarks', error: e);
      return [];
    }
  }

  /// Update a bookmark's note
  Future<bool> updateBookmarkNote(String bookmarkId, String? note) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('bookmarks')
          .update({'note': note})
          .eq('id', bookmarkId)
          .eq('user_id', user.id);

      AppLogger.i('Bookmark note updated');
      return true;
    } catch (e) {
      AppLogger.e('Error updating bookmark note', error: e);
      return false;
    }
  }

  /// Delete a bookmark
  Future<bool> deleteBookmark(String bookmarkId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('bookmarks')
          .delete()
          .eq('id', bookmarkId)
          .eq('user_id', user.id);

      AppLogger.i('Bookmark deleted');
      return true;
    } catch (e) {
      AppLogger.e('Error deleting bookmark', error: e);
      return false;
    }
  }

  /// Delete all bookmarks for an audiobook
  Future<bool> deleteAllBookmarksForAudiobook(int audiobookId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('bookmarks')
          .delete()
          .eq('user_id', user.id)
          .eq('audiobook_id', audiobookId);

      AppLogger.i('All bookmarks deleted for audiobook $audiobookId');
      return true;
    } catch (e) {
      AppLogger.e('Error deleting bookmarks for audiobook', error: e);
      return false;
    }
  }

  /// Check if a bookmark exists near a position (within 30 seconds)
  Future<Bookmark?> findNearbyBookmark({
    required int audiobookId,
    required int chapterId,
    required int positionSeconds,
    int toleranceSeconds = 30,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('bookmarks')
          .select('*, chapters(title_fa), audiobooks(title_fa)')
          .eq('user_id', user.id)
          .eq('audiobook_id', audiobookId)
          .eq('chapter_id', chapterId)
          .gte('position_seconds', positionSeconds - toleranceSeconds)
          .lte('position_seconds', positionSeconds + toleranceSeconds)
          .limit(1);

      if ((response as List).isNotEmpty) {
        return Bookmark.fromJson(response.first);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error finding nearby bookmark', error: e);
      return null;
    }
  }
}
