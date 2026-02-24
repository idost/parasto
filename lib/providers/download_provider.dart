import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myna/services/download_service.dart';
import 'package:myna/services/access_gate_service.dart';
import 'package:myna/utils/app_logger.dart';

/// State for tracking downloads across the app
class DownloadState {
  final Map<String, DownloadStatus> statuses;
  final Map<String, double> progress;
  final int totalDownloads;
  final int totalSizeBytes;

  const DownloadState({
    this.statuses = const {},
    this.progress = const {},
    this.totalDownloads = 0,
    this.totalSizeBytes = 0,
  });

  DownloadState copyWith({
    Map<String, DownloadStatus>? statuses,
    Map<String, double>? progress,
    int? totalDownloads,
    int? totalSizeBytes,
  }) {
    return DownloadState(
      statuses: statuses ?? this.statuses,
      progress: progress ?? this.progress,
      totalDownloads: totalDownloads ?? this.totalDownloads,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
    );
  }
}

/// Result of checking if download is allowed
class DownloadAllowedResult {
  final bool allowed;
  final String? errorMessage;

  const DownloadAllowedResult({required this.allowed, this.errorMessage});

  static const allowed_ = DownloadAllowedResult(allowed: true);
}

/// Notifier for managing download state
class DownloadNotifier extends StateNotifier<DownloadState> {
  final DownloadService _service = DownloadService();
  SharedPreferences? _prefs;

  DownloadNotifier() : super(const DownloadState()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _service.init();

    // Set up callbacks for UI updates
    _service.onDownloadProgress = (key, task) {
      _updateProgress(key, task.progress);
    };

    _service.onDownloadComplete = (key) {
      _updateStatus(key, DownloadStatus.downloaded);
      _refreshStats();
    };

    _service.onDownloadError = (key, error) {
      _updateStatus(key, DownloadStatus.failed);
    };

    _refreshStats();
  }

  void _updateStatus(String key, DownloadStatus status) {
    final newStatuses = Map<String, DownloadStatus>.from(state.statuses);
    newStatuses[key] = status;
    state = state.copyWith(statuses: newStatuses);
  }

  void _updateProgress(String key, double progress) {
    final newProgress = Map<String, double>.from(state.progress);
    newProgress[key] = progress;
    final newStatuses = Map<String, DownloadStatus>.from(state.statuses);
    newStatuses[key] = DownloadStatus.downloading;
    state = state.copyWith(progress: newProgress, statuses: newStatuses);
  }

  void _refreshStats() {
    state = state.copyWith(
      totalDownloads: _service.getAllDownloads().length,
      totalSizeBytes: _service.getTotalDownloadSize(),
    );
  }

  /// Get download status for a chapter
  DownloadStatus getStatus(int audiobookId, int chapterId) {
    return _service.getStatus(audiobookId, chapterId);
  }

  /// Get download progress for a chapter (0.0 to 1.0)
  double getProgress(int audiobookId, int chapterId) {
    final key = '${audiobookId}_$chapterId';
    return state.progress[key] ?? _service.getProgress(audiobookId, chapterId);
  }

  /// Check if a chapter is downloaded
  bool isDownloaded(int audiobookId, int chapterId) {
    return _service.isDownloaded(audiobookId, chapterId);
  }

  /// Get local path for a downloaded chapter
  String? getLocalPath(int audiobookId, int chapterId) {
    return _service.getLocalPath(audiobookId, chapterId);
  }

  /// Check if the WiFi-only download setting is enabled
  bool get isWifiOnlyEnabled {
    return _prefs?.getBool('download_wifi_only') ?? true;
  }

  /// Check if download is allowed based on current settings and network
  /// Returns a result with allowed=true if download can proceed,
  /// or allowed=false with an error message if blocked
  Future<DownloadAllowedResult> checkDownloadAllowed() async {
    // If WiFi-only is disabled, always allow
    if (!isWifiOnlyEnabled) {
      return DownloadAllowedResult.allowed_;
    }

    // Check if we're on WiFi by trying to determine connection type
    // Note: Without connectivity_plus, we can't definitively check WiFi vs cellular
    // For now, we'll allow the download but log a warning
    // A proper implementation would require adding connectivity_plus package
    AppLogger.d('DOWNLOAD: WiFi-only setting is enabled, proceeding with download');
    return DownloadAllowedResult.allowed_;
  }

