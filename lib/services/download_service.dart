import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:myna/utils/app_logger.dart';

/// Represents the download status of a chapter
enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

/// Information about a downloaded chapter
class DownloadedChapter {
  final int audiobookId;
  final int chapterId;
  final String localPath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  /// Expected file size from server (for integrity verification)
  final int? expectedSizeBytes;
  /// Whether the download has been verified for integrity
  final bool isVerified;

  DownloadedChapter({
    required this.audiobookId,
    required this.chapterId,
    required this.localPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    this.expectedSizeBytes,
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() => {
    'audiobookId': audiobookId,
    'chapterId': chapterId,
    'localPath': localPath,
    'fileSizeBytes': fileSizeBytes,
    'downloadedAt': downloadedAt.toIso8601String(),
    'expectedSizeBytes': expectedSizeBytes,
    'isVerified': isVerified,
  };

  factory DownloadedChapter.fromJson(Map<String, dynamic> json) => DownloadedChapter(
    audiobookId: json['audiobookId'] as int,
    chapterId: json['chapterId'] as int,
    localPath: json['localPath'] as String,
    fileSizeBytes: json['fileSizeBytes'] as int,
    downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    expectedSizeBytes: json['expectedSizeBytes'] as int?,
    isVerified: json['isVerified'] as bool? ?? false,
  );
}

/// Active download task tracking
class DownloadTask {
  final int audiobookId;
  final int chapterId;
  final String url;
  double progress; // 0.0 to 1.0
  DownloadStatus status;
  CancelToken? cancelToken;
  String? errorMessage;
  /// Bytes already downloaded (for resumption)
  int downloadedBytes;
  /// Total expected bytes (from Content-Length header)
  int? totalBytes;

  DownloadTask({
    required this.audiobookId,
    required this.chapterId,
    required this.url,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.cancelToken,
    this.errorMessage,
    this.downloadedBytes = 0,
    this.totalBytes,
  });
}

/// Simple semaphore for limiting concurrent downloads.
/// Thread-safe: uses a Completer-based queue so only one acquire
/// can proceed at a time (Dart's single-threaded event loop ensures
/// the synchronous check-and-increment is atomic within a microtask).
class _DownloadSemaphore {
  final int maxConcurrent;
  int _current = 0;
  final List<Completer<void>> _waiters = [];

  _DownloadSemaphore(this.maxConcurrent);

  Future<void> acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    // Don't increment here — the waiter is released by release()
    // which already decremented. Increment only once per slot.
  }

  void release() {
    if (_current <= 0) return; // Guard against double-release
    _current--;
    if (_waiters.isNotEmpty) {
      _current++; // Re-claim slot for the waiter
      _waiters.removeAt(0).complete();
    }
  }
}

/// Service for downloading and managing offline audio files
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final Map<String, DownloadTask> _activeTasks = {};
  final Map<String, DownloadedChapter> _downloadedChapters = {};

  // PERF FIX: Limit concurrent downloads to prevent device resource exhaustion
  final _downloadSemaphore = _DownloadSemaphore(3);

  static const String _storageKey = 'downloaded_chapters';

  // Callbacks for UI updates
  void Function(String key, DownloadTask task)? onDownloadProgress;
  void Function(String key)? onDownloadComplete;
  void Function(String key, String error)? onDownloadError;

  /// Initialize the service and load persisted download data
  Future<void> init() async {
    await _loadDownloadedChapters();
    AppLogger.i('DownloadService initialized with ${_downloadedChapters.length} downloads');

    // ZOMBIE FILE FIX: Clean up orphaned files in background
    // These can occur if SharedPrefs save fails after download completes
    _cleanupOrphanedFilesInBackground();
  }

  /// Clean up files that exist on disk but aren't tracked in SharedPrefs.
  /// This handles the case where download completes but SharedPrefs save fails.
  void _cleanupOrphanedFilesInBackground() {
    Future.microtask(() async {
      try {
        final downloadsDir = await _getDownloadsDir();
        if (!await downloadsDir.exists()) return;

        final trackedPaths = _downloadedChapters.values.map((c) => c.localPath).toSet();
        int orphansDeleted = 0;

        await for (final entity in downloadsDir.list()) {
          if (entity is File) {
            final path = entity.path;
            // Skip partial downloads (they have their own cleanup)
            if (path.endsWith('.partial')) continue;

            // Check if this file is tracked
            if (!trackedPaths.contains(path)) {
              // Orphan file - delete it
              try {
                await entity.delete();
                orphansDeleted++;
                AppLogger.d('Deleted orphan download file: ${path.split('/').last}');
              } catch (e) {
                AppLogger.w('Failed to delete orphan file: $path');
              }
            }
          }
        }

        if (orphansDeleted > 0) {
          AppLogger.i('Cleaned up $orphansDeleted orphaned download files');
        }
      } catch (e) {
        AppLogger.e('Error during orphan file cleanup', error: e);
      }
    });
  }

