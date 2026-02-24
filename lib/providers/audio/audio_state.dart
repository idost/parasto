// Audio state models and enums for the Myna audio player.
//
// This file contains:
// - [AudioErrorType] - Error classification for user-facing messages
// - [SleepTimerMode] - Sleep timer configuration options
// - [AudioState] - Immutable state class for audio playback
// - [PlaylistItem] - Minimal stub for playlist compatibility

/// Minimal stub for PlaylistItem - playlist feature has been removed
/// This stub maintains compatibility with existing AudioState structure
class PlaylistItem {
  final int audiobookId;
  final int? chapterIndex;
  final String? titleFa;
  const PlaylistItem({required this.audiobookId, this.chapterIndex, this.titleFa});
}

/// Sentinel value to distinguish between "not provided" and "explicitly null"
const _sentinel = Object();

/// Possible audio error types for user-facing messages
enum AudioErrorType {
  none,
  networkError,
  audioNotFound,
  playbackFailed,
  unauthorized,
}

/// Sleep timer modes
enum SleepTimerMode {
  off,
  timed,        // Minutes-based countdown
  endOfChapter, // Stop at end of current chapter
}

/// Immutable state class representing the current audio playback state.
///
/// This is the single source of truth for all audio-related UI.
/// Use [copyWith] to create new instances with updated values.
class AudioState {
  final Map<String, dynamic>? audiobook;
  final List<Map<String, dynamic>> chapters;
  final int currentChapterIndex;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final bool isBuffering;
  final double playbackSpeed;
  final AudioErrorType errorType;
  final String? errorMessage;
  // Sleep timer state
  final SleepTimerMode sleepTimerMode;
  final Duration sleepTimerRemaining;
  // Ownership state - tracks whether user has purchased this audiobook
  final bool isOwned;
  // Subscription state - tracks whether user has an active Parasto Premium
  // subscription. Required for accessing is_free content. Reflects the
  // native store's subscription state (includes grace/retry periods).
  final bool isSubscriptionActive;
  // Playlist queue state - for sequential playlist playback
  final String? playlistId;
  final List<PlaylistItem> playlistItems;
  final int currentPlaylistIndex;

  const AudioState({
    this.audiobook,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.isBuffering = false,
    this.playbackSpeed = 1.0,
    this.errorType = AudioErrorType.none,
    this.errorMessage,
    this.sleepTimerMode = SleepTimerMode.off,
    this.sleepTimerRemaining = Duration.zero,
    this.isOwned = false,
    this.isSubscriptionActive = false,
    this.playlistId,
    this.playlistItems = const [],
    this.currentPlaylistIndex = 0,
  });

  bool get hasAudio => audiobook != null;
  bool get hasError => errorType != AudioErrorType.none;
  bool get hasSleepTimer => sleepTimerMode != SleepTimerMode.off;
  bool get isMusic => audiobook?['is_music'] == true;

  /// True if currently playing from a playlist queue
  bool get isPlaylistActive => playlistId != null && playlistItems.isNotEmpty;

  /// True if there's a next item in the playlist queue
  bool get hasNextPlaylistItem =>
      isPlaylistActive && currentPlaylistIndex < playlistItems.length - 1;

  /// Check if user can play a specific chapter.
  ///
  /// Priority order (matches AccessGateService):
  /// 1. Owned (purchased/entitled) → always allowed
  /// 2. Preview chapter → always allowed (checked before sub gate)
  /// 3. Free audiobook + active subscription → allowed
  /// 4. Free audiobook + no subscription → LOCKED
  /// 5. Paid + not owned → LOCKED
  bool canPlayChapter(int chapterIndex) {
    // 1. Purchased items are always accessible (permanent).
    if (isOwned) return true;

    // 2. Preview chapters are always accessible — checked BEFORE
    //    subscription gate so previews work for everyone.
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
      if (chapters[chapterIndex]['is_preview'] == true) return true;
    }

    // 3. Free audiobook requires active subscription.
    if (audiobook != null && audiobook!['is_free'] == true) {
      return isSubscriptionActive;
    }

    // 4. Bounds check for non-free, non-owned content.
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return false;

    return false;
  }

  /// Check if there's a next chapter that the user can play
  bool get hasNextPlayableChapter {
    if (currentChapterIndex >= chapters.length - 1) return false;
    return canPlayChapter(currentChapterIndex + 1);
  }

  /// Check if there's a previous chapter that the user can play
  bool get hasPreviousPlayableChapter {
    if (currentChapterIndex <= 0) return false;
    return canPlayChapter(currentChapterIndex - 1);
  }

  AudioState copyWith({
    Map<String, dynamic>? audiobook,
    List<Map<String, dynamic>>? chapters,
    int? currentChapterIndex,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    bool? isBuffering,
    double? playbackSpeed,
    AudioErrorType? errorType,
    String? errorMessage,
    SleepTimerMode? sleepTimerMode,
    Duration? sleepTimerRemaining,
    bool? isOwned,
    bool? isSubscriptionActive,
    Object? playlistId = _sentinel,
    List<PlaylistItem>? playlistItems,
    int? currentPlaylistIndex,
  }) {
    return AudioState(
      audiobook: audiobook ?? this.audiobook,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isBuffering: isBuffering ?? this.isBuffering,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorType: errorType ?? this.errorType,
      errorMessage: errorMessage,
      sleepTimerMode: sleepTimerMode ?? this.sleepTimerMode,
      sleepTimerRemaining: sleepTimerRemaining ?? this.sleepTimerRemaining,
      isOwned: isOwned ?? this.isOwned,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      playlistId: playlistId == _sentinel ? this.playlistId : playlistId as String?,
      playlistItems: playlistItems ?? this.playlistItems,
      currentPlaylistIndex: currentPlaylistIndex ?? this.currentPlaylistIndex,
    );
  }

  /// Clear playlist queue state (e.g., when playing a single audiobook directly)
  AudioState clearPlaylist() {
    return copyWith(
      playlistId: null,
      playlistItems: const [],
      currentPlaylistIndex: 0,
    );
  }

  /// Clear error state
  AudioState clearError() {
    return copyWith(
      errorType: AudioErrorType.none,
      errorMessage: null,
    );
  }
}