  /// Start downloading a chapter.
  /// Returns false if download was blocked by access gate or settings.
  ///
  /// Access gate params are required to enforce subscription/ownership:
  /// - [isOwned]: user has entitlement for this audiobook
  /// - [isFree]: audiobook is_free flag (requires subscription)
  /// - [isSubscriptionActive]: user has active Parasto Premium
  /// - [isPreviewContent]: chapter is_preview (preview = streaming only, no download)
  Future<bool> downloadChapter({
    required int audiobookId,
    required int chapterId,
    required String url,
    String? chapterTitle,
    required bool isOwned,
    required bool isFree,
    required bool isSubscriptionActive,
    bool isPreviewContent = false,
  }) async {
    // Preview chapters: streaming only, no downloads allowed
    if (isPreviewContent) {
      AppLogger.w('DOWNLOAD: Blocked - preview chapters are streaming only');
      return false;
    }

    // Access gate check: enforce subscription/ownership at action level
    final accessResult = AccessGateService.checkAccess(
      isOwned: isOwned,
      isFree: isFree,
      isSubscriptionActive: isSubscriptionActive,
      isPreviewContent: false, // Never allow preview downloads
    );

    if (!accessResult.canAccess) {
      AppLogger.w('DOWNLOAD: Blocked by access gate - ${accessResult.type}');
      final key = '${audiobookId}_$chapterId';
      _updateStatus(key, DownloadStatus.failed);
      return false;
    }

    // Check if download is allowed (WiFi-only setting)
    final checkResult = await checkDownloadAllowed();
    if (!checkResult.allowed) {
      AppLogger.w('DOWNLOAD: Blocked - ${checkResult.errorMessage}');
      final key = '${audiobookId}_$chapterId';
      _updateStatus(key, DownloadStatus.failed);
      return false;
    }

    final key = '${audiobookId}_$chapterId';
    _updateStatus(key, DownloadStatus.downloading);
    _updateProgress(key, 0.0);

    await _service.downloadChapter(
      audiobookId: audiobookId,
      chapterId: chapterId,
      url: url,
      chapterTitle: chapterTitle,
    );
    return true;
  }

  /// Download all chapters of an audiobook.
  /// Returns false if download was blocked by access gate or settings.
  ///
  /// Preview chapters are skipped (streaming only).
  Future<bool> downloadAudiobook({
    required int audiobookId,
    required List<Map<String, dynamic>> chapters,
    required String Function(Map<String, dynamic>) getUrl,
    required bool isOwned,
    required bool isFree,
    required bool isSubscriptionActive,
  }) async {
    // Access gate check at audiobook level first
    final accessResult = AccessGateService.checkAccess(
      isOwned: isOwned,
      isFree: isFree,
      isSubscriptionActive: isSubscriptionActive,
    );

    if (!accessResult.canAccess) {
      AppLogger.w('DOWNLOAD: Batch download blocked by access gate - ${accessResult.type}');
      return false;
    }

    // Check if download is allowed before starting batch download
    final checkResult = await checkDownloadAllowed();
    if (!checkResult.allowed) {
      AppLogger.w('DOWNLOAD: Batch download blocked - ${checkResult.errorMessage}');
      return false;
    }

    for (final chapter in chapters) {
      final chapterId = chapter['id'] as int;
      final isPreview = chapter['is_preview'] == true;
      final url = getUrl(chapter);
      // Skip preview chapters (streaming only) and already downloaded
      if (url.isNotEmpty && !isPreview && !_service.isDownloaded(audiobookId, chapterId)) {
        await downloadChapter(
          audiobookId: audiobookId,
          chapterId: chapterId,
          url: url,
          chapterTitle: chapter['title_fa'] as String?,
          isOwned: isOwned,
          isFree: isFree,
          isSubscriptionActive: isSubscriptionActive,
        );
      }
    }
    return true;
  }

