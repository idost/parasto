import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/config/env.dart';
import 'package:myna/config/audio_config.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/services/audio_handler.dart';
import 'package:myna/services/download_service.dart';
import 'package:myna/services/notification_permission_service.dart';
import 'package:myna/services/access_gate_service.dart';
import 'package:myna/providers/home_providers.dart';

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
  timed,       // Minutes-based countdown
  endOfChapter, // Stop at end of current chapter
}

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
  // subscription. Required for accessing is_free content.
  final bool isSubscriptionActive;
  // Session-start position: where playback began this session (Apple Books pattern)
  // Shows as a gray dot on the seek bar so user sees "where I started from"
  final Duration? sessionStartPosition;
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
    this.sessionStartPosition,
    this.playlistId,
    this.playlistItems = const [],
    this.currentPlaylistIndex = 0,
  });

  bool get hasAudio => audiobook != null;
  bool get hasError => errorType != AudioErrorType.none;
  bool get hasSleepTimer => sleepTimerMode != SleepTimerMode.off;
  bool get isMusic => audiobook?['content_type'] == 'music';

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
    Object? sessionStartPosition = _sentinel,
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
      sessionStartPosition: sessionStartPosition == _sentinel
          ? this.sessionStartPosition
          : sessionStartPosition as Duration?,
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

// ==========================================================================
// NOTIFICATION PERMISSION STATE (Android 13+ UX)
// ==========================================================================

/// State enum for notification permission status
enum NotificationPermissionStatus {
  /// Not yet checked
  unknown,
  /// Permission granted, media controls will appear
  granted,
  /// Permission denied, user should be informed
  denied,
  /// Permission permanently denied, must go to settings
  permanentlyDenied,
}

/// Provider for Android notification permission status.
/// Used to show UX warnings when permission is denied.
final notificationPermissionProvider =
    StateProvider<NotificationPermissionStatus>((ref) => NotificationPermissionStatus.unknown);

/// Provider to track if user has dismissed the permission warning.
/// Prevents showing the warning repeatedly in the same session.
final notificationWarningDismissedProvider = StateProvider<bool>((ref) => false);

/// Global audio handler instance - set from main.dart
MynaAudioHandler? _globalAudioHandler;

/// Set the audio handler (called from main.dart after initialization)
void setGlobalAudioHandler(MynaAudioHandler handler) {
  _globalAudioHandler = handler;
}

class AudioNotifier extends StateNotifier<AudioState> with WidgetsBindingObserver {
  final Ref _ref;
  late final AudioPlayer _player;
  Timer? _saveTimer;
  Timer? _sleepTimer;

  /// Flag set immediately when dispose() starts.
  /// Used to prevent timer callbacks from modifying state after dispose.
  /// This is more reliable than `mounted` for async callbacks because
  /// it's set synchronously before any cleanup happens.
  bool _isDisposed = false;

  int _totalListenTime = 0;
  DateTime? _playStartTime;
  /// Track today's session time for accurate daily stats
  int _todaySessionTime = 0;
  String? _todaySessionDate; // YYYY-MM-DD format
  /// Track unique chapters listened to per (audiobook, date) for accurate stats
  final Set<int> _todayChaptersListened = {};
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  /// Flag to suspend position stream updates (used during payment to reduce CPU)
  bool _positionUpdatesSuspended = false;

  /// Request counter for cancellation pattern - allows newer play requests to cancel older ones
  /// Instead of blocking new requests, we let them run and cancel in-flight older requests
  int _currentPlayRequestId = 0;

  /// OPTIMIZATION: Cached autoPlayNext setting to avoid SharedPreferences.getInstance() on every chapter complete.
  /// Default is true. Updated when user changes the setting via SettingsScreen.
  bool _cachedAutoPlayNext = true;

  /// Cached SharedPreferences instance for faster access
  SharedPreferences? _cachedPrefs;

  /// Guard flag to prevent duplicate _onChapterComplete calls.
  /// Both the stream listener and the audio_handler callback can trigger it.
  bool _chapterCompleteInProgress = false;

  /// Timestamp-based debounce for play/pause to prevent rapid-fire calls.
  /// Using timestamp instead of bool flag ensures it can't get stuck.
  DateTime? _lastPlayPauseTime;

  AudioNotifier(this._ref) : super(const AudioState()) {
    // Use the global audio handler's player if available, otherwise create standalone
    _player = _globalAudioHandler?.player ?? AudioPlayer();
    _initPlayer();
    _initAuthListener();
    _initAutoPlaySetting();
    WidgetsBinding.instance.addObserver(this);
  }

  /// OPTIMIZATION: Load autoPlayNext setting once at init and cache it
  /// Also loads and applies other audio settings (skipSilence, default playback speed)
  Future<void> _initAutoPlaySetting() async {
    _cachedPrefs = await SharedPreferences.getInstance();
    _cachedAutoPlayNext = _cachedPrefs?.getBool('auto_play_next') ?? true;
    AppLogger.audio('INIT: Cached autoPlayNext=$_cachedAutoPlayNext');
    // Sync to handler for iOS background auto-next
    _globalAudioHandler?.setAutoPlayNext(_cachedAutoPlayNext);

    // Apply skip silence setting from preferences
    final skipSilence = _cachedPrefs?.getBool('skip_silence') ?? false;
    if (skipSilence) {
      await setSkipSilence(true);
    }

    // Cache default playback speed for use when starting new playback
    _cachedDefaultPlaybackSpeed = _cachedPrefs?.getDouble('playback_speed') ?? 1.0;
    AppLogger.audio('INIT: Cached defaultPlaybackSpeed=$_cachedDefaultPlaybackSpeed');
  }

  /// Cached default playback speed from settings
  double _cachedDefaultPlaybackSpeed = 1.0;

  /// Call this when user changes the autoPlayNext setting to update the cache
  void updateAutoPlayNextCache(bool value) {
    _cachedAutoPlayNext = value;
    AppLogger.audio('CACHE: autoPlayNext updated to $value');
    // Sync to handler for iOS background auto-next
    _globalAudioHandler?.setAutoPlayNext(value);
  }

  /// Call this when user changes the default playback speed in settings
  void updateDefaultPlaybackSpeedCache(double speed) {
    _cachedDefaultPlaybackSpeed = speed;
    AppLogger.audio('CACHE: defaultPlaybackSpeed updated to $speed');
  }

  /// Update ownership state for the currently playing audiobook.
  /// Call this after a successful purchase to unlock all chapters immediately.
  /// This syncs ownership to both the provider state AND the handler (for iOS background).
  ///
  /// [audiobookId] - The audiobook that was purchased (only updates if matches current)
  void updateOwnershipAfterPurchase(int audiobookId) {
    final currentAudiobookId = state.audiobook?['id'];
    if (currentAudiobookId != audiobookId) {
      AppLogger.audio('OWNERSHIP: Purchase was for different audiobook ($audiobookId), current is $currentAudiobookId');
      return;
    }

    AppLogger.audio('OWNERSHIP: Updating ownership for audiobook $audiobookId after purchase');

    // Update provider state
    if (mounted) {
      state = state.copyWith(isOwned: true);
    }

    // Sync to handler for iOS background auto-next
    final isFree = state.audiobook?['is_free'] == true;
    _globalAudioHandler?.setOwnershipState(isOwned: true, isFreeAudiobook: isFree);

    AppLogger.audio('OWNERSHIP: Updated - state.isOwned=true, handler synced');
  }

