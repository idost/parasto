import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/ebook.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for managing ebook operations
class EbookService {
  static final EbookService _instance = EbookService._internal();
  factory EbookService() => _instance;
  EbookService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  final Dio _dio = Dio();

  // ============================================
  // EBOOK CATALOG
  // ============================================

  /// Get featured ebooks
  Future<List<Map<String, dynamic>>> getFeaturedEbooks({int limit = 10}) async {
    try {
      final response = await _client
          .from('ebooks')
          .select('''
            id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
            page_count, read_count, is_featured, status, epub_storage_path,
            categories(name_fa)
          ''')
          .eq('status', 'approved')
          .eq('is_featured', true)
          .order('read_count', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.e('Error fetching featured ebooks', error: e);
      rethrow;
    }
  }

  /// Get new ebook releases
  Future<List<Map<String, dynamic>>> getNewReleases({int limit = 10}) async {
    try {
      final response = await _client
          .from('ebooks')
          .select('''
            id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
            page_count, read_count, status, epub_storage_path,
            categories(name_fa)
          ''')
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.e('Error fetching new ebooks', error: e);
      rethrow;
    }
  }

  /// Get popular ebooks
  Future<List<Map<String, dynamic>>> getPopularEbooks({int limit = 10}) async {
    try {
      final response = await _client
          .from('ebooks')
          .select('''
            id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
            page_count, read_count, status, epub_storage_path,
            categories(name_fa)
          ''')
          .eq('status', 'approved')
          .order('read_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.e('Error fetching popular ebooks', error: e);
      rethrow;
    }
  }

  /// Get ebooks by category
  Future<List<Map<String, dynamic>>> getEbooksByCategory(int categoryId, {int limit = 20}) async {
    try {
      final response = await _client
          .from('ebooks')
          .select('''
            id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
            page_count, read_count, status, epub_storage_path,
            categories(name_fa)
          ''')
          .eq('status', 'approved')
          .eq('category_id', categoryId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.e('Error fetching ebooks by category', error: e);
      rethrow;
    }
  }

  /// Get single ebook details
  Future<Map<String, dynamic>?> getEbookDetails(int ebookId) async {
    try {
      final response = await _client
          .from('ebooks')
          .select('''
            *,
            categories(name_fa, name_en)
          ''')
          .eq('id', ebookId)
          .maybeSingle();
      return response;
    } catch (e) {
      AppLogger.e('Error fetching ebook details', error: e);
      return null;
    }
  }

  /// Get a valid cover URL (generates signed URL if needed)
  Future<String?> getCoverUrl(String? coverUrl, String? coverStoragePath) async {
    // If we have a valid signed URL, use it
    if (coverUrl != null && coverUrl.contains('token=')) {
      return coverUrl;
    }

    // If we have a storage path, generate a signed URL
    if (coverStoragePath != null && coverStoragePath.isNotEmpty) {
      try {
        final signedUrl = await _client.storage
            .from('ebook-files')
            .createSignedUrl(coverStoragePath, 3600); // 1 hour
        return signedUrl;
      } catch (e) {
        AppLogger.w('Failed to generate signed URL for cover', error: e);
      }
    }

    // Fallback to original URL (might be a public URL)
    return coverUrl;
  }

  // ============================================
  // OWNERSHIP & ENTITLEMENTS
  // ============================================

  /// Check if user owns an ebook
  Future<bool> isEbookOwned(int ebookId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _client
          .from('ebook_entitlements')
          .select('id')
          .eq('user_id', user.id)
          .eq('ebook_id', ebookId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      AppLogger.e('Error checking ebook ownership', error: e);
      return false;
    }
  }

  /// Claim free ebook
  Future<bool> claimFreeEbook(int ebookId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      AppLogger.e('Cannot claim ebook: user not authenticated');
      return false;
    }

    try {
      AppLogger.i('Claiming free ebook $ebookId for user ${user.id}');
      await _client.from('ebook_entitlements').insert({
        'user_id': user.id,
        'ebook_id': ebookId,
        'source': 'free',
      });
      AppLogger.i('Free ebook claimed successfully: $ebookId');
      return true;
    } catch (e, stackTrace) {
      // Check if already owned (duplicate key error)
      if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        AppLogger.i('Ebook $ebookId already claimed by user');
        return true;
      }
      AppLogger.e('Error claiming free ebook $ebookId', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get user's owned ebooks
  Future<List<Map<String, dynamic>>> getOwnedEbooks() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('ebook_entitlements')
          .select('''
            ebook_id,
            ebooks(
              id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
              page_count, status, epub_storage_path
            )
          ''')
          .eq('user_id', user.id);

      return (response as List)
          .where((item) => item['ebooks'] != null)
          .map((item) => Map<String, dynamic>.from(item['ebooks'] as Map))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching owned ebooks', error: e);
      return [];
    }
  }

  // ============================================
  // READING PROGRESS
  // ============================================

  /// Get reading progress for an ebook
  Future<ReadingProgress?> getReadingProgress(int ebookId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('reading_progress')
          .select('*')
          .eq('user_id', user.id)
          .eq('ebook_id', ebookId)
          .maybeSingle();

      if (response == null) return null;
      return ReadingProgress.fromJson(response);
    } catch (e) {
      AppLogger.e('Error fetching reading progress', error: e);
      return null;
    }
  }

  /// Save reading progress
  Future<bool> saveReadingProgress({
    required int ebookId,
    required int chapterIndex,
    String? cfiPosition,
    required double scrollPercentage,
    required double completionPercentage,
    int? additionalReadTimeSeconds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      // Get existing progress to accumulate read time
      final existing = await getReadingProgress(ebookId);
      final totalReadTime = (existing?.totalReadTimeSeconds ?? 0) +
          (additionalReadTimeSeconds ?? 0);

      await _client.from('reading_progress').upsert({
        'user_id': user.id,
        'ebook_id': ebookId,
        'current_chapter_index': chapterIndex,
        'cfi_position': cfiPosition,
        'scroll_percentage': scrollPercentage,
        'completion_percentage': completionPercentage,
        'total_read_time_seconds': totalReadTime,
        'last_read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,ebook_id');

      AppLogger.d('Reading progress saved: ebook=$ebookId, chapter=$chapterIndex, completion=$completionPercentage%');
      return true;
    } catch (e) {
      AppLogger.e('Error saving reading progress', error: e);
      return false;
    }
  }

  /// Get continue reading ebooks (incomplete books sorted by last read)
  Future<List<Map<String, dynamic>>> getContinueReading({int limit = 5}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('reading_progress')
          .select('''
            ebook_id, completion_percentage, last_read_at, current_chapter_index,
            ebooks(
              id, title_fa, title_en, cover_url, cover_storage_path, is_free, author_fa,
              page_count, status, epub_storage_path
            )
          ''')
          .eq('user_id', user.id)
          .lt('completion_percentage', 100)
          .order('last_read_at', ascending: false)
          .limit(limit);

      return (response as List)
          .where((item) => item['ebooks'] != null && item['ebooks']['status'] == 'approved')
          .map((item) {
            final ebook = Map<String, dynamic>.from(item['ebooks'] as Map);
            ebook['progress'] = {
              'completion_percentage': item['completion_percentage'],
              'current_chapter_index': item['current_chapter_index'],
              'last_read_at': item['last_read_at'],
            };
            return ebook;
          })
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching continue reading', error: e);
      return [];
    }
  }

  // ============================================
  // BOOKMARKS
  // ============================================

  /// Get bookmarks for an ebook
  Future<List<EbookBookmark>> getBookmarks(int ebookId) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('ebook_bookmarks')
          .select('*')
          .eq('user_id', user.id)
          .eq('ebook_id', ebookId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EbookBookmark.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching ebook bookmarks', error: e);
      return [];
    }
  }