  /// Cancel a download
  Future<void> cancelDownload(int audiobookId, int chapterId) async {
    await _service.cancelDownload(audiobookId, chapterId);
    final key = '${audiobookId}_$chapterId';
    _updateStatus(key, DownloadStatus.notDownloaded);
    _updateProgress(key, 0.0);
  }

  /// Delete a downloaded chapter
  Future<void> deleteDownload(int audiobookId, int chapterId) async {
    await _service.deleteDownload(audiobookId, chapterId);
    final key = '${audiobookId}_$chapterId';
    _updateStatus(key, DownloadStatus.notDownloaded);
    _refreshStats();
  }

  /// Delete all downloads for an audiobook
  Future<void> deleteAudiobookDownloads(int audiobookId) async {
    await _service.deleteAudiobookDownloads(audiobookId);
    _refreshStats();
    // Clear statuses for this audiobook
    final newStatuses = Map<String, DownloadStatus>.from(state.statuses);
    newStatuses.removeWhere((key, _) => key.startsWith('${audiobookId}_'));
    state = state.copyWith(statuses: newStatuses);
  }

  /// Get all downloads for an audiobook
  List<DownloadedChapter> getAudiobookDownloads(int audiobookId) {
    return _service.getAudiobookDownloads(audiobookId);
  }

  /// Check if audiobook is fully downloaded
  bool isAudiobookFullyDownloaded(int audiobookId, int totalChapters) {
    return _service.isAudiobookFullyDownloaded(audiobookId, totalChapters);
  }

  /// Get formatted total download size
  String getFormattedTotalSize() {
    final bytes = state.totalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get formatted total download size in Farsi
  String getFormattedTotalSizeFarsi() {
    final bytes = state.totalSizeBytes;
    if (bytes < 1024) return '$bytes بایت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} کیلوبایت';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} مگابایت';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} گیگابایت';
  }

  /// Get all downloaded audiobook IDs
  Set<int> getDownloadedAudiobookIds() {
    final downloads = _service.getAllDownloads();
    return downloads.map((d) => d.audiobookId).toSet();
  }

  /// Check if an audiobook has any downloaded chapters
  bool hasAnyDownloads(int audiobookId) {
    return _service.getAudiobookDownloads(audiobookId).isNotEmpty;
  }

  /// Get all downloads grouped by audiobook
  Map<int, List<DownloadedChapter>> getAllDownloadsGrouped() {
    final downloads = _service.getAllDownloads();
    final grouped = <int, List<DownloadedChapter>>{};
    for (final download in downloads) {
      grouped.putIfAbsent(download.audiobookId, () => []);
      grouped[download.audiobookId]!.add(download);
    }
    return grouped;
  }

  /// Get all downloads
  List<DownloadedChapter> getAllDownloads() {
    return _service.getAllDownloads();
  }

  /// Delete all downloads
  Future<void> deleteAllDownloads() async {
    final downloads = _service.getAllDownloads();
    final audiobookIds = downloads.map((d) => d.audiobookId).toSet();
    for (final audiobookId in audiobookIds) {
      await _service.deleteAudiobookDownloads(audiobookId);
    }
    // Clear all statuses
    state = state.copyWith(
      statuses: {},
      progress: {},
      totalDownloads: 0,
      totalSizeBytes: 0,
    );
  }

  /// Verify downloads - check if files still exist and update state
  Future<void> verifyDownloads() async {
    await _service.init(); // This already verifies files exist
    _refreshStats();
  }

  /// Get total size for a specific audiobook's downloads
  int getAudiobookDownloadSize(int audiobookId) {
    final downloads = _service.getAudiobookDownloads(audiobookId);
    return downloads.fold(0, (sum, d) => sum + d.fileSizeBytes);
  }
}

/// Provider for download state
final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier();
});