  /// Listen for auth state changes and stop audio on logout
  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        AppLogger.audio('User signed out - stopping audio');
        _stopAndClear();
      }
    });
  }

  /// Stop audio and clear state (without saving progress since user is logging out)
  Future<void> _stopAndClear() async {
    _clearLocalPosition();
    if (_globalAudioHandler != null) {
      await _globalAudioHandler!.stop();
    } else {
      await _player.stop();
    }

    // Cancel all stream subscriptions to prevent memory leaks
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription = null;
    _playerStateSubscription = null;
    AppLogger.audio('LOGOUT: All subscriptions cancelled');

    if (mounted) {
      state = const AudioState();
    }
  }

  /// Throttle position updates to reduce CPU usage on large files
  /// Only update state if position changed by more than 250ms
  Duration _lastReportedPosition = Duration.zero;
  static const _positionUpdateThreshold = Duration(milliseconds: 250);

  void _initPlayer() {
    // Set up callbacks for audio handler (for lock screen controls and background playback)
    if (_globalAudioHandler != null) {
      _globalAudioHandler!.onProgressSave = _saveProgress;
      // onChapterComplete is called when:
      // 1. User taps next/previous on lock screen controls (skipToNext/skipToPrevious)
      // 2. iOS auto-next has finished loading next chapter (to sync UI state only)
      //
      // For case 1: We need to call goToChapter() to start playback
      // For case 2: We just need to sync state without starting new playback
      //
      // We differentiate by checking if the handler already started playback:
      // If player.playing is true and handler's currentChapterIndex matches,
      // the handler already started playback, so we just sync state.
      _globalAudioHandler!.onChapterComplete = (index) {
        if (index != state.currentChapterIndex && state.hasAudio) {
          // Check if handler already started playback for this chapter
          final handlerIsPlaying = _player.playing;
          final handlerChapterIndex = _globalAudioHandler?.currentChapterIndex ?? -1;

          if (Platform.isIOS && handlerIsPlaying && handlerChapterIndex == index) {
            // iOS auto-next: Handler already started playback, just sync state
            AppLogger.audio('[AUTO_NEXT] onChapterComplete: iOS sync only - handler already playing chapter $index');
            if (mounted) {
              state = state.copyWith(
                currentChapterIndex: index,
                isLoading: false,
              );
            }
          } else {
            // Lock screen controls or Android: Start playback
            AppLogger.audio('[AUTO_NEXT] onChapterComplete: Starting playback for chapter $index');
            goToChapter(index);
          }
        }
      };
      // BACKGROUND PLAYBACK FIX: Handle completion callback from audio_handler.
      // This ensures chapter auto-next works even when app is minimized/in background.
      // The audio_handler's completion detection runs in audio_service's background
      // context, which is more reliable than Flutter's stream listeners when suspended.
      _globalAudioHandler!.onPlaybackComplete = () {
        // [AUTO_NEXT] Log when handler callback reaches audio_provider
        AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_HANDLER_RECEIVED: callback from audio_handler received in AudioNotifier');
        _onChapterComplete();
      };
    }

    // OPTIMIZATION: Throttle position updates to reduce rebuilds
    // PERF FIX: Always throttle - 100ms minimum even when paused
    // Sub-100ms updates are imperceptible but cause excessive rebuilds
    _positionSubscription = _player.positionStream.listen((pos) {
      if (!mounted || _positionUpdatesSuspended) return;

      final diff = (pos - _lastReportedPosition).abs();

      // PERF FIX: Throttle even when paused (100ms min vs 250ms when playing)
      // This prevents excessive rebuilds from 30-60Hz position stream
      final threshold = state.isPlaying
          ? _positionUpdateThreshold  // 250ms when playing
          : const Duration(milliseconds: 100);  // 100ms when paused

      if (diff >= threshold) {
        _lastReportedPosition = pos;
        state = state.copyWith(position: pos);
      }
    });

    _durationSubscription = _player.durationStream.listen((dur) {
      if (dur != null && mounted) {
        // RACE CONDITION FIX: Capture chapter index atomically BEFORE any async work.
        // If user skips chapters rapidly, state.currentChapterIndex may change
        // between now and when _updateChapterDurationIfNeeded runs.
        final capturedChapterIndex = state.currentChapterIndex;
        final capturedChapters = state.chapters;

        state = state.copyWith(duration: dur);
        // Update chapter duration in database if not already set
        _updateChapterDurationIfNeeded(dur, capturedChapterIndex, capturedChapters);
      }
    });

    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (!mounted) return;

      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      final isLoading = processingState == ProcessingState.loading;
      final isBuffering = processingState == ProcessingState.buffering;

      // [PP20] Log state changes from player stream (single source of truth)
      if (state.isPlaying != isPlaying) {
        AppLogger.audio('[PP20][STATE] isPlaying changed: $isPlaying');
      }

      state = state.copyWith(
        isPlaying: isPlaying,
        isLoading: isLoading,
        isBuffering: isBuffering,
      );

      // Track listening time
      if (isPlaying && _playStartTime == null) {
        _playStartTime = DateTime.now();
        // Capture session-start position for UI seek bar marker (Apple Books pattern)
        if (state.sessionStartPosition == null) {
          state = state.copyWith(sessionStartPosition: state.position);
        }
        // Reset today's session tracking if date changed
        final today = DateTime.now().toIso8601String().split('T')[0];
        if (_todaySessionDate != today) {
          _todaySessionDate = today;
          _todaySessionTime = 0;
          _todayChaptersListened.clear();
        }
        // Track current chapter as listened
        if (state.currentChapterIndex >= 0 && state.chapters.isNotEmpty) {
          final chapterId = state.chapters[state.currentChapterIndex]['id'] as int?;
          if (chapterId != null) {
            _todayChaptersListened.add(chapterId);
          }
        }
      } else if (!isPlaying && _playStartTime != null) {
        final elapsed = DateTime.now().difference(_playStartTime!).inSeconds;
        _totalListenTime += elapsed;
        _todaySessionTime += elapsed; // Also track today's session time
        _playStartTime = null;
      }

      // Handle chapter completion
      if (processingState == ProcessingState.completed) {
        // [AUTO_NEXT] Log when UI stream detects completion
        AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI_STREAM: processingState=completed detected in playerStateStream');
        _onChapterComplete();
      }
    });

    // Listen for playback errors
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        AppLogger.e('Playback error', error: e, stackTrace: st);
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            isBuffering: false,
            errorType: AudioErrorType.playbackFailed,
            errorMessage: 'خطا در پخش صدا. لطفاً دوباره تلاش کنید',
          );
        }
      },
    );

    // Periodic progress save every 30 seconds while playing
    // This ensures progress is saved even if user kills the app
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // DISPOSE SAFETY: Check flag before accessing state
      if (_isDisposed) return;
      if (state.isPlaying && state.hasAudio) {
        _saveProgress();
      }
    });
  }

  /// Handle app lifecycle changes - save progress when app goes to background
  /// and force refresh state when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.detached) {
      // App is going to background or closing - save progress
      if (state.hasAudio) {
        AppLogger.audio('App lifecycle: $appState - saving progress');
        _saveProgress();
      }
    } else if (appState == AppLifecycleState.resumed) {
      // App is coming back to foreground - force refresh playback state
      if (state.hasAudio) {
        AppLogger.audio('App lifecycle: resumed - refreshing state');
        _forceRefreshState();
      }
    }
  }

  /// Force refresh the playback state from the player
  /// Called when app resumes from background to sync UI with actual playback
  void _forceRefreshState() {
    if (!mounted) return;

    // Get current actual values from player
    final currentPosition = _player.position;
    final currentDuration = _player.duration ?? Duration.zero;
    final isPlaying = _player.playing;
    final processingState = _player.processingState;

    // Force update last reported position to allow immediate refresh
    _lastReportedPosition = currentPosition;

    // Update state with all current values
    state = state.copyWith(
      position: currentPosition,
      duration: currentDuration,
      isPlaying: isPlaying,
      isLoading: processingState == ProcessingState.loading,
      isBuffering: processingState == ProcessingState.buffering,
    );
  }

  /// Get the audio source - prefers local file if downloaded, otherwise remote URL
  /// Returns a record with the source URL/path and whether it's local
  (String? source, bool isLocal) _getAudioSourceWithType(Map<String, dynamic> chapter, int audiobookId) {
    final chapterId = chapter['id'] as int?;

    // First check if we have a local download
    if (chapterId != null) {
      final downloadService = DownloadService();
      final localPath = downloadService.getLocalPath(audiobookId, chapterId);
      if (localPath != null && File(localPath).existsSync()) {
        AppLogger.audio('Using local file', chapter: chapter['title_fa'] as String?);
        return (localPath, true);
      }
    }

    // Fall back to remote URL
    return (_getRemoteUrl(chapter), false);
  }

  /// PERF FIX: Cache offline status to avoid DNS lookup on every chapter change
  /// DNS lookups can add 500-2000ms latency
  bool? _cachedOfflineStatus;
  DateTime? _offlineStatusCacheTime;

  /// Check if device is currently offline (cached for configurable duration)
  /// Use [forceRefresh] to bypass cache when user explicitly changes network state
  Future<bool> _isOffline({bool forceRefresh = false}) async {
    // Return cached result if still valid (unless force refresh requested)
    if (!forceRefresh && _cachedOfflineStatus != null && _offlineStatusCacheTime != null) {
      final elapsed = DateTime.now().difference(_offlineStatusCacheTime!);
      if (elapsed < AudioConfig.offlineStatusCacheDuration) {
        return _cachedOfflineStatus!;
      }
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(AudioConfig.offlineCheckTimeout);
      _cachedOfflineStatus = result.isEmpty || result[0].rawAddress.isEmpty;
    } on SocketException catch (_) {
      _cachedOfflineStatus = true;
    } on TimeoutException catch (_) {
      _cachedOfflineStatus = true;
    } catch (_) {
      _cachedOfflineStatus = false; // Assume online if we can't determine
    }

    _offlineStatusCacheTime = DateTime.now();
    return _cachedOfflineStatus!;
  }

  /// Force refresh offline status cache.
  /// Call this when user toggles airplane mode or network settings change.
  void invalidateOfflineCache() {
    _cachedOfflineStatus = null;
    _offlineStatusCacheTime = null;
    AppLogger.audio('Offline status cache invalidated');
  }

  /// Get the remote URL for a chapter
  String? _getRemoteUrl(Map<String, dynamic> chapter) {
    // Try direct audio_url first
    if (chapter['audio_url'] != null) {
      return chapter['audio_url'] as String;
    }

    // If audio_storage_path exists, construct public URL from Supabase Storage
    if (chapter['audio_storage_path'] != null) {
      final path = chapter['audio_storage_path'] as String;
      return Supabase.instance.client.storage
          .from(Env.audioBucket)  // Use configured bucket name
          .getPublicUrl(path);
    }

    return null;
  }

  /// Clear any error state
  void clearError() {
    if (mounted) {
      state = state.clearError();
    }
  }

  /// Suspend position stream updates to reduce CPU usage during payment
  /// Call this before presenting the Stripe payment sheet
  void suspendPositionUpdates() {
    _positionUpdatesSuspended = true;
  }

  /// Resume position stream updates after payment completes
  void resumePositionUpdates() {
    _positionUpdatesSuspended = false;
  }

  /// Load existing listen time from database for accumulation
  Future<void> _loadExistingListenTime(int audiobookId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _totalListenTime = 0;
        _todaySessionTime = 0;
        _todaySessionDate = null;
        return;
      }

      final response = await Supabase.instance.client
          .from('listening_progress')
          .select('total_listen_time_seconds')
          .eq('user_id', user.id)
          .eq('audiobook_id', audiobookId)
          .maybeSingle()
          .timeout(AudioConfig.databaseQueryTimeout);

      if (response != null) {
        _totalListenTime = (response['total_listen_time_seconds'] as int?) ?? 0;
        AppLogger.audio('Loaded existing listen time: ${_totalListenTime}s');
      } else {
        _totalListenTime = 0;
      }

      // Also load today's session time from listening_sessions
      final today = DateTime.now().toIso8601String().split('T')[0];
      _todaySessionDate = today;

      final sessionResponse = await Supabase.instance.client
          .from('listening_sessions')
          .select('duration_seconds')
          .eq('user_id', user.id)
          .eq('audiobook_id', audiobookId)
          .eq('session_date', today)
          .maybeSingle()
          .timeout(AudioConfig.databaseQueryTimeout);

      if (sessionResponse != null) {
        _todaySessionTime = (sessionResponse['duration_seconds'] as int?) ?? 0;
        AppLogger.audio('Loaded today session time: ${_todaySessionTime}s');
      } else {
        _todaySessionTime = 0;
      }
    } catch (e) {
      AppLogger.e('Error loading existing listen time', error: e);
      _totalListenTime = 0;
      _todaySessionTime = 0;
      _todaySessionDate = null;
    }
  }

  /// Retry playback after an error
  Future<void> retry() async {
    if (!state.hasAudio || state.chapters.isEmpty) return;

    clearError();
    await play(
      audiobook: state.audiobook!,
      chapters: state.chapters,
      chapterIndex: state.currentChapterIndex,
      seekTo: state.position.inSeconds,
    );
  }

  Future<void> play({
    required Map<String, dynamic> audiobook,
    required List<Map<String, dynamic>> chapters,
    int chapterIndex = 0,
    int? seekTo,
    bool? isOwned,
    bool isSubscriptionActive = false,
  }) async {
    final audiobookId = audiobook['id'];
    final audiobookTitle = audiobook['title_fa'] ?? audiobook['title'] ?? 'unknown';
    final isFree = audiobook['is_free'] == true;
    final platform = Platform.isIOS ? 'iOS' : 'Android';

    // Increment request ID FIRST - this cancels any in-flight play operations immediately
    // Using cancellation pattern: new requests always proceed, older requests check and abort
    _currentPlayRequestId++;
    final thisRequestId = _currentPlayRequestId;

    AppLogger.audioNotif('[AUDIO_NOTIF] PROVIDER: play() START - '
        'requestId=$thisRequestId, audiobookId=$audiobookId, title="$audiobookTitle", '
        'chapterIndex=$chapterIndex, totalChapters=${chapters.length}, '
        'isOwned=$isOwned, isFree=$isFree, platform=$platform');

    // ANDROID 13+ FIX: Request notification permission before starting playback.
    // Without this, the media notification won't appear in the notification shade.
    if (Platform.isAndroid) {
      AppLogger.audioNotif('PLAY: Android detected - checking notification permission');
      final notificationService = NotificationPermissionService();
      final permissionGranted = await notificationService.ensureNotificationPermission();

      // Update the notification permission provider for UX feedback
      if (!permissionGranted) {
        AppLogger.audioNotif('PLAY: WARNING - Notification permission NOT granted, media controls may not appear');
        AppLogger.w('PLAYER: Notification permission not granted - media controls may not appear');

        // Check if permanently denied (user must go to settings)
        final diagnostics = await notificationService.getNotificationDiagnostics();
        if (diagnostics != null && diagnostics.sdkInt >= 33 && !diagnostics.postNotifGranted) {
          // On Android 13+, if user denied once, future requests won't show dialog
          _ref.read(notificationPermissionProvider.notifier).state =
              NotificationPermissionStatus.permanentlyDenied;
        } else {
          _ref.read(notificationPermissionProvider.notifier).state =
              NotificationPermissionStatus.denied;
        }
        // Continue anyway - audio will still play, just without system notification
      } else {
        AppLogger.audioNotif('PLAY: Notification permission granted');
        _ref.read(notificationPermissionProvider.notifier).state =
            NotificationPermissionStatus.granted;
      }

      // Log diagnostics right before first playback to capture channel state
      await notificationService.logNotificationDiagnostics('PLAYBACK');

      // Check if cancelled during permission check
      if (_currentPlayRequestId != thisRequestId) {
        AppLogger.audioNotif('PLAY: Request $thisRequestId cancelled during permission check');
        return;
      }
    }

    final chapterId = chapters.isNotEmpty && chapterIndex < chapters.length
        ? chapters[chapterIndex]['id']
        : null;
    AppLogger.audio(
      'PLAYER: play() called - requestId=$thisRequestId, audiobookId=${audiobook['id']}, '
      'chapterIndex=$chapterIndex, chapterId=$chapterId',
    );

    try {
      await _playInternal(
        audiobook: audiobook,
        chapters: chapters,
        chapterIndex: chapterIndex,
        seekTo: seekTo,
        isOwned: isOwned,
        isSubscriptionActive: isSubscriptionActive,
        requestId: thisRequestId,
      );
      AppLogger.audioNotif('[AUDIO_NOTIF] PROVIDER: play() completed successfully');
    } catch (e, st) {
      AppLogger.audioNotif('[AUDIO_NOTIF] PROVIDER: play() FAILED with exception: $e');
      AppLogger.e('[AUDIO_NOTIF] PROVIDER: play() exception', error: e, stackTrace: st);
      // Ensure loading state is cleared on any exception
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Internal play method with cancellation support
  /// The requestId parameter allows newer requests to cancel this one mid-flight
  Future<void> _playInternal({
    required Map<String, dynamic> audiobook,
    required List<Map<String, dynamic>> chapters,
    int chapterIndex = 0,
    int? seekTo,
    bool? isOwned,
    bool isSubscriptionActive = false,
    required int requestId,
    int retryCount = 0,
  }) async {
    // Helper to check if this request has been superseded by a newer one
    bool isCancelled() => _currentPlayRequestId != requestId;

    AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] Starting playback process');

    if (chapters.isEmpty) {
      AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] FAILED - no chapters');
      AppLogger.w('PLAYER: No chapters to play');
      final isMusic = audiobook['content_type'] == 'music';
      state = state.copyWith(
        errorType: AudioErrorType.audioNotFound,
        errorMessage: isMusic ? 'هیچ آهنگی برای پخش وجود ندارد' : 'هیچ فصلی برای پخش وجود ندارد',
      );
      return;
    }

    // Validate chapter index
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] Invalid chapter index $chapterIndex, resetting to 0');
      AppLogger.e('PLAYER: Invalid chapter index: $chapterIndex');
      chapterIndex = 0;
    }

    // Determine ownership: use provided value, or preserve current state if same audiobook
    final isSameAudiobook = audiobook['id'] == state.audiobook?['id'];
    final ownershipStatus = isOwned ?? (isSameAudiobook ? state.isOwned : false);

    // Check if user can play this chapter using AccessGateService
    final chapter = chapters[chapterIndex];
    final chapterIsPreview = chapter['is_preview'] == true;
    final isFreeAudiobook = audiobook['is_free'] == true;

    final accessResult = AccessGateService.checkAccess(
      isOwned: ownershipStatus,
      isFree: isFreeAudiobook,
      isSubscriptionActive: isSubscriptionActive,
      isPreviewContent: chapterIsPreview,
    );

    // Log entitlement check for debugging
    AppLogger.audioNotif('ENTITLEMENT: [req=$requestId] Check - '
        'isOwned=$ownershipStatus, isFree=$isFreeAudiobook, isPreview=$chapterIsPreview, '
        'isSubActive=$isSubscriptionActive, access=${accessResult.type}');

    if (!accessResult.canAccess) {
      AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] BLOCKED - ${accessResult.type}');
      AppLogger.w('PLAYER: Access denied - ${accessResult.type}');
      final isMusic = audiobook['content_type'] == 'music';
      state = state.copyWith(
        errorType: AudioErrorType.unauthorized,
        errorMessage: accessResult.needsSubscription
            ? 'برای دسترسی به این محتوا، اشتراک فعال نیاز است'
            : isMusic
                ? 'برای گوش دادن به این آهنگ، آلبوم را خریداری کنید'
                : 'برای گوش دادن به این فصل، کتاب را خریداری کنید',
      );
      return;
    }

    // OPTIMIZATION: Skip database query during chapter transitions within the same audiobook.
    // Listen time is already loaded when the audiobook started playing.
    // This saves ~50-150ms per chapter transition.
    if (!isSameAudiobook) {
      await _loadExistingListenTime(audiobook['id'] as int);
    } else {
      AppLogger.audio('PLAYER: [req=$requestId] Skipping listen time load (same audiobook)');
    }

    // Check if cancelled after async operation
    if (isCancelled()) {
      AppLogger.audio('PLAYER: Request $requestId cancelled (newer request exists)');
      return;
    }

    // For new audiobooks, use default playback speed from settings
    // For chapter transitions (same audiobook), preserve current speed
    final playbackSpeedToUse = isSameAudiobook
        ? state.playbackSpeed
        : _cachedDefaultPlaybackSpeed;

    // Set loading state BEFORE stopping player to show immediate feedback
    state = state.copyWith(
      audiobook: audiobook,
      chapters: chapters,
      currentChapterIndex: chapterIndex,
      isLoading: true,
      errorType: AudioErrorType.none,
      errorMessage: null,
      isOwned: ownershipStatus,
      isSubscriptionActive: isSubscriptionActive,
      playbackSpeed: playbackSpeedToUse,
    );

    try {
      final chapter = chapters[chapterIndex];
      final audiobookId = audiobook['id'] as int;
      final (audioSource, isLocal) = _getAudioSourceWithType(chapter, audiobookId);

      AppLogger.audio(
        'PLAYER: [req=$requestId] Loading chapter - title="${chapter['title_fa']}", '
        'isLocal=$isLocal',
      );

      if (audioSource == null || audioSource.isEmpty) {
        AppLogger.e('PLAYER: No audio source found for chapter');
        if (!isCancelled()) {
          final isMusic = audiobook['content_type'] == 'music';
          state = state.copyWith(
            isLoading: false,
            errorType: AudioErrorType.audioNotFound,
            errorMessage: isMusic
                ? 'فایل صوتی این آهنگ موجود نیست'
                : 'فایل صوتی این فصل موجود نیست',
          );
        }
        return;
      }

      // OPTIMIZATION: Skip offline check during chapter transitions within the same audiobook.
      // If we're already streaming, the connection is working. The player will fail naturally
      // if the network drops mid-stream. This saves ~100-300ms per chapter transition.
      if (!isLocal && !isSameAudiobook) {
        final offline = await _isOffline();
        if (isCancelled()) {
          AppLogger.audio('PLAYER: Request $requestId cancelled after offline check');
          // Clear loading state for cancelled request
          state = state.copyWith(isLoading: false);
          return;
        }
        if (offline) {
          AppLogger.e('PLAYER: Offline and chapter not downloaded');
          final isMusic = audiobook['content_type'] == 'music';
          state = state.copyWith(
            isLoading: false,
            errorType: AudioErrorType.networkError,
            errorMessage: isMusic
                ? 'این آهنگ دانلود نشده است و شما آفلاین هستید. لطفاً به اینترنت متصل شوید یا آهنگ را دانلود کنید.'
                : 'این فصل دانلود نشده است و شما آفلاین هستید. لطفاً به اینترنت متصل شوید یا فصل را دانلود کنید.',
          );
          return;
        }
      } else if (!isLocal && isSameAudiobook) {
        AppLogger.audio('PLAYER: [req=$requestId] Skipping offline check (same audiobook, already streaming)');
      }

      // CRITICAL: Stop the player before setting a new source
      // This prevents PlayerInterruptedException when switching chapters
      AppLogger.audio('PLAYER: [req=$requestId] Stopping current playback');
      await _player.stop();

      // Check cancellation after stop
      if (isCancelled()) {
        AppLogger.audio('PLAYER: Request $requestId cancelled after stop');
        // Clear loading state for cancelled request (newer request will set its own)
        state = state.copyWith(isLoading: false);
        return;
      }

      // Use audio handler if available (enables lock screen controls)
      if (_globalAudioHandler != null) {
        AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] Calling _globalAudioHandler.playChapter() - '
            'this will set MediaItem and trigger notification');
        AppLogger.audio('PLAYER: [req=$requestId] Using audio handler to play chapter');

        // Sync ownership state to handler for iOS background auto-next
        _globalAudioHandler!.setOwnershipState(
          isOwned: ownershipStatus,
          isFreeAudiobook: isFreeAudiobook,
        );

        await _globalAudioHandler!.playChapter(
          audiobook: audiobook,
          chapters: chapters,
          chapterIndex: chapterIndex,
          audioUrl: audioSource,
          startPosition: seekTo != null ? Duration(seconds: seekTo) : null,
          isLocalFile: isLocal,
        );

        AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] _globalAudioHandler.playChapter() returned successfully');

        // Check cancellation after playChapter
        if (isCancelled()) {
          AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] Request cancelled after playChapter');
          AppLogger.audio('PLAYER: Request $requestId cancelled after playChapter - stopping');
          await _player.stop();
          // Clear loading state for cancelled request
          state = state.copyWith(isLoading: false);
          return;
        }

        await _globalAudioHandler!.setSpeed(state.playbackSpeed);
      } else {
        AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] WARNING - _globalAudioHandler is null, using direct player (no notification!)');
        // Fallback: direct player control
        AppLogger.audio('PLAYER: [req=$requestId] Using direct player control');
        if (isLocal) {
          await _player.setFilePath(audioSource);
        } else {
          await _player.setUrl(audioSource);
        }

        if (isCancelled()) {
          AppLogger.audio('PLAYER: Request $requestId cancelled after setUrl - stopping');
          await _player.stop();
          return;
        }

        await _player.setSpeed(state.playbackSpeed);
        if (seekTo != null && seekTo > 0) {
          final maxSeek = state.duration.inSeconds;
          final clampedSeek = maxSeek > 0 ? seekTo.clamp(0, maxSeek) : seekTo;
          await _player.seek(Duration(seconds: clampedSeek));
        }
        await _player.play();
      }

      // Final cancellation check before updating state
      if (isCancelled()) {
        AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] Request cancelled at final check');
        AppLogger.audio('PLAYER: Request $requestId cancelled at end - stopping');
        await _player.stop();
        // Clear loading state for cancelled request
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(isLoading: false);
      AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] SUCCESS - playback started, '
          'isPlaying=${_player.playing}, processingState=${_player.processingState}');
      AppLogger.audio('PLAYER: [req=$requestId] Playback started successfully${isLocal ? " (offline)" : ""}');
    } on PlayerException catch (e, st) {
      AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] PlayerException: $e');
      AppLogger.e('PLAYER ERROR: PlayerException', error: e, stackTrace: st);
      if (!isCancelled()) {
        state = state.copyWith(
          isLoading: false,
          errorType: AudioErrorType.playbackFailed,
          errorMessage: 'خطا در بارگذاری صدا. لطفاً دوباره تلاش کنید',
        );
      }
    } on PlayerInterruptedException catch (e, st) {
      // This can happen legitimately when a newer request cancels this one
      // Only show error if this request wasn't cancelled
      if (!isCancelled()) {
        AppLogger.e('PLAYER ERROR: PlayerInterruptedException', error: e, stackTrace: st);
        state = state.copyWith(
          isLoading: false,
          errorType: AudioErrorType.playbackFailed,
          errorMessage: 'پخش قطع شد. لطفاً دوباره تلاش کنید',
        );
      } else {
        AppLogger.audio('PLAYER: PlayerInterruptedException for cancelled request $requestId (expected)');
      }
    } catch (e, st) {
      if (!isCancelled()) {
        // CRITICAL: If audio is already playing successfully, don't treat timeout as an error.
        // The timeout just means the function took too long, but playback started fine.
        // Retrying would restart the chapter from 0, which is wrong.
        if (_player.playing) {
          AppLogger.audioNotif('PLAY_INTERNAL: [req=$requestId] Exception occurred but audio is playing - ignoring error: $e');
          state = state.copyWith(isLoading: false);
          return;
        }

        AppLogger.e('PLAYER ERROR: Unexpected error (retry=$retryCount)', error: e, stackTrace: st);

        // Determine error type based on exception
        AudioErrorType errorType = AudioErrorType.playbackFailed;
        String errorMessage = 'خطا در پخش صدا. لطفاً دوباره تلاش کنید';
        bool isTransientError = false;

        final errorString = e.toString().toLowerCase();
        // Note: Don't treat timeout as transient if it's from operation queue timeout
        // (those timeouts happen even when playback is working, just slow to complete)
        if (errorString.contains('network') ||
            errorString.contains('connection') ||
            errorString.contains('socket')) {
          errorType = AudioErrorType.networkError;
          errorMessage = 'اتصال به اینترنت برقرار نیست';
          isTransientError = true; // Network errors are often transient
        } else if (errorString.contains('timeout') && !_player.playing) {
          // Only treat timeout as transient if audio isn't playing
          errorType = AudioErrorType.networkError;
          errorMessage = 'زمان اتصال به پایان رسید';
          isTransientError = true;
        } else if (errorString.contains('404') ||
                   errorString.contains('not found')) {
          errorType = AudioErrorType.audioNotFound;
          errorMessage = 'فایل صوتی یافت نشد';
        } else if (errorString.contains('403') ||
                   errorString.contains('unauthorized') ||
                   errorString.contains('forbidden')) {
          errorType = AudioErrorType.unauthorized;
          errorMessage = 'شما اجازه دسترسی به این محتوا را ندارید';
        }

        // AUTO-RETRY: For transient errors (network issues), automatically retry
        // This improves UX by recovering from temporary network glitches without user action
        if (isTransientError && retryCount < AudioConfig.networkErrorMaxRetries) {
          AppLogger.audio('PLAYER: Transient error, auto-retrying (attempt ${retryCount + 1}/${AudioConfig.networkErrorMaxRetries})');

          // Show temporary loading state while retrying
          state = state.copyWith(isLoading: true);

          // Wait before retrying to give network time to recover
          await Future<void>.delayed(AudioConfig.networkErrorRetryDelay);

          // Check if still the current request before retrying
          if (!isCancelled()) {
            await _playInternal(
              audiobook: audiobook,
              chapters: chapters,
              chapterIndex: chapterIndex,
              seekTo: seekTo,
              isOwned: isOwned,
              isSubscriptionActive: isSubscriptionActive,
              requestId: requestId,
              retryCount: retryCount + 1,
            );
          }
          return; // Don't set error state - retry is in progress
        }

        // No more retries - show error to user
        if (retryCount > 0) {
          AppLogger.audio('PLAYER: All ${AudioConfig.networkErrorMaxRetries} retries exhausted, showing error');
        }

        state = state.copyWith(
          isLoading: false,
          errorType: errorType,
          errorMessage: errorMessage,
        );
      }
    }
  }

  /// [PP20] Simple, deterministic toggle - thin dispatcher to handler
  /// Uses timestamp-based debounce to prevent rapid-fire calls from UI.
  Future<void> togglePlayPause() async {
    if (state.hasError) {
      await retry();
      return;
    }

    // Timestamp-based debounce: ignore calls within debounce window.
    // This prevents rapid-fire calls from stuck UI or multiple tap handlers.
    final now = DateTime.now();
    if (_lastPlayPauseTime != null) {
      final elapsed = now.difference(_lastPlayPauseTime!);
      if (elapsed < AudioConfig.playPauseDebounce) {
        AppLogger.audio('[PP20][PROVIDER] DEBOUNCE - ignoring call within ${elapsed.inMilliseconds}ms');
        return;
      }
    }
    _lastPlayPauseTime = now;

    // Get canonical state from player (single source of truth)
    final canonicalPlaying = _player.playing;
    final intent = canonicalPlaying ? 'PAUSE' : 'PLAY';

    AppLogger.audio('[PP20][PROVIDER] intent=$intent canonicalPlaying=$canonicalPlaying');

    try {
      if (canonicalPlaying) {
        // Currently playing -> pause
        if (_globalAudioHandler != null) {
          await _globalAudioHandler!.pause();
        } else {
          await _player.pause();
        }
        _saveProgress();
      } else {
        // Currently paused -> play
        if (_globalAudioHandler != null) {
          await _globalAudioHandler!.play();
        } else {
          await _player.play();
        }
      }
    } catch (e) {
      AppLogger.e('[PP20][PROVIDER] error', error: e);
    }
  }

  Future<void> seek(Duration position) async {
    // Clamp position to valid range
    final maxDuration = state.duration;
    final clampedPosition = Duration(
      milliseconds: position.inMilliseconds.clamp(0, maxDuration.inMilliseconds),
    );
    // Immediately update state for responsive UI
    _lastReportedPosition = clampedPosition;
    state = state.copyWith(position: clampedPosition);

    if (_globalAudioHandler != null) {
      await _globalAudioHandler!.seek(clampedPosition);
    } else {
      await _player.seek(clampedPosition);
    }
  }

  Future<void> skipForward({int seconds = 15}) async {
    if (_globalAudioHandler != null) {
      // Use custom duration instead of default fastForward
      final newPos = state.position + Duration(seconds: seconds);
      if (newPos < state.duration) {
        await _globalAudioHandler!.seek(newPos);
      } else {
        await _globalAudioHandler!.seek(state.duration);
      }
    } else {
      final newPos = state.position + Duration(seconds: seconds);
      if (newPos < state.duration) {
        await _player.seek(newPos);
      } else {
        await _player.seek(state.duration);
      }
    }
  }

  Future<void> skipBackward({int seconds = 15}) async {
    if (_globalAudioHandler != null) {
      // Use custom duration instead of default rewind
      final newPos = state.position - Duration(seconds: seconds);
      await _globalAudioHandler!.seek(newPos.isNegative ? Duration.zero : newPos);
    } else {
      final newPos = state.position - Duration(seconds: seconds);
      await _player.seek(newPos.isNegative ? Duration.zero : newPos);
    }
  }

  Future<void> previousChapter() async {
    // CRASH FIX: Guard against null audiobook (can happen during logout race)
    if (state.audiobook == null) return;
    if (state.currentChapterIndex > 0 && state.canPlayChapter(state.currentChapterIndex - 1)) {
      await play(
        audiobook: state.audiobook!,
        chapters: state.chapters,
        chapterIndex: state.currentChapterIndex - 1,
        isOwned: state.isOwned,
        isSubscriptionActive: state.isSubscriptionActive,
      );
    }
  }

  /// Attempt to play next chapter. Returns true if successful, false if blocked (locked chapter).
  Future<bool> nextChapter() async {
    // CRASH FIX: Guard against null audiobook (can happen during logout race)
    if (state.audiobook == null) return false;
    if (state.currentChapterIndex < state.chapters.length - 1) {
      final nextIndex = state.currentChapterIndex + 1;
      if (state.canPlayChapter(nextIndex)) {
        await play(
          audiobook: state.audiobook!,
          chapters: state.chapters,
          chapterIndex: nextIndex,
          isOwned: state.isOwned,
          isSubscriptionActive: state.isSubscriptionActive,
        );
        return true;
      } else {
        // Chapter is locked - set error state to notify UI
        AppLogger.w('Next chapter is locked');
        state = state.copyWith(
          errorType: AudioErrorType.unauthorized,
          errorMessage: state.isMusic
              ? 'آهنگ بعدی قفل است. برای ادامه، آلبوم را خریداری کنید'
              : 'فصل بعدی قفل است. برای ادامه، کتاب را خریداری کنید',
        );
        return false;
      }
    }
    return false;
  }

  Future<void> goToChapter(int chapterIndex) async {
    AppLogger.audio('PLAYER: goToChapter($chapterIndex) called, currentState: isPlaying=${state.isPlaying}, hasError=${state.hasError}');

    // Validate state
    if (state.audiobook == null) {
      AppLogger.e('PLAYER: Cannot switch chapter - no audiobook loaded');
      return;
    }

    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) {
      AppLogger.e('PLAYER: Invalid chapter index $chapterIndex (chapters: ${state.chapters.length})');
      return;
    }

    if (!state.canPlayChapter(chapterIndex)) {
      // Chapter is locked
      AppLogger.w('PLAYER: Chapter $chapterIndex is locked');
      state = state.copyWith(
        errorType: AudioErrorType.unauthorized,
        errorMessage: state.isMusic
            ? 'این آهنگ قفل است. برای گوش دادن، آلبوم را خریداری کنید'
            : 'این فصل قفل است. برای گوش دادن، کتاب را خریداری کنید',
      );
      return;
    }

    // FIX: Clear any existing error state before switching chapters
    // This prevents "خطایی در پخش رخ داد" from showing during valid transitions
    if (state.hasError) {
      AppLogger.audio('PLAYER: Clearing error state before chapter switch');
      state = state.clearError();
    }

    // Save progress before switching chapters
    if (state.hasAudio) {
      AppLogger.audio('PLAYER: Saving progress before chapter switch');
      _saveProgress();
    }

    // FIX: Log full chapter details for debugging
    final chapter = state.chapters[chapterIndex];
    AppLogger.audio('PLAYER: Switching to chapter $chapterIndex - "${chapter['title_fa']}"');

    await play(
      audiobook: state.audiobook!,
      chapters: state.chapters,
      chapterIndex: chapterIndex,
      isOwned: state.isOwned,
      isSubscriptionActive: state.isSubscriptionActive,
    );
  }

  Future<void> setSpeed(double speed) async {
    if (_globalAudioHandler != null) {
      await _globalAudioHandler!.setSpeed(speed);
    } else {
      await _player.setSpeed(speed);
    }
    state = state.copyWith(playbackSpeed: speed);
  }

  /// Enable/disable skip silence feature
  /// Automatically skips silent portions of audio for faster listening
  Future<void> setSkipSilence(bool enabled) async {
    try {
      await _player.setSkipSilenceEnabled(enabled);
      AppLogger.audio('PLAYER: Skip silence set to $enabled');
    } catch (e) {
      AppLogger.e('Error setting skip silence', error: e);
    }
  }

  /// Enable/disable volume boost (loudness enhancement)
  /// Note: Full loudness enhancement requires native Android AudioEffect API
  /// This is a placeholder that logs the preference - native implementation would be needed
  /// for actual audio amplification beyond the system volume
  Future<void> setBoostVolume(bool enabled) async {
    // Volume boost would require native Android LoudnessEnhancer AudioEffect
    // or iOS AVAudioUnitEQ. For now, we just log the preference.
    // The setting is saved and can be used when native support is added.
    AppLogger.audio('PLAYER: Volume boost preference set to $enabled');
    // TODO: Implement native loudness enhancement if needed
  }

  // ============================================
  // SLEEP TIMER METHODS
  // ============================================

  /// Set a timed sleep timer (in minutes)
  void setSleepTimer(int minutes) {
    _cancelSleepTimerInternal();

    if (minutes <= 0) return;

    final duration = Duration(minutes: minutes);
    state = state.copyWith(
      sleepTimerMode: SleepTimerMode.timed,
      sleepTimerRemaining: duration,
    );

    // Sync to handler for iOS background auto-next
    _globalAudioHandler?.setSleepTimerActive(true);

    AppLogger.audio('Sleep timer set: $minutes minutes');

    // Start countdown timer (updates every second)
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // DISPOSE SAFETY: Check both flags - _isDisposed is set first in dispose()
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      final remaining = state.sleepTimerRemaining - const Duration(seconds: 1);

      if (remaining.inSeconds <= 0) {
        // Timer expired - pause audio
        _onSleepTimerExpired();
        timer.cancel();
      } else {
        state = state.copyWith(sleepTimerRemaining: remaining);
      }
    });
  }

  /// Set sleep timer to "end of chapter" mode
  void setSleepTimerEndOfChapter() {
    _cancelSleepTimerInternal();

    state = state.copyWith(
      sleepTimerMode: SleepTimerMode.endOfChapter,
      sleepTimerRemaining: Duration.zero,
    );

    // Sync to handler for iOS background auto-next
    _globalAudioHandler?.setSleepTimerActive(true);

    AppLogger.audio('Sleep timer set: end of chapter');
  }

  /// Cancel the sleep timer
  void cancelSleepTimer() {
    _cancelSleepTimerInternal();
    state = state.copyWith(
      sleepTimerMode: SleepTimerMode.off,
      sleepTimerRemaining: Duration.zero,
    );
    // Sync to handler for iOS background auto-next
    _globalAudioHandler?.setSleepTimerActive(false);
    AppLogger.audio('Sleep timer cancelled');
  }

  void _cancelSleepTimerInternal() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  void _onSleepTimerExpired() async {
    // DISPOSE SAFETY: Early exit if already disposed
    if (_isDisposed) return;

    AppLogger.audio('Sleep timer expired - pausing');

    // Pause playback
    if (_globalAudioHandler != null) {
      await _globalAudioHandler!.pause();
    } else {
      await _player.pause();
    }

    // DISPOSE SAFETY: Check again after async operation
    if (_isDisposed) return;

    // Save progress (async but doesn't modify state directly)
    _saveProgress();

    // Clear timer state - check both flags for safety
    if (!_isDisposed && mounted) {
      state = state.copyWith(
        sleepTimerMode: SleepTimerMode.off,
        sleepTimerRemaining: Duration.zero,
      );
    }
    // Sync to handler for iOS background auto-next
    _globalAudioHandler?.setSleepTimerActive(false);
  }

  Future<void> stop() async {
    await _saveProgress();
    _clearLocalPosition();
    if (_globalAudioHandler != null) {
      await _globalAudioHandler!.stop();
    } else {
      await _player.stop();
    }
    state = const AudioState();
  }

  void _onChapterComplete() async {
    // GUARD: Prevent duplicate calls from both stream listener and audio_handler callback.
    // This can happen because processingStateStream.completed and onPlaybackComplete
    // may both fire for the same completion event.
    if (_chapterCompleteInProgress) {
      AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: DUPLICATE CALL - ignoring');
      return;
    }
    _chapterCompleteInProgress = true;

    // CRITICAL: Capture all state values upfront BEFORE any async operations
    // This prevents race conditions where state changes during await calls
    final currentState = state;
    final audiobookId = currentState.audiobook?['id'];
    final chapterIndex = currentState.currentChapterIndex;
    final chaptersCount = currentState.chapters.length;
    final isPlaylistActive = currentState.isPlaylistActive;
    final hasNextPlaylistItem = currentState.hasNextPlaylistItem;
    final playlistIndex = currentState.currentPlaylistIndex;
    final playlistItemsCount = currentState.playlistItems.length;
    final sleepTimerMode = currentState.sleepTimerMode;
    final hasNext = chapterIndex < chaptersCount - 1;

    // [AUTO_NEXT] Comprehensive diagnostic log at entry
    AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: ENTRY - '
        'audiobookId=$audiobookId, chapterIndex=$chapterIndex, totalChapters=$chaptersCount, '
        'hasNext=$hasNext, autoPlayNext=$_cachedAutoPlayNext, sleepTimerMode=$sleepTimerMode, '
        'mounted=$mounted, platform=${Platform.isIOS ? "iOS" : "Android"}');

    // === iOS CHAPTER AUTO-NEXT ===
    // On iOS, CHAPTER auto-next is handled directly by the audio_handler in native context.
    // The callback here is for:
    // 1. UI sync (updating state.currentChapterIndex) for mid-audiobook transitions
    // 2. PLAYLIST auto-advance when the last chapter of an audiobook completes
    //
    // We should NOT run chapter auto-next logic here to avoid double-triggering,
    // BUT we MUST allow playlist auto-advance to run.
    if (Platform.isIOS && hasNext) {
      // Mid-audiobook: Handler manages chapter auto-next, we just sync UI
      AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: iOS mid-book - skipping chapter auto-next (handler manages it), syncing UI state');
      if (_globalAudioHandler != null) {
        final handlerChapterIndex = _globalAudioHandler!.currentChapterIndex;
        final handlerAudiobook = _globalAudioHandler!.currentAudiobook;
        if (handlerChapterIndex != currentState.currentChapterIndex &&
            handlerAudiobook != null) {
          AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: iOS sync - updating state from handler '
              '(handlerIdx=$handlerChapterIndex, stateIdx=$chapterIndex)');
          state = state.copyWith(
            currentChapterIndex: handlerChapterIndex,
            // Clear any loading state
            isLoading: false,
          );
        }
      }
      // Reset guard flag after sync (uses centralized config)
      Future.delayed(AudioConfig.chapterCompleteGuardReset, () {
        _chapterCompleteInProgress = false;
      });
      return;
    }
    // NOTE: iOS last-chapter case (hasNext=false) falls through to playlist auto-advance logic below

    // Check if "end of chapter" sleep timer is active
    if (sleepTimerMode == SleepTimerMode.endOfChapter) {
      AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: SLEEP_TIMER - triggering end-of-chapter sleep');
      _chapterCompleteInProgress = false;
      _onSleepTimerExpired();
      return;
    }

    // OPTIMIZATION: Use cached autoPlayNext setting instead of await SharedPreferences.getInstance()
    // This eliminates ~50-200ms delay on every chapter transition.
    // The cache is updated when user changes the setting via SettingsScreen.
    //
    // STALE CACHE FIX: Refresh from SharedPreferences if available to ensure freshness.
    // This handles edge cases where cache might be stale (e.g., settings changed elsewhere).
    if (_cachedPrefs != null) {
      final freshValue = _cachedPrefs!.getBool('auto_play_next') ?? true;
      if (freshValue != _cachedAutoPlayNext) {
        AppLogger.audio('CACHE: autoPlayNext was stale! Updating: $_cachedAutoPlayNext -> $freshValue');
        _cachedAutoPlayNext = freshValue;
        _globalAudioHandler?.setAutoPlayNext(freshValue);
      }
    }
    final autoPlayNext = _cachedAutoPlayNext;

    AppLogger.audio('AUTOPLAY: Chapter $chapterIndex complete - autoPlayNext=$autoPlayNext (audiobook=$audiobookId)');

    if (chapterIndex < chaptersCount - 1) {
      if (autoPlayNext) {
        // Auto-play is ON - try to play next chapter
        AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: CALLING_NEXT - autoPlayNext=true, calling nextChapter()');
        final success = await nextChapter();
        AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: NEXT_RESULT - nextChapter() returned success=$success');
        if (!success) {
          // Next chapter is locked - save progress and stop
          AppLogger.audio('[AUTO_NEXT] CH_COMPLETE_UI: NEXT_LOCKED - stopping playback');
          _saveProgress();
          if (_globalAudioHandler != null) {
            await _globalAudioHandler!.pause();
          }
        }
      } else {
        // Auto-play is OFF - stop at end of chapter
        AppLogger.audio('AUTOPLAY: Auto-play is OFF - stopping at end of chapter $chapterIndex');
        _saveProgress();
        if (_globalAudioHandler != null) {
          await _globalAudioHandler!.pause();
        }
      }
    } else {
      // Last chapter of current audiobook completed
      AppLogger.audio('AUTOPLAY: Last chapter complete - audiobook finished, platform=${Platform.isIOS ? "iOS" : "Android"}');

      // Clear any loading state that might be stuck (especially important for iOS)
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }

      _saveProgress(completed: true);

      // DEBUG: Log all playlist state values for troubleshooting
      // Using captured values to ensure consistency
      AppLogger.audio('PLAYLIST_DEBUG: playlistId=${currentState.playlistId}, '
          'itemsCount=$playlistItemsCount, '
          'currentIndex=$playlistIndex, '
          'isActive=$isPlaylistActive, '
          'hasNext=$hasNextPlaylistItem, '
          'autoPlayNext=$autoPlayNext');

      // PLAYLIST AUTO-ADVANCE: If playing from a playlist, move to next item
      // CRITICAL: Use captured values (isPlaylistActive, hasNextPlaylistItem)
      // to avoid race conditions where state might change during async operations
      // NOTE: This runs on BOTH iOS and Android - playlist auto-advance is handled here, not in handler
      if (isPlaylistActive && hasNextPlaylistItem && autoPlayNext) {
        AppLogger.audio('PLAYLIST: Audiobook finished, advancing to next playlist item '
            '(current=$playlistIndex, total=$playlistItemsCount)');
        await _playNextPlaylistItem();
      } else if (isPlaylistActive) {
        AppLogger.audio('PLAYLIST: Playlist playback complete (no more items or auto-play off)');
        // Clear playlist state when done
        if (mounted) {
          state = state.clearPlaylist();
        }
      }
    }

    // Reset guard flag after completion (with delay to debounce rapid events)
    Future.delayed(AudioConfig.chapterCompleteGuardReset, () {
      _chapterCompleteInProgress = false;
    });
  }

  // ============================================
  // PLAYLIST PLAYBACK METHODS
  // ============================================

  /// Start playing a playlist from a specific index.
  /// This loads the audiobook at that index and begins playback.
  ///
  /// [playlistId] - The playlist being played
  /// [items] - Ordered list of playlist items
  /// [startIndex] - Which item to start from (0-based)
  Future<void> playFromPlaylist({
    required String playlistId,
    required List<PlaylistItem> items,
    required int startIndex,
  }) async {
    if (items.isEmpty) {
      AppLogger.w('PLAYLIST: Cannot play - empty playlist');
      return;
    }

    if (startIndex < 0 || startIndex >= items.length) {
      AppLogger.e('PLAYLIST: Invalid start index $startIndex for playlist with ${items.length} items');
      startIndex = 0;
    }

    AppLogger.audio('PLAYLIST: Starting playlist $playlistId from index $startIndex (${items.length} items)');

    // THREAD-SAFETY: Store an unmodifiable copy of the list to prevent
    // external modifications from affecting our playlist state.
    final safeItems = List<PlaylistItem>.unmodifiable(items);

    // Set playlist state
    state = state.copyWith(
      playlistId: playlistId,
      playlistItems: safeItems,
      currentPlaylistIndex: startIndex,
    );

    // DEBUG: Verify state was set correctly
    AppLogger.audio('PLAYLIST_DEBUG: After state set - playlistId=${state.playlistId}, '
        'itemsCount=${state.playlistItems.length}, currentIndex=${state.currentPlaylistIndex}');

    // Load and play the first item
    await _loadAndPlayPlaylistItem(startIndex);
  }

  /// Load and play a specific item from the current playlist.
  /// THREAD-SAFETY: Captures playlist snapshot atomically to prevent IndexError
  /// if the playlist is modified during async operations.
  Future<void> _loadAndPlayPlaylistItem(int playlistIndex) async {
    // CRITICAL: Capture playlist state atomically to prevent race conditions.
    // The list could be modified between the check and the access otherwise.
    final currentState = state;
    final playlistItems = List<PlaylistItem>.unmodifiable(currentState.playlistItems);
    final playlistId = currentState.playlistId;

    if (playlistId == null || playlistItems.isEmpty) {
      AppLogger.e('PLAYLIST: No active playlist');
      return;
    }

    if (playlistIndex < 0 || playlistIndex >= playlistItems.length) {
      AppLogger.e('PLAYLIST: Invalid playlist index $playlistIndex (list has ${playlistItems.length} items)');
      return;
    }

    // Safe access using the captured snapshot
    final item = playlistItems[playlistIndex];
    final audiobookId = item.audiobookId;

    AppLogger.audio('PLAYLIST: Loading item $playlistIndex - audiobook $audiobookId (${item.titleFa ?? "unknown"})');

    // Update current index before loading
    state = state.copyWith(currentPlaylistIndex: playlistIndex);

    try {
      // Fetch audiobook details and chapters from database
      // Uses timeout to prevent app freeze on slow networks
      final supabase = Supabase.instance.client;

      // Include book_metadata and music_metadata for narrator/artist info
      // (not profiles which is the uploader account, not the actual narrator/artist)
      final results = await Future.wait([
        supabase
            .from('audiobooks')
            .select('*, categories(name_fa), book_metadata(narrator_name), music_metadata(artist_name, featured_artists)')
            .eq('id', audiobookId)
            .maybeSingle(),
        supabase
            .from('chapters')
            .select('*')
            .eq('audiobook_id', audiobookId)
            .order('chapter_index', ascending: true),
      ]).timeout(AudioConfig.databaseQueryTimeout);

      final audiobook = results[0] as Map<String, dynamic>?;
      final chapters = List<Map<String, dynamic>>.from(results[1] as List);

      // Handle case where audiobook doesn't exist or isn't accessible
      if (audiobook == null) {
        AppLogger.e('PLAYLIST: Audiobook $audiobookId not found or not accessible');
        state = state.copyWith(
          errorType: AudioErrorType.audioNotFound,
          errorMessage: 'کتاب صوتی یافت نشد',
        );
        return;
      }

      if (chapters.isEmpty) {
        AppLogger.e('PLAYLIST: No chapters for audiobook $audiobookId');
        state = state.copyWith(
          errorType: AudioErrorType.audioNotFound,
          errorMessage: 'هیچ فصلی برای پخش وجود ندارد',
        );
        return;
      }

      // Check ownership/entitlement for this audiobook
      // NOTE(Issue 1.2 fix): Added robust entitlement check with logging
      final user = supabase.auth.currentUser;
      bool isOwned = false;
      final isFree = audiobook['is_free'] == true;

      AppLogger.audio('PLAYLIST_ENTITLEMENT: Checking access for audiobook $audiobookId - '
          'isFree=$isFree, userId=${user?.id ?? "null"}');

      if (user != null && !isFree) {
        // ENTITLEMENT CHECK WITH RETRY: Prevents false lockout on transient errors
        // Try up to 2 times before failing
        for (int attempt = 1; attempt <= 2; attempt++) {
          try {
            // Query the entitlements table directly for reliability
            // NOTE(Issue 1.2 fix): Using 'entitlements' table directly instead of view
            // to avoid issues if the view doesn't exist yet
            final entitlement = await supabase
                .from('entitlements')
                .select('id')
                .eq('user_id', user.id)
                .eq('audiobook_id', audiobookId)
                .maybeSingle()
                .timeout(AudioConfig.databaseQueryTimeout);
            isOwned = entitlement != null;
            AppLogger.audio('PLAYLIST_ENTITLEMENT: Result - isOwned=$isOwned (attempt $attempt)');
            break; // Success, exit retry loop
          } catch (e) {
            AppLogger.e('PLAYLIST_ENTITLEMENT: Error checking entitlement (attempt $attempt)', error: e);
            if (attempt == 2) {
              // Last attempt failed - check if chapter has preview flag as fallback
              // This prevents completely blocking the user on network errors
              final targetChapter = chapters.isNotEmpty ? chapters[0] : null;
              final hasPreviewChapter = targetChapter?['is_preview'] == true;
              if (hasPreviewChapter) {
                AppLogger.audio('PLAYLIST_ENTITLEMENT: Entitlement check failed but chapter is preview - allowing');
                isOwned = false; // Not owned but can play preview
              } else {
                // Set error state so user knows something went wrong
                AppLogger.w('PLAYLIST_ENTITLEMENT: Entitlement check failed - assuming not owned, '
                    'user may need to check connection');
                isOwned = false;
              }
            } else {
              // Wait briefly before retry
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
          }
        }
      } else if (isFree) {
        AppLogger.audio('PLAYLIST_ENTITLEMENT: Book is free - skipping ownership check');
      }

      // Determine which chapter(s) to play based on playlist item type
      final isSingleChapter = item.chapterIndex != null;
      final startChapterIndex = item.chapterIndex ?? 0;

      // For single chapter items, extract just that chapter
      // This ensures when it completes, playlist auto-advance triggers
      List<Map<String, dynamic>> chaptersToPlay;
      int playFromIndex;

      if (isSingleChapter) {
        // Validate the chapter index exists
        if (startChapterIndex < 0 || startChapterIndex >= chapters.length) {
          AppLogger.e('PLAYLIST: Invalid chapter index $startChapterIndex for audiobook $audiobookId');
          state = state.copyWith(
            errorType: AudioErrorType.audioNotFound,
            errorMessage: 'فصل مورد نظر یافت نشد',
          );
          return;
        }
        // Single chapter: pass only that chapter (so completion triggers playlist advance)
        chaptersToPlay = [chapters[startChapterIndex]];
        playFromIndex = 0;
        AppLogger.audio('PLAYLIST: Single chapter mode - playing chapter $startChapterIndex');
      } else {
        // Whole book: play all chapters from the beginning
        chaptersToPlay = chapters;
        playFromIndex = 0;
      }

      // Check if the target chapter is playable
      // NOTE(Issue 1.2 fix): Added detailed logging for playability check
      final targetChapter = chaptersToPlay[playFromIndex];
      final targetChapterPreview = targetChapter['is_preview'] == true;

      AppLogger.audio('PLAYLIST_PLAYABILITY: audiobook=$audiobookId, isOwned=$isOwned, '
          'isFree=$isFree, isPreview=$targetChapterPreview');

      final playlistAccessResult = AccessGateService.checkAccess(
        isOwned: isOwned,
        isFree: isFree,
        isSubscriptionActive: state.isSubscriptionActive,
        isPreviewContent: targetChapterPreview,
      );

      if (!playlistAccessResult.canAccess) {
        AppLogger.w('PLAYLIST: Chapter locked - ${playlistAccessResult.type}');
        state = state.copyWith(
          errorType: AudioErrorType.unauthorized,
          errorMessage: playlistAccessResult.needsSubscription
              ? 'برای دسترسی به این محتوا، اشتراک فعال نیاز است'
              : 'برای گوش دادن به این محتوا، آن را خریداری کنید',
        );
        // Do NOT auto-advance - let user see the error
        return;
      }

      AppLogger.audio('PLAYLIST: Playing audiobook $audiobookId - '
          '${isSingleChapter ? "single chapter $startChapterIndex" : "all ${chapters.length} chapters"} '
          '(owned=$isOwned, free=$isFree)');

      // DEBUG: Log state before calling play()
      AppLogger.audio('PLAYLIST_DEBUG: Before play() - playlistId=${state.playlistId}, '
          'itemsCount=${state.playlistItems.length}, currentIndex=${state.currentPlaylistIndex}');

      // Play the audiobook/chapter using existing play() method
      await play(
        audiobook: audiobook,
        chapters: chaptersToPlay,
        chapterIndex: playFromIndex,
        isOwned: isOwned,
        isSubscriptionActive: state.isSubscriptionActive,
      );

      // DEBUG: Log state after calling play()
      AppLogger.audio('PLAYLIST_DEBUG: After play() - playlistId=${state.playlistId}, '
          'itemsCount=${state.playlistItems.length}, currentIndex=${state.currentPlaylistIndex}');

    } catch (e, st) {
      AppLogger.e('PLAYLIST: Error loading audiobook $audiobookId', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorType: AudioErrorType.playbackFailed,
        errorMessage: 'خطا در بارگذاری محتوا',
      );
    }
  }

  /// Advance to the next item in the playlist.
  /// THREAD-SAFETY: Captures state atomically before async operation.
  Future<void> _playNextPlaylistItem() async {
    // CRITICAL: Capture state atomically to calculate next index safely.
    // Both hasNextPlaylistItem and currentPlaylistIndex must be from same snapshot.
    final currentState = state;
    final hasNext = currentState.hasNextPlaylistItem;
    final currentIndex = currentState.currentPlaylistIndex;

    if (!hasNext) {
      AppLogger.audio('PLAYLIST: No next item to play');
      return;
    }

    final nextIndex = currentIndex + 1;
    AppLogger.audio('PLAYLIST: Advancing to next item at index $nextIndex');
    await _loadAndPlayPlaylistItem(nextIndex);
  }

  /// Clear the playlist queue and stop playlist playback mode.
  /// Does NOT stop the current audio - just clears the queue.
  void clearPlaylistQueue() {
    if (mounted) {
      state = state.clearPlaylist();
      AppLogger.audio('PLAYLIST: Queue cleared');
    }
  }

  // ============================================
  // PROGRESS CALCULATION SYSTEM
  // ============================================
  // Album-level completion is calculated as:
  //   completion_percentage = (sum of listened seconds across all chapters)
  //                           / (sum of chapter durations) * 100
  //
  // Key rules:
  // - Each chapter's listened time is capped at its duration (prevents >100%)
  // - Chapters with ≥95% listened count as 100% complete (completion threshold)
  // - Overall percentage ≥98% is displayed as 100% (near-completion rounding)
  // - is_completed=true only when explicitly completed (last chapter finishes)
  // ============================================

  /// Completion threshold: if a chapter is ≥95% listened, count as fully complete
  static const double _chapterCompletionThreshold = 0.95;

  /// Near-completion threshold: if album is ≥98% complete, round to 100%
  static const double _albumNearCompletionThreshold = 0.98;

  /// Save progress to database with exponential backoff retry.
  /// This ensures progress isn't lost due to transient network issues.
  Future<void> _saveProgressWithRetry(
    Map<String, dynamic> progressData,
    Map<String, dynamic> sessionData,
  ) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < AudioConfig.progressSaveMaxRetries) {
      try {
        // Save listening progress
        await Supabase.instance.client.from('listening_progress').upsert(
          progressData,
          onConflict: 'user_id,audiobook_id',
        ).timeout(AudioConfig.databaseQueryTimeout);

        // Save listening session (for daily stats)
        await Supabase.instance.client.from('listening_sessions').upsert(
          sessionData,
          onConflict: 'user_id,audiobook_id,session_date',
        ).timeout(AudioConfig.databaseQueryTimeout);

        AppLogger.audio('Progress saved (attempt ${attempt + 1})', position: state.position);
        return; // Success - exit retry loop
      } on TimeoutException catch (e) {
        lastError = e;
        attempt++;
        if (attempt < AudioConfig.progressSaveMaxRetries) {
          // Exponential backoff: 2s, 4s, 8s...
          final delay = AudioConfig.progressSaveRetryDelay * (1 << (attempt - 1));
          AppLogger.w('Progress save timeout (attempt $attempt/${AudioConfig.progressSaveMaxRetries}), retrying in ${delay.inSeconds}s');
          await Future<void>.delayed(delay);
        }
      } catch (e) {
        // For non-timeout errors, don't retry (likely auth or data issue)
        AppLogger.e('Progress save failed (non-retryable)', error: e);
        rethrow;
      }
    }

    // All retries exhausted
    AppLogger.e('Progress save failed after ${AudioConfig.progressSaveMaxRetries} attempts', error: lastError);
    // Don't rethrow - we don't want to interrupt playback for progress save failures
  }

  Future<void> _saveProgress({bool completed = false}) async {
    if (state.audiobook == null) return;

    // LOCAL BACKUP: Save position to SharedPreferences immediately.
    // This is a lightweight fallback that survives app kills and offline scenarios.
    // The Supabase save below is the primary source of truth.
    _savePositionLocally();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Safety check for chapters
      if (state.chapters.isEmpty ||
          state.currentChapterIndex >= state.chapters.length) {
        return;
      }

      final chapter = state.chapters[state.currentChapterIndex];
      final chapterId = chapter['id'] as int?;

      // Safety check: chapter must have a valid ID
      if (chapterId == null || chapterId <= 0) {
        AppLogger.w('Cannot save progress: invalid chapter ID');
        return;
      }

      // Get current chapter duration (from player or database)
      final currentChapterDuration = (chapter['duration_seconds'] as int?) ??
          state.duration.inSeconds;

      // Cap current position at chapter duration (prevents drift beyond 100%)
      final currentPositionCapped = state.position.inSeconds.clamp(0,
          currentChapterDuration > 0 ? currentChapterDuration : state.position.inSeconds);

      // Calculate total completed seconds across ALL chapters
      // For previous chapters: if we've passed them, count as fully listened
      // For current chapter: use actual capped position
      int completedSeconds = 0;
      int totalDuration = 0;

      for (int i = 0; i < state.chapters.length; i++) {
        final chapterDuration = (state.chapters[i]['duration_seconds'] as int?) ?? 0;
        totalDuration += chapterDuration;

        if (i < state.currentChapterIndex) {
          // Previous chapters: count as fully listened
          completedSeconds += chapterDuration;
        } else if (i == state.currentChapterIndex) {
          // Current chapter: use actual position, capped at duration
          // Apply completion threshold: if ≥95% through, count as complete
          if (chapterDuration > 0) {
            final chapterProgress = currentPositionCapped / chapterDuration;
            if (chapterProgress >= _chapterCompletionThreshold) {
              completedSeconds += chapterDuration; // Count as fully complete
            } else {
              completedSeconds += currentPositionCapped;
            }
          } else {
            completedSeconds += currentPositionCapped;
          }
        }
        // Future chapters: add 0 (not listened yet)
      }

      // Fallback: use audiobook's stored total duration if chapters don't have it
      if (totalDuration == 0) {
        final audiobookDuration = state.audiobook!['total_duration_seconds'];
        if (audiobookDuration != null && (audiobookDuration as num).toInt() > 0) {
          totalDuration = audiobookDuration.toInt();
        }
      }

      // Calculate percentage
      int percentage = 0;
      if (totalDuration > 0) {
        final rawPercentage = (completedSeconds * 100.0) / totalDuration;

        // Apply near-completion rounding: if ≥98%, show as 100%
        if (rawPercentage >= _albumNearCompletionThreshold * 100) {
          percentage = 100;
        } else {
          percentage = rawPercentage.round().clamp(0, 100);
        }
      } else if (completedSeconds > 0) {
        // Fallback: estimate based on current chapter only
        final currentDuration = state.duration.inSeconds;
        if (currentDuration > 0) {
          percentage = ((state.position.inSeconds * 100) ~/ currentDuration).clamp(0, 99);
        }
      }

      // Force 100% if explicitly completed
      if (completed) percentage = 100;

      // Debug logging for progress tracking
      AppLogger.d('PROGRESS_SAVE: audiobookId=${state.audiobook!['id']}, '
          'chapterId=$chapterId, chapterIndex=${state.currentChapterIndex}, '
          'pos=${state.position.inSeconds}s, chapterDur=$currentChapterDuration, '
          'completedSec=$completedSeconds, totalDur=$totalDuration, pct=$percentage%');

      // Calculate current listen time if still playing
      int currentListenTime = _totalListenTime;
      if (_playStartTime != null) {
        currentListenTime += DateTime.now().difference(_playStartTime!).inSeconds;
      }

      // Track today's session for accurate daily stats
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

      // Calculate today's listen time increment
      int todayIncrement = 0;
      if (_playStartTime != null) {
        todayIncrement = DateTime.now().difference(_playStartTime!).inSeconds;
      }

      // Reset session tracking if date changed (new day)
      if (_todaySessionDate != today) {
        _todaySessionDate = today;
        _todaySessionTime = 0;
        _todayChaptersListened.clear();
      }

      // Track current chapter as listened for today's stats
      if (state.currentChapterIndex >= 0 && state.chapters.isNotEmpty) {
        final currentChapterId = state.chapters[state.currentChapterIndex]['id'] as int?;
        if (currentChapterId != null) {
          _todayChaptersListened.add(currentChapterId);
        }
      }

      // Accumulate today's session time
      final todayTotalTime = _todaySessionTime + todayIncrement;

      // Prepare data for database saves
      final progressData = {
        'user_id': user.id,
        'audiobook_id': state.audiobook!['id'],
        'chapter_id': chapterId,
        'current_chapter_id': chapterId,
        'current_chapter_index': state.currentChapterIndex,
        'position_seconds': state.position.inSeconds,
        'playback_speed': state.playbackSpeed,
        'is_completed': completed,
        'completion_percentage': percentage,
        'total_listen_time_seconds': currentListenTime,
        'last_played_at': DateTime.now().toIso8601String(),
      };

      final sessionData = {
        'user_id': user.id,
        'audiobook_id': state.audiobook!['id'],
        'session_date': today,
        'duration_seconds': todayTotalTime,
        'chapters_listened': _todayChaptersListened.length,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save with retry logic (exponential backoff)
      await _saveProgressWithRetry(progressData, sessionData);

      // Invalidate home screen cache to show updated progress immediately
      _ref.invalidate(continueListeningProvider);
      _ref.invalidate(homeRecentlyPlayedProvider);
      AppLogger.d('HOME_CACHE: invalidated after _saveProgress');
    } catch (e) {
      AppLogger.e('Error saving progress', error: e);
      // Don't set error state - progress save failure shouldn't interrupt playback
    }
  }

  /// Save progress immediately (for external calls)
  Future<void> saveProgressNow() async {
    await _saveProgress();
  }

  // ==========================================================================
  // LOCAL POSITION BACKUP (SharedPreferences)
  // ==========================================================================

  /// Save current playback position to SharedPreferences as a lightweight local backup.
  /// This survives app kills and offline scenarios where Supabase save might fail.
  /// Called at the start of _saveProgress (before network save) and on app lifecycle changes.
  void _savePositionLocally() {
    if (state.audiobook == null || _cachedPrefs == null) return;

    final audiobookId = state.audiobook!['id'];
    if (audiobookId == null) return;

    _cachedPrefs!.setInt('last_audiobook_id', audiobookId as int);
    _cachedPrefs!.setInt('last_chapter_index', state.currentChapterIndex);
    _cachedPrefs!.setInt('last_position_seconds', state.position.inSeconds);
    _cachedPrefs!.setString('last_saved_at', DateTime.now().toIso8601String());
  }

  /// Retrieve the last locally saved position for a given audiobook.
  /// Returns null if no saved position exists or if it's for a different audiobook.
  /// This is used as a fallback when the Supabase query fails or the app was killed.
  static ({int chapterIndex, int positionSeconds, DateTime savedAt})?
      getLastSavedPosition(SharedPreferences prefs, int audiobookId) {
    final savedId = prefs.getInt('last_audiobook_id');
    if (savedId != audiobookId) return null;

    final chapterIndex = prefs.getInt('last_chapter_index');
    final positionSeconds = prefs.getInt('last_position_seconds');
    final savedAtStr = prefs.getString('last_saved_at');

    if (chapterIndex == null || positionSeconds == null || savedAtStr == null) {
      return null;
    }

    final savedAt = DateTime.tryParse(savedAtStr);
    if (savedAt == null) return null;

    // Ignore positions older than 30 days (stale data)
    if (DateTime.now().difference(savedAt).inDays > 30) return null;

    return (
      chapterIndex: chapterIndex,
      positionSeconds: positionSeconds,
      savedAt: savedAt,
    );
  }

  /// Clear the local position backup (e.g., on logout or stop)
  void _clearLocalPosition() {
    _cachedPrefs?.remove('last_audiobook_id');
    _cachedPrefs?.remove('last_chapter_index');
    _cachedPrefs?.remove('last_position_seconds');
    _cachedPrefs?.remove('last_saved_at');
  }

  /// Update chapter duration in database if it's currently 0
  /// This ensures proper progress calculation after first playback
  ///
  /// RACE CONDITION FIX: Takes captured chapter index and chapters list as parameters
  /// to ensure we update the correct chapter even if user skips rapidly.
  Future<void> _updateChapterDurationIfNeeded(
    Duration duration,
    int capturedChapterIndex,
    List<Map<String, dynamic>> capturedChapters,
  ) async {
    if (state.audiobook == null || capturedChapters.isEmpty) return;
    if (capturedChapterIndex >= capturedChapters.length) return;

    final chapter = capturedChapters[capturedChapterIndex];
    final chapterId = chapter['id'] as int?;
    final existingDuration = (chapter['duration_seconds'] as int?) ?? 0;

    // Only update if duration is not set (0) and we have a valid new duration
    if (chapterId == null || existingDuration > 0 || duration.inSeconds <= 0) {
      return;
    }

    try {
      // Update chapter duration in database
      await Supabase.instance.client
          .from('chapters')
          .update({'duration_seconds': duration.inSeconds})
          .eq('id', chapterId)
          .timeout(AudioConfig.databaseQueryTimeout);

      // Update local state to reflect the change - but only if still on the same chapter
      // to avoid corrupting state if user already switched chapters
      if (mounted && state.currentChapterIndex == capturedChapterIndex) {
        final updatedChapters = List<Map<String, dynamic>>.from(state.chapters);
        if (capturedChapterIndex < updatedChapters.length) {
          updatedChapters[capturedChapterIndex] = {
            ...updatedChapters[capturedChapterIndex],
            'duration_seconds': duration.inSeconds,
          };
          state = state.copyWith(chapters: updatedChapters);
        }
      }

      AppLogger.audio('Updated chapter $capturedChapterIndex duration: ${duration.inSeconds}s');

      // Also update audiobook total_duration_seconds
      await _updateAudiobookTotalDuration();
    } catch (e) {
      AppLogger.e('Error updating chapter duration', error: e);
    }
  }

  /// Update audiobook total duration based on sum of chapter durations
  Future<void> _updateAudiobookTotalDuration() async {
    if (state.audiobook == null) return;

    try {
      final audiobookId = state.audiobook!['id'] as int;

      // Get all chapters for this audiobook with their durations
      final response = await Supabase.instance.client
          .from('chapters')
          .select('duration_seconds')
          .eq('audiobook_id', audiobookId)
          .timeout(AudioConfig.databaseQueryTimeout);

      int totalDuration = 0;
      for (final chapter in response as List) {
        totalDuration += (chapter['duration_seconds'] as int?) ?? 0;
      }

      // Only update if we have a meaningful total duration
      if (totalDuration > 0) {
        await Supabase.instance.client
            .from('audiobooks')
            .update({'total_duration_seconds': totalDuration})
            .eq('id', audiobookId)
            .timeout(AudioConfig.databaseQueryTimeout);

        // Update local state
        final updatedAudiobook = Map<String, dynamic>.from(state.audiobook!);
        updatedAudiobook['total_duration_seconds'] = totalDuration;
        state = state.copyWith(audiobook: updatedAudiobook);

        AppLogger.audio('Updated audiobook total duration: ${totalDuration}s');
      }
    } catch (e) {
      AppLogger.e('Error updating audiobook total duration', error: e);
    }
  }

  @override
  void dispose() {
    // CRITICAL: Set dispose flag FIRST, before cancelling timers.
    // This ensures any in-flight timer callbacks see the flag and abort
    // before trying to modify state.
    _isDisposed = true;

    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _authSubscription?.cancel();
    // Only dispose player if we created it (not using global handler)
    if (_globalAudioHandler == null) {
      _player.dispose();
    }
    super.dispose();
  }
}

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier(ref);
});