  /// Create a bookmark
  Future<EbookBookmark?> createBookmark({
    required int ebookId,
    required int chapterIndex,
    String? cfiPosition,
    String? highlightedText,
    String? note,
    String? color,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('ebook_bookmarks')
          .insert({
            'user_id': user.id,
            'ebook_id': ebookId,
            'chapter_index': chapterIndex,
            'cfi_position': cfiPosition,
            'highlighted_text': highlightedText,
            'note': note,
            'color': color,
          })
          .select()
          .maybeSingle();

      if (response == null) {
        AppLogger.e('Failed to create ebook bookmark');
        return null;
      }
      AppLogger.i('Ebook bookmark created');
      return EbookBookmark.fromJson(response);
    } catch (e) {
      AppLogger.e('Error creating ebook bookmark', error: e);
      return null;
    }
  }

  /// Delete a bookmark
  Future<bool> deleteBookmark(String bookmarkId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('ebook_bookmarks')
          .delete()
          .eq('id', bookmarkId)
          .eq('user_id', user.id);
      AppLogger.i('Ebook bookmark deleted');
      return true;
    } catch (e) {
      AppLogger.e('Error deleting ebook bookmark', error: e);
      return false;
    }
  }

  // ============================================
  // FILE MANAGEMENT
  // ============================================

  /// Download ebook file to local storage
  Future<String?> downloadEbook(int ebookId, String epubStoragePath) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      AppLogger.e('Cannot download ebook: user not authenticated');
      return null;
    }

    try {
      AppLogger.i('Downloading ebook $ebookId, path: $epubStoragePath');

      // Get signed URL for the EPUB file
      final signedUrl = await _client.storage
          .from('ebook-files')
          .createSignedUrl(epubStoragePath, 3600); // 1 hour expiry

      AppLogger.i('Got signed URL for ebook $ebookId');

      // Get local path
      final appDir = await getApplicationDocumentsDirectory();
      final ebooksDir = Directory('${appDir.path}/ebooks');
      if (!await ebooksDir.exists()) {
        await ebooksDir.create(recursive: true);
      }

      final localPath = '${ebooksDir.path}/ebook_$ebookId.epub';
      final file = File(localPath);

      // Download if not exists
      if (!await file.exists()) {
        AppLogger.i('Downloading ebook $ebookId from signed URL...');
        await _dio.download(signedUrl, localPath);
        AppLogger.i('Ebook $ebookId downloaded to $localPath');
      } else {
        AppLogger.i('Ebook $ebookId already exists locally at $localPath');
      }

      return localPath;
    } catch (e, stackTrace) {
      AppLogger.e('Error downloading ebook $ebookId', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if ebook is downloaded locally
  Future<bool> isEbookDownloaded(int ebookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/ebooks/ebook_$ebookId.epub';
      return await File(localPath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Get local path for downloaded ebook
  Future<String?> getLocalEbookPath(int ebookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/ebooks/ebook_$ebookId.epub';
      if (await File(localPath).exists()) {
        return localPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Delete downloaded ebook
  Future<bool> deleteDownloadedEbook(int ebookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/ebooks/ebook_$ebookId.epub';
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.i('Downloaded ebook $ebookId deleted');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error deleting downloaded ebook', error: e);
      return false;
    }
  }

  /// Get total size of downloaded ebooks
  Future<int> getDownloadedEbooksSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final ebooksDir = Directory('${appDir.path}/ebooks');
      if (!await ebooksDir.exists()) return 0;

      int totalSize = 0;
      await for (final file in ebooksDir.list()) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Increment read count for an ebook
  Future<void> incrementReadCount(int ebookId) async {
    try {
      await _client.rpc<void>('increment_ebook_read_count', params: {
        'p_ebook_id': ebookId,
      });
    } catch (e) {
      // Non-critical, log and continue
      AppLogger.w('Failed to increment ebook read count', error: e);
    }
  }
}