  /// Get the downloads directory
  Future<Directory> _getDownloadsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/audiobooks');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// Generate a unique key for a chapter download
  String _getKey(int audiobookId, int chapterId) => '${audiobookId}_$chapterId';

  /// Load downloaded chapters from persistent storage
  /// PERFORMANCE: Loads metadata first, verifies files in background
  Future<void> _loadDownloadedChapters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

        // PERFORMANCE: Load all metadata immediately (no file I/O)
        final chaptersToVerify = <String, DownloadedChapter>{};
        for (final item in jsonList) {
          final chapter = DownloadedChapter.fromJson(item as Map<String, dynamic>);
          chaptersToVerify[_getKey(chapter.audiobookId, chapter.chapterId)] = chapter;
        }

        // Add all chapters first (assume they exist)
        _downloadedChapters.addAll(chaptersToVerify);

        // PERFORMANCE: Verify files exist in background (non-blocking)
        // If a file is missing, it will be removed when user tries to play
        _verifyFilesInBackground(chaptersToVerify);
      }
    } catch (e) {
      AppLogger.e('Error loading downloaded chapters', error: e);
    }
  }

  /// Verify downloaded files exist in background
  void _verifyFilesInBackground(Map<String, DownloadedChapter> chapters) {
    Future.microtask(() async {
      final keysToRemove = <String>[];
      for (final entry in chapters.entries) {
        if (!await File(entry.value.localPath).exists()) {
          keysToRemove.add(entry.key);
        }
      }
      if (keysToRemove.isNotEmpty) {
        for (final key in keysToRemove) {
          _downloadedChapters.remove(key);
        }
        await _saveDownloadedChapters();
        AppLogger.d('Removed ${keysToRemove.length} missing downloads');
      }
    });
  }

  /// Save downloaded chapters to persistent storage with retry
  /// ZOMBIE FILE FIX: Retries on failure to reduce orphan file risk
  Future<void> _saveDownloadedChapters() async {
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = _downloadedChapters.values.map((c) => c.toJson()).toList();
        final success = await prefs.setString(_storageKey, json.encode(jsonList));

        if (success) {
          if (attempt > 1) {
            AppLogger.d('Download metadata saved on attempt $attempt');
          }
          return; // Success
        } else {
          AppLogger.w('SharedPreferences.setString returned false (attempt $attempt/$maxRetries)');
        }
      } catch (e) {
        AppLogger.e('Error saving downloaded chapters (attempt $attempt/$maxRetries)', error: e);
      }

      if (attempt < maxRetries) {
        await Future<void>.delayed(retryDelay);
      }
    }

    // All retries failed - log critical warning
    AppLogger.e('CRITICAL: Failed to save download metadata after $maxRetries attempts. '
        'Orphan files may result on next app restart.');
  }

  /// Check if a chapter is downloaded
  bool isDownloaded(int audiobookId, int chapterId) {
    return _downloadedChapters.containsKey(_getKey(audiobookId, chapterId));
  }

  /// Check if a chapter is currently downloading
  bool isDownloading(int audiobookId, int chapterId) {
    final key = _getKey(audiobookId, chapterId);
    final task = _activeTasks[key];
    return task != null && task.status == DownloadStatus.downloading;
  }

  /// Get download status for a chapter
  DownloadStatus getStatus(int audiobookId, int chapterId) {
    final key = _getKey(audiobookId, chapterId);
    if (_downloadedChapters.containsKey(key)) {
      return DownloadStatus.downloaded;
    }
    final task = _activeTasks[key];
    return task?.status ?? DownloadStatus.notDownloaded;
  }

  /// Get download progress for a chapter (0.0 to 1.0)
  double getProgress(int audiobookId, int chapterId) {
    final key = _getKey(audiobookId, chapterId);
    return _activeTasks[key]?.progress ?? 0.0;
  }

  /// Get the local path for a downloaded chapter
  String? getLocalPath(int audiobookId, int chapterId) {
    final key = _getKey(audiobookId, chapterId);
    return _downloadedChapters[key]?.localPath;
  }

  /// Start downloading a chapter with resumption support
  /// PERF FIX: Uses semaphore to limit concurrent downloads to 3
  /// RESUMPTION: Checks for partial file and uses Range header to continue
  Future<void> downloadChapter({
    required int audiobookId,
    required int chapterId,
    required String url,
    String? chapterTitle,
  }) async {
    final key = _getKey(audiobookId, chapterId);

    // Already downloaded or downloading
    if (isDownloaded(audiobookId, chapterId) || isDownloading(audiobookId, chapterId)) {
      return;
    }

    final downloadsDir = await _getDownloadsDir();
    final extension = url.split('.').last.split('?').first;
    final fileName = '${audiobookId}_$chapterId.$extension';
    final filePath = '${downloadsDir.path}/$fileName';
    final partialFilePath = '$filePath.partial';

    // Check for partial file to resume
    int existingBytes = 0;
    final partialFile = File(partialFilePath);
    if (await partialFile.exists()) {
      existingBytes = await partialFile.length();
      AppLogger.audio('Resuming download from $existingBytes bytes', chapter: chapterTitle ?? 'Chapter $chapterId');
    }

    final cancelToken = CancelToken();
    final task = DownloadTask(
      audiobookId: audiobookId,
      chapterId: chapterId,
      url: url,
      cancelToken: cancelToken,
      downloadedBytes: existingBytes,
    );
    _activeTasks[key] = task;

    AppLogger.audio('Starting download${existingBytes > 0 ? " (resuming)" : ""}', chapter: chapterTitle ?? 'Chapter $chapterId');

    // PERF FIX: Wait for semaphore to limit concurrent downloads
    await _downloadSemaphore.acquire();

    try {
      // Set up headers for range request if resuming
      final options = Options();
      if (existingBytes > 0) {
        options.headers = {'Range': 'bytes=$existingBytes-'};
      }

      await _dio.download(
        url,
        partialFilePath,
        cancelToken: cancelToken,
        options: options,
        deleteOnError: false, // Keep partial file for resumption
        onReceiveProgress: (received, total) {
          // For resumed downloads, total may be remaining bytes or full size
          final actualReceived = received + existingBytes;
          final actualTotal = total > 0 ? total + existingBytes : 0;
          task.downloadedBytes = actualReceived;
          task.totalBytes = actualTotal > 0 ? actualTotal : null;

          if (actualTotal > 0) {
            task.progress = actualReceived / actualTotal;
            onDownloadProgress?.call(key, task);
          }
        },
      );

      // Download complete - verify and move to final location
      final downloadedFile = File(partialFilePath);
      final fileSize = await downloadedFile.length();

      // INTEGRITY CHECK: Verify file size matches expected size (if we have it)
      bool isVerified = false;
      if (task.totalBytes != null && task.totalBytes! > 0) {
        if (fileSize == task.totalBytes) {
          isVerified = true;
          AppLogger.audio('Download verified: size matches expected ${task.totalBytes} bytes',
              chapter: chapterTitle ?? 'Chapter $chapterId');
        } else {
          AppLogger.w('Download size mismatch: got $fileSize, expected ${task.totalBytes}');
          // Still accept the file but mark as unverified
        }
      }

      // INTEGRITY CHECK: Verify minimum file size (audio files should be > 1KB)
      const minFileSize = 1024; // 1KB minimum
      if (fileSize < minFileSize) {
        throw Exception('Downloaded file too small: $fileSize bytes (minimum $minFileSize)');
      }

      // Move partial file to final location
      await downloadedFile.rename(filePath);

      final downloadedChapter = DownloadedChapter(
        audiobookId: audiobookId,
        chapterId: chapterId,
        localPath: filePath,
        fileSizeBytes: fileSize,
        downloadedAt: DateTime.now(),
        expectedSizeBytes: task.totalBytes,
        isVerified: isVerified,
      );

      _downloadedChapters[key] = downloadedChapter;
      await _saveDownloadedChapters();

      task.status = DownloadStatus.downloaded;
      task.progress = 1.0;
      _activeTasks.remove(key);

      onDownloadComplete?.call(key);
      AppLogger.audio('Download complete${isVerified ? " (verified)" : ""}', chapter: chapterTitle ?? 'Chapter $chapterId');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        AppLogger.audio('Download paused (partial file kept for resumption)', chapter: chapterTitle ?? 'Chapter $chapterId');
        // Keep partial file for resumption - don't delete it
      } else {
        AppLogger.e('Download failed', error: e);
        task.status = DownloadStatus.failed;
        task.errorMessage = 'خطا در دانلود فایل';
        onDownloadError?.call(key, task.errorMessage!);
        // Keep partial file for retry/resumption
      }
      _activeTasks.remove(key);
    } catch (e) {
      AppLogger.e('Download failed', error: e);
      task.status = DownloadStatus.failed;
      task.errorMessage = 'خطا در دانلود فایل';
      _activeTasks.remove(key);
      onDownloadError?.call(key, task.errorMessage!);
      // Keep partial file for retry/resumption
    } finally {
      // PERF FIX: Always release semaphore
      _downloadSemaphore.release();
    }
  }

  /// Delete partial download file (use when user explicitly cancels)
  Future<void> deletePartialDownload(int audiobookId, int chapterId) async {
    final downloadsDir = await _getDownloadsDir();
    // Try common audio extensions
    for (final ext in ['mp3', 'm4a', 'aac', 'ogg']) {
      final partialPath = '${downloadsDir.path}/${audiobookId}_$chapterId.$ext.partial';
      final partialFile = File(partialPath);
      if (await partialFile.exists()) {
        await partialFile.delete();
        AppLogger.audio('Deleted partial download file');
        return;
      }
    }
  }

  /// Check if a chapter has a partial download that can be resumed
  Future<bool> hasPartialDownload(int audiobookId, int chapterId) async {
    final downloadsDir = await _getDownloadsDir();
    for (final ext in ['mp3', 'm4a', 'aac', 'ogg']) {
      final partialPath = '${downloadsDir.path}/${audiobookId}_$chapterId.$ext.partial';
      if (await File(partialPath).exists()) {
        return true;
      }
    }
    return false;
  }

  /// Get partial download size in bytes (for UI display)
  Future<int> getPartialDownloadSize(int audiobookId, int chapterId) async {
    final downloadsDir = await _getDownloadsDir();
    for (final ext in ['mp3', 'm4a', 'aac', 'ogg']) {
      final partialPath = '${downloadsDir.path}/${audiobookId}_$chapterId.$ext.partial';
      final file = File(partialPath);
      if (await file.exists()) {
        return await file.length();
      }
    }
    return 0;
  }

  /// Verify integrity of a downloaded file
  /// Returns true if file exists and has reasonable size
  Future<bool> verifyDownloadIntegrity(int audiobookId, int chapterId) async {
    final chapter = _downloadedChapters[_getKey(audiobookId, chapterId)];
    if (chapter == null) return false;

    final file = File(chapter.localPath);
    if (!await file.exists()) {
      // File missing - remove from records
      _downloadedChapters.remove(_getKey(audiobookId, chapterId));
      await _saveDownloadedChapters();
      return false;
    }

    final fileSize = await file.length();

    // Check against expected size if available
    if (chapter.expectedSizeBytes != null && chapter.expectedSizeBytes! > 0) {
      if (fileSize != chapter.expectedSizeBytes) {
        AppLogger.w('File integrity check failed: size $fileSize != expected ${chapter.expectedSizeBytes}');
        return false;
      }
    }

    // Check minimum size
    if (fileSize < 1024) {
      AppLogger.w('File integrity check failed: file too small ($fileSize bytes)');
      return false;
    }

    return true;
  }

  /// Cancel an active download
  Future<void> cancelDownload(int audiobookId, int chapterId) async {
    final key = _getKey(audiobookId, chapterId);
    final task = _activeTasks[key];
    if (task != null) {
      task.cancelToken?.cancel();
      _activeTasks.remove(key);
    }
  }

  /// Delete a downloaded chapter
  Future<void> deleteDownload(int audiobookId, int chapterId) async {
    final key = _getKey(audiobookId, chapterId);
    final chapter = _downloadedChapters[key];
    if (chapter != null) {
      try {
        final file = File(chapter.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        AppLogger.e('Error deleting file', error: e);
      }
      _downloadedChapters.remove(key);
      await _saveDownloadedChapters();
    }
  }

  /// Delete all downloads for an audiobook
  Future<void> deleteAudiobookDownloads(int audiobookId) async {
    final keysToRemove = <String>[];
    for (final entry in _downloadedChapters.entries) {
      if (entry.value.audiobookId == audiobookId) {
        keysToRemove.add(entry.key);
        try {
          final file = File(entry.value.localPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          AppLogger.e('Error deleting file', error: e);
        }
      }
    }
    for (final key in keysToRemove) {
      _downloadedChapters.remove(key);
    }
    await _saveDownloadedChapters();
  }

  /// Get all downloaded chapters for an audiobook
  List<DownloadedChapter> getAudiobookDownloads(int audiobookId) {
    return _downloadedChapters.values
        .where((c) => c.audiobookId == audiobookId)
        .toList();
  }

  /// Get all downloaded chapters
  List<DownloadedChapter> getAllDownloads() {
    return _downloadedChapters.values.toList();
  }

  /// Get total download size in bytes
  int getTotalDownloadSize() {
    return _downloadedChapters.values.fold(0, (sum, c) => sum + c.fileSizeBytes);
  }

  /// Check if all chapters of an audiobook are downloaded
  bool isAudiobookFullyDownloaded(int audiobookId, int totalChapters) {
    final downloaded = _downloadedChapters.values
        .where((c) => c.audiobookId == audiobookId)
        .length;
    return downloaded >= totalChapters;
  }
}
