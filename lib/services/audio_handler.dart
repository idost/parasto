import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/config/env.dart';
import 'package:myna/config/audio_config.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/services/notification_permission_service.dart';
import 'package:myna/services/download_service.dart';

/// Custom AudioHandler that bridges just_audio with audio_service
/// for background playback and system media controls.
class MynaAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Stream subscriptions - CRITICAL: Store these to prevent memory leaks
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  // Audio session event subscriptions
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  // === SERIALIZED OPERATION QUEUE WITH CIRCUIT BREAKER ===
  // Ensures all audio operations (setAudioSource/play/pause/stop) run sequentially.
  // Prevents iOS "Loading interrupted" errors from overlapping operations.
  // Circuit breaker prevents cascading failures when player is in bad state.
  Future<void> _opQueue = Future.value();

  // Dedupe guard: track current loading request to ignore duplicates
  String? _currentLoadingKey;

  // === CIRCUIT BREAKER STATE ===
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;
  bool get _isCircuitOpen {
    if (_consecutiveFailures < AudioConfig.circuitBreakerFailureThreshold) {
      return false;
    }
    // Check if reset timeout has passed
    if (_circuitOpenedAt != null) {
      final elapsed = DateTime.now().difference(_circuitOpenedAt!);
      if (elapsed >= AudioConfig.circuitBreakerResetTimeout) {
        // Allow one test request through (half-open state)
        return false;
      }
    }
    return true;
  }

  void _recordSuccess() {
    if (_consecutiveFailures > 0) {
      AppLogger.audioNotif('[CIRCUIT_BREAKER] Operation succeeded, resetting failure count');
    }
    _consecutiveFailures = 0;
    _circuitOpenedAt = null;
  }

  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= AudioConfig.circuitBreakerFailureThreshold) {
      _circuitOpenedAt = DateTime.now();
      AppLogger.audioNotif('[CIRCUIT_BREAKER] OPEN - $_consecutiveFailures consecutive failures, '
          'blocking operations for ${AudioConfig.circuitBreakerResetTimeout.inSeconds}s');
    } else {
      AppLogger.audioNotif('[CIRCUIT_BREAKER] Failure recorded: $_consecutiveFailures/${AudioConfig.circuitBreakerFailureThreshold}');
    }
  }

  /// Enqueue an audio operation to run after all previous operations complete.
  /// Includes circuit breaker to prevent cascading failures.
  /// Exceptions inside fn are caught and logged but don't break the queue.
  Future<T> _enqueue<T>(Future<T> Function() fn, {String? opName}) async {
    // CIRCUIT BREAKER: Fail fast if circuit is open
    if (_isCircuitOpen) {
      AppLogger.audioNotif('[CIRCUIT_BREAKER] $opName REJECTED - circuit is open');
      throw StateError('Circuit breaker open - audio operations temporarily disabled');
    }

    final completer = _opQueue.then((_) async {
      try {
        // Add timeout to prevent single operation from blocking queue indefinitely
        final result = await fn().timeout(
          AudioConfig.operationTimeout,
          onTimeout: () {
            throw TimeoutException('Operation $opName timed out after ${AudioConfig.operationTimeout.inSeconds}s');
          },
        );
        _recordSuccess();
        return result;
      } catch (e, st) {
        // Catch "Loading interrupted" specifically - this is expected when operations overlap
        // Don't count as failure for circuit breaker
        if (e.toString().contains('Loading interrupted') ||
            e.toString().contains('abort')) {
          AppLogger.audioNotif('[SERIAL] $opName aborted; superseded by newer request');
          rethrow; // Still rethrow so caller knows it was cancelled
        }

        // Record failure for circuit breaker (but not for aborts/interrupts)
        _recordFailure();

        AppLogger.audioNotif('[SERIAL] $opName failed: $e');
        AppLogger.e('[SERIAL] Operation failed', error: e, stackTrace: st);
        rethrow;
      }
    });
    // Update queue to wait for this operation (ignore errors for queue chaining)
    _opQueue = completer.then((_) {}).catchError((_) {});
    return completer;
  }

  /// Reset circuit breaker manually (e.g., when user explicitly retries)
  void resetCircuitBreaker() {
    if (_consecutiveFailures > 0 || _circuitOpenedAt != null) {
      AppLogger.audioNotif('[CIRCUIT_BREAKER] Manual reset');
      _consecutiveFailures = 0;
      _circuitOpenedAt = null;
    }
  }

  // Current audiobook/chapter metadata
  Map<String, dynamic>? _currentAudiobook;
  List<Map<String, dynamic>> _chapters = [];
  int _currentChapterIndex = 0;

  // Current playback speed - preserved across chapters
  double _currentSpeed = 1.0;

  // === iOS BACKGROUND AUTO-NEXT STATE ===
  // On iOS, when app is in background, Flutter streams may not fire reliably.
  // The audio_handler runs in native audio service context and can detect completion.
  // We cache the playback context so handler can auto-advance without Flutter UI.
  bool _autoPlayNextEnabled = true; // Default true, updated from AudioNotifier
  bool _isOwned = false; // Whether user owns the audiobook (can play all chapters)
  bool _isFreeAudiobook = false; // Whether audiobook is free
  bool _autoNextInFlight = false; // Guard to prevent duplicate auto-next triggers
  bool _sleepTimerActive = false; // If true, don't auto-next (sleep timer should stop)

  // === SIMPLIFIED PLAYBACK STATE ===
  // Single flag: when true, user has explicitly requested pause, so don't auto-resume
  bool _userRequestedPause = false;

  // === AUDIO SESSION IDEMPOTENCY ===
  // Track if audio session is already active to prevent redundant setActive(true) calls.
  // Rapid activation calls can cause audio focus issues on iOS.
  bool _audioSessionActive = false;

  // Flag to indicate we're in the middle of auto-next, so completion detection should be skipped
  bool _isAutoNexting = false;

  // Callbacks for progress saving and chapter transitions
  void Function()? onProgressSave;
  void Function(int chapterIndex)? onChapterComplete;
  /// Called when playback naturally completes (reaches end of audio).
  /// This is critical for background auto-next to work properly.
  void Function()? onPlaybackComplete;

  MynaAudioHandler() {
    AppLogger.audioNotif('HANDLER: MynaAudioHandler constructor called');
    _init();
  }

  AudioPlayer get player => _player;
  Map<String, dynamic>? get currentAudiobook => _currentAudiobook;
  List<Map<String, dynamic>> get chapters => _chapters;
  int get currentChapterIndex => _currentChapterIndex;
  double get currentSpeed => _currentSpeed;

  // === iOS BACKGROUND AUTO-NEXT: Setters for cached state ===
  // Called from AudioNotifier to sync playback context with handler

  /// Update autoPlayNext setting (called when user toggles setting)
  void setAutoPlayNext(bool value) {
    _autoPlayNextEnabled = value;
    AppLogger.audio('[AUTO_NEXT_IOS] Handler: autoPlayNext set to $value');
  }

  /// Update sleep timer state (called when sleep timer is set/cancelled)
  void setSleepTimerActive(bool value) {
    _sleepTimerActive = value;
    AppLogger.audio('[AUTO_NEXT_IOS] Handler: sleepTimerActive set to $value');
  }

  /// Update ownership state (called when playback starts or ownership changes)
  void setOwnershipState({required bool isOwned, required bool isFreeAudiobook}) {
    _isOwned = isOwned;
    _isFreeAudiobook = isFreeAudiobook;
    AppLogger.audio('[AUTO_NEXT_IOS] Handler: ownership updated - isOwned=$isOwned, isFree=$isFreeAudiobook');
  }

  Future<void> _init() async {
    AppLogger.audioNotif('HANDLER: _init() started - configuring audio session');
    AppLogger.audio('HANDLER(iOS): Initializing audio session...');

    // Configure audio session for audiobook playback
    // iOS: Using .playback category with .spokenAudio mode for best audiobook experience
    // The .playback category allows audio to continue when screen is locked or app is backgrounded
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      // Use .none to properly handle interruptions from other apps
      // With .none, our app will properly pause when another app takes audio focus
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
      // .spokenAudio mode optimizes for voice content (audiobooks, podcasts)
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Activate the session for background playback
    await session.setActive(true);
    AppLogger.audio('HANDLER(iOS): Audio session configured with playback category (no ducking)');

    // Handle audio interruptions (phone calls, other apps starting audio)
    // CRITICAL for Android: This only fires if audio focus was properly requested via setActive(true)
    // CRITICAL for iOS: This handles phone calls, Siri, other audio apps taking focus
    // MEMORY LEAK FIX: Store subscription so it can be cancelled in dispose()
    _interruptionSubscription = session.interruptionEventStream.listen((event) {
      final wasPlaying = _player.playing;
      if (Platform.isIOS) {
        // [AUDIO_NOTIF] iOS-specific logging for easier debugging in Xcode
        AppLogger.audioNotif('[AUDIO_NOTIF] IOS_INTERRUPT: begin=${event.begin}, type=${event.type}, wasPlaying=$wasPlaying');
      } else {
        AppLogger.audioNotif('[AUDIO_NOTIF] INTERRUPT: begin=${event.begin}, type=${event.type}, platform=Android, playing=$wasPlaying');
      }

      if (event.begin) {
        // Audio interrupted - pause playback
        if (wasPlaying) {
          if (Platform.isIOS) {
            AppLogger.audioNotif('[AUDIO_NOTIF] IOS_INTERRUPT: Pausing due to interruption (type=${event.type})');
          } else {
            AppLogger.audioNotif('[AUDIO_NOTIF] INTERRUPT: Pausing due to interruption (type=${event.type})');
          }
          pause();
        } else {
          AppLogger.audioNotif('[AUDIO_NOTIF] ${Platform.isIOS ? "IOS_INTERRUPT" : "INTERRUPT"}: Already paused, no action needed');
        }
      } else {
        // Interruption ended
        // SAFE BEHAVIOR: Stay paused - let user manually resume
        // This prevents unexpected audio when user is done with other app/call
        if (Platform.isIOS) {
          AppLogger.audioNotif('[AUDIO_NOTIF] IOS_INTERRUPT: Interruption ended - staying paused (user must manually resume)');
        } else {
          AppLogger.audioNotif('[AUDIO_NOTIF] INTERRUPT: Interruption ended - staying paused (user must manually resume)');
        }
      }
    });

    // Handle becoming noisy (headphones unplugged)
    // MEMORY LEAK FIX: Store subscription so it can be cancelled in dispose()
    _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
      final wasPlaying = _player.playing;
      if (Platform.isIOS) {
        AppLogger.audioNotif('[AUDIO_NOTIF] IOS_NOISY: Headphones disconnected event, wasPlaying=$wasPlaying');
      } else {
        AppLogger.audioNotif('[AUDIO_NOTIF] NOISY: Headphones unplugged event, platform=Android, playing=$wasPlaying');
      }
      // Pause when headphones are unplugged
      if (wasPlaying) {
        if (Platform.isIOS) {
          AppLogger.audioNotif('[AUDIO_NOTIF] IOS_NOISY: Pausing playback');
        } else {
          AppLogger.audioNotif('[AUDIO_NOTIF] NOISY: Pausing playback');
        }
        pause();
      }
    });

    // Listen to player state and broadcast to system
    AppLogger.audioNotif('HANDLER: Setting up playbackEventStream listener');
    _playbackEventSubscription = _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.audioNotif('HANDLER: playbackEventStream ERROR: $error');
        AppLogger.e('HANDLER: playbackEventStream error', error: error, stackTrace: stackTrace);
      },
    );

    // Listen for completion
    _processingStateSubscription = _player.processingStateStream.listen((state) {
      // [DIAG] Log all processing state changes for debugging auto-next
      // Include audiobook ID and loading key for cross-book debugging
      final audiobookId = _currentAudiobook?['id'] ?? 'null';
      if (state == ProcessingState.completed || state == ProcessingState.ready || state == ProcessingState.loading) {
        AppLogger.audioNotif('[AUTO_NEXT_DIAG] processingStateStream: state=$state, '
            'audiobookId=$audiobookId, chapterIndex=$_currentChapterIndex, loadKey=$_currentLoadingKey, '
            'position=${_player.position.inSeconds}s/${_player.duration?.inSeconds ?? 0}s, '
            'platform=${Platform.isIOS ? "iOS" : "Android"}');
      }

      if (state == ProcessingState.completed) {
        // [AUTO_NEXT] Log completion detection at handler level
        final currentMediaId = mediaItem.valueOrNull?.id ?? 'null';
        final chapterIdx = _currentChapterIndex;
        final isPlaying = _player.playing;
        AppLogger.audioNotif('[AUTO_NEXT] CH_COMPLETE_HANDLER(processingState): processingState=completed, '
            'audiobookId=$audiobookId, mediaItemId=$currentMediaId, chapterIndex=$chapterIdx, playing=$isPlaying');
        _handleCompletion();
      }
    });

    // FIX: Listen for duration changes from the player
    // When just_audio discovers the actual duration (after loading audio source),
    // update the MediaItem so iOS Control Center shows correct duration instead of -:--
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && duration > Duration.zero) {
        _updateMediaItemDuration(duration);
      }
    });

    AppLogger.audioNotif('HANDLER: _init() completed - audio handler ready');
    AppLogger.audio('Audio handler initialized');
  }

  /// Update the MediaItem with the actual duration discovered by the player.
  /// This is critical for iOS Control Center to show correct duration instead of -:--
  void _updateMediaItemDuration(Duration duration) {
    final currentItem = mediaItem.valueOrNull;
    if (currentItem == null) return;

    // Only update if duration actually changed (avoid unnecessary broadcasts)
    if (currentItem.duration == duration) return;

    AppLogger.audio(
      'HANDLER(iOS): Updating MediaItem duration from ${currentItem.duration?.inSeconds ?? 0}s to ${duration.inSeconds}s',
    );

    // Create updated MediaItem with correct duration
    final updatedItem = currentItem.copyWith(duration: duration);
    mediaItem.add(updatedItem);

    // Re-broadcast state to ensure iOS Control Center picks up the new duration
    _broadcastState(_player.playbackEvent);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = _player.processingState;

    // Map just_audio states to audio_service states
    final audioProcessingState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[processingState] ?? AudioProcessingState.idle;

    // iOS BACKGROUND AUTO-NEXT FIX: Detect completion in playbackEventStream
    // processingStateStream doesn't fire reliably in iOS background, but playbackEventStream does
    if (processingState == ProcessingState.completed) {
      final currentMediaId = mediaItem.valueOrNull?.id ?? 'null';
      final chapterIdx = _currentChapterIndex;
      AppLogger.audioNotif('[AUTO_NEXT] CH_COMPLETE_HANDLER(playbackEvent): processingState=completed, '
          'mediaItemId=$currentMediaId, chapterIndex=$chapterIdx, playing=$playing');
      _handleCompletion();
    }

    // Log significant state transitions for Android notification debugging
    // These are the states that should trigger/update the notification
    if (processingState == ProcessingState.ready ||
        processingState == ProcessingState.loading ||
        processingState == ProcessingState.completed) {
      AppLogger.audioNotif('PLAYBACK_STATE: processingState=$processingState, '
          'audioProcessingState=$audioProcessingState, playing=$playing, '
          'position=${_player.position.inSeconds}s, buffered=${_player.bufferedPosition.inSeconds}s');
    }

    // FIX: Broadcast state with full controls for iOS lock screen
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 2, 4],
      processingState: audioProcessingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentChapterIndex,
    ));

    // Log when playing state changes (critical for notification visibility)
    if (processingState == ProcessingState.ready) {
      AppLogger.audioNotif('PLAYBACK_STATE: State broadcast complete - playing=$playing, '
          'controls=[skipToPrev, rewind, ${playing ? "pause" : "play"}, fastFwd, skipToNext]');
      AppLogger.audio('HANDLER: Playback state broadcast - playing=$playing, position=${_player.position.inSeconds}s');
    }
  }

  void _handleCompletion() {
    // GUARD: Skip completion handling if we're in the middle of auto-next transition
    // This prevents false triggers when stopping player before loading next chapter
    if (_isAutoNexting) {
      AppLogger.audioNotif('[AUTO_NEXT] CH_COMPLETE_HANDLER: SKIPPED - _isAutoNexting=true (mid-transition)');
      return;
    }

    // BACKGROUND PLAYBACK FIX: Notify AudioNotifier that playback completed.
    // When the app is in background, Flutter's stream listeners may not receive events
    // promptly. By actively calling the callback here (from audio_service's background
    // execution context), we ensure chapter auto-advance works even when app is minimized.

    final hasCallback = onPlaybackComplete != null;
    final audiobookId = _currentAudiobook?['id'] ?? 'null';
    AppLogger.audioNotif('[AUTO_NEXT] CH_COMPLETE_HANDLER: chapterIndex=$_currentChapterIndex, '
        'audiobookId=$audiobookId, hasCallback=$hasCallback, platform=${Platform.isIOS ? "iOS" : "Android"}');

    // === iOS BACKGROUND AUTO-NEXT ===
    // On iOS, we handle auto-next directly in the handler because:
    // 1. Flutter UI streams may not fire when app is suspended/background
    // 2. The audio_handler runs in native audio service context (reliable)
    // 3. We have cached all necessary context (autoPlayNext, isOwned, chapters)
    //
    // On Android, the callback to AudioNotifier works reliably, so we let it handle.
    if (Platform.isIOS) {
      AppLogger.audioNotif('[AUTO_NEXT] _handleCompletion: iOS detected - calling _handleAutoNextiOS()');
      _handleAutoNextiOS();
    } else {
      // Android: Notify AudioNotifier, which handles auto-next
      AppLogger.audioNotif('[AUTO_NEXT] _handleCompletion: Android detected - calling onPlaybackComplete callback');
      onPlaybackComplete?.call();
    }
  }

  /// iOS-specific auto-next handler that runs directly in the native audio service.
  /// This is more reliable than Flutter callbacks when app is in background.
  ///
  /// CRITICAL FOR iOS BACKGROUND: This method runs in the audio service's native context.
  /// Unlike Flutter streams which can be suspended when app is in background,
  /// the audio_service runs continuously. This is why we handle auto-next here for iOS.
  Future<void> _handleAutoNextiOS() async {
    final nextIndex = _currentChapterIndex + 1;
    AppLogger.audioNotif('[AUTO_NEXT_IOS] COMPLETION received, index=$_currentChapterIndex, nextIndex=$nextIndex');
    AppLogger.audioNotif('[AUTO_NEXT_IOS] === ENTRY === chapterIndex=$_currentChapterIndex, '
        'totalChapters=${_chapters.length}, autoPlayNext=$_autoPlayNextEnabled, '
        'sleepTimerActive=$_sleepTimerActive, autoNextInFlight=$_autoNextInFlight');

    // Guard: Prevent duplicate triggers
    if (_autoNextInFlight) {
      AppLogger.audioNotif('[AUTO_NEXT_IOS] GUARD: autoNextInFlight=true, ignoring duplicate');
      return;
    }
    _autoNextInFlight = true;
    _isAutoNexting = true; // Prevent false completion triggers during transition

    try {
      // Check if sleep timer should stop playback
      if (_sleepTimerActive) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] SLEEP_TIMER: Active, NOT advancing. Pausing.');
        await pause();
        // Still call callback so AudioNotifier can update UI/state
        onPlaybackComplete?.call();
        return;
      }

      // Check if auto-play is disabled
      if (!_autoPlayNextEnabled) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] AUTO_PLAY_OFF: Not advancing. Pausing.');
        await pause();
        onPlaybackComplete?.call();
        return;
      }

      // Check if there's a next chapter
      final nextIndex = _currentChapterIndex + 1;
      if (nextIndex >= _chapters.length) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] LAST_CHAPTER: No more chapters. Stopping.');
        onPlaybackComplete?.call();
        return;
      }

      // Check if user can play the next chapter
      final nextChapter = _chapters[nextIndex];
      final isNextPreview = nextChapter['is_preview'] == true;
      final canPlayNext = _isOwned || _isFreeAudiobook || isNextPreview;

      // [DIAG] Log next chapter map keys
      final chapterKeys = nextChapter.keys.toList();
      final hasAudioUrl = nextChapter.containsKey('audio_url') && nextChapter['audio_url'] != null;
      final hasStoragePath = nextChapter.containsKey('audio_storage_path') && nextChapter['audio_storage_path'] != null;
      final hasDuration = nextChapter.containsKey('duration_seconds');
      final hasIsPreview = nextChapter.containsKey('is_preview');
      AppLogger.audioNotif('[AUTO_NEXT_IOS] NEXT_CHAPTER_KEYS: keys=$chapterKeys');
      AppLogger.audioNotif('[AUTO_NEXT_IOS] NEXT_CHAPTER_FIELDS: audio_url=$hasAudioUrl, '
          'audio_storage_path=$hasStoragePath, duration_seconds=$hasDuration, is_preview=$hasIsPreview');

      AppLogger.audioNotif('[AUTO_NEXT_IOS] NEXT_CHECK: nextIndex=$nextIndex, '
          'isOwned=$_isOwned, isFree=$_isFreeAudiobook, isPreview=$isNextPreview, canPlay=$canPlayNext');

      if (!canPlayNext) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] LOCKED: Next chapter locked - reason: '
            '${!_isOwned ? "not owned" : ""}'
            '${!_isFreeAudiobook ? " not free" : ""}'
            '${!isNextPreview ? " not preview" : ""}. Stopping.');
        await pause();
        onPlaybackComplete?.call();
        return;
      }

      // === AUTO-ADVANCE TO NEXT CHAPTER ===
      AppLogger.audioNotif('[AUTO_NEXT_IOS] ADVANCING: Playing next chapter $nextIndex');

      // Safely capture audiobook reference — it could theoretically be cleared
      final audiobook = _currentAudiobook;
      if (audiobook == null) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] ERROR: _currentAudiobook is null during auto-next');
        onPlaybackComplete?.call();
        return;
      }

      // Check if the next chapter is downloaded locally
      final audiobookId = audiobook['id'] as int;
      final nextChapterId = nextChapter['id'] as int?;
      String? audioSource;
      bool isLocalFile = false;

      if (nextChapterId != null) {
        final downloadService = DownloadService();
        final localPath = downloadService.getLocalPath(audiobookId, nextChapterId);
        if (localPath != null && File(localPath).existsSync()) {
          audioSource = localPath;
          isLocalFile = true;
          AppLogger.audioNotif('[AUTO_NEXT_IOS] USING_LOCAL: Downloaded chapter found at $localPath');
        }
      }

      // Fall back to remote URL if not downloaded
      if (audioSource == null) {
        audioSource = _getChapterAudioUrl(nextChapter);
        final urlSource = nextChapter['audio_url'] != null ? 'audio_url' :
                         nextChapter['audio_storage_path'] != null ? 'audio_storage_path' : 'none';
        AppLogger.audioNotif('[AUTO_NEXT_IOS] URL_RESOLVE: source=$urlSource, '
            'urlLength=${audioSource?.length ?? 0}, url=${audioSource != null ? "present" : "NULL"}');
      }

      if (audioSource == null || audioSource.isEmpty) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] ERROR: No audio source for next chapter - cannot proceed');
        onPlaybackComplete?.call();
        return;
      }

      // === iOS BACKGROUND FIX: Ensure audio session is active before loading new source ===
      // When in background, the audio session may have been deactivated or lost focus.
      // We MUST reactivate it before attempting to play the next chapter.
      AppLogger.audioNotif('[AUTO_NEXT_IOS] PRE_PLAY: Ensuring audio session is active for background playback');
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
        _audioSessionActive = true;
        AppLogger.audioNotif('[AUTO_NEXT_IOS] PRE_PLAY: Audio session activated successfully');
      } catch (e) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] PRE_PLAY: WARNING - Audio session activation failed: $e');
        // Continue anyway - might still work
      }

      // === iOS BACKGROUND FIX: Direct playback without going through queue ===
      // The _enqueue system can introduce delays and race conditions in background.
      // For iOS auto-next, we use direct player control for reliability.
      AppLogger.audioNotif('[AUTO_NEXT_IOS] PLAY_START: Direct playback for nextIndex=$nextIndex, isLocal=$isLocalFile');

      try {
        // Clear user pause flag - this is auto-advance, not user action
        _userRequestedPause = false;

        // Update metadata immediately
        _currentChapterIndex = nextIndex;

        // Stop current playback cleanly
        await _player.stop();

        // Update MediaItem for lock screen display (use safe local `audiobook`)
        final title = (nextChapter['title_fa'] as String?) ?? 'فصل ${nextIndex + 1}';
        final bookTitle = (audiobook['title'] as String?) ??
            (audiobook['title_fa'] as String?) ??
            'کتاب صوتی';
        final coverUrl = audiobook['cover_url'] as String?;
        final durationSeconds = (nextChapter['duration_seconds'] as int?) ?? 0;

        // Get narrator/artist name
        final isMusic = (audiobook['is_music'] as bool?) ?? false;
        final isParastoBrand = (audiobook['is_parasto_brand'] as bool?) ?? false;
        String artistName = 'پرستو';
        if (isParastoBrand) {
          artistName = 'پرستو';
        } else if (isMusic) {
          final musicMeta = audiobook['music_metadata'] as Map<String, dynamic>?;
          artistName = (musicMeta?['artist_name'] as String?) ??
              (audiobook['author_fa'] as String?) ?? 'پرستو';
        } else {
          final bookMeta = audiobook['book_metadata'] as Map<String, dynamic>?;
          artistName = (bookMeta?['narrator_name'] as String?) ??
              (audiobook['author_fa'] as String?) ?? 'پرستو';
        }

        final chapterSubtitle = _buildChapterSubtitle(nextIndex, isMusic: isMusic);
        final newMediaItem = MediaItem(
          id: '${audiobook['id']}_$nextIndex',
          album: bookTitle,
          title: title,
          artist: artistName,
          displaySubtitle: chapterSubtitle,
          duration: Duration(seconds: durationSeconds),
          artUri: coverUrl != null ? Uri.parse(coverUrl) : null,
          extras: {
            'audiobook_id': audiobook['id'],
            'chapter_index': nextIndex,
            'is_offline': isLocalFile,
          },
        );
        mediaItem.add(newMediaItem);
        AppLogger.audioNotif('[AUTO_NEXT_IOS] MEDIA_ITEM: Updated for chapter $nextIndex - subtitle="$chapterSubtitle"');

        // Load and play the audio source
        if (isLocalFile) {
          await _player.setFilePath(audioSource);
        } else {
          await _player.setUrl(audioSource);
        }

        // Apply current playback speed
        if (_currentSpeed != 1.0) {
          await _player.setSpeed(_currentSpeed);
        }

        // Start playback
        await _player.play();

        // Verify playback started (with short timeout for background reliability)
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final isPlaying = _player.playing;
        final processingState = _player.processingState;

        AppLogger.audioNotif('[AUTO_NEXT_IOS] PLAY_VERIFY: playing=$isPlaying, state=$processingState');

        if (!isPlaying && processingState != ProcessingState.loading && processingState != ProcessingState.buffering) {
          // Retry play once
          AppLogger.audioNotif('[AUTO_NEXT_IOS] PLAY_RETRY: Playback not started, retrying...');
          await _player.play();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          AppLogger.audioNotif('[AUTO_NEXT_IOS] PLAY_RETRY: After retry - playing=${_player.playing}');
        }

        // Broadcast state to update lock screen controls
        _broadcastState(_player.playbackEvent);

        AppLogger.audioNotif('[AUTO_NEXT_IOS] PLAY_SUCCESS: Chapter $nextIndex started, playing=${_player.playing}');
        AppLogger.audioNotif('[AUTO_NEXT_IOS] SUCCESS: Now playing chapter $nextIndex - NOT calling callback');

        // Notify the provider to sync UI state (but not to trigger another auto-next)
        // This ensures the UI shows the correct chapter
        onChapterComplete?.call(nextIndex);

      } catch (e, st) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] PLAY_ERROR: Direct playback failed - $e');
        AppLogger.e('[AUTO_NEXT_IOS] Direct playback error', error: e, stackTrace: st);
        onPlaybackComplete?.call();
        return;
      }
    } finally {
      // Reset guard after delay to debounce rapid events and allow new chapter
      // to start playing before accepting new completions.
      // Uses longer delay than UI guard due to network latency.
      Future.delayed(AudioConfig.autoNextGuardResetiOS, () {
        _autoNextInFlight = false;
        _isAutoNexting = false;
        AppLogger.audioNotif('[AUTO_NEXT_IOS] Guards reset - ready for next completion');
      });
    }
  }

  /// Build a Farsi chapter subtitle for lock screen display (e.g., "فصل ۳ از ۱۲")
  String _buildChapterSubtitle(int chapterIndex, {bool isMusic = false}) {
    final label = isMusic ? 'آهنگ' : 'فصل';
    final current = FarsiUtils.toFarsiDigits(chapterIndex + 1);
    final total = FarsiUtils.toFarsiDigits(_chapters.length);
    return _chapters.length > 1
        ? '$label $current از $total'
        : '$label $current';
  }

  /// Get audio URL for a chapter (handles both audio_url and audio_storage_path)
  String? _getChapterAudioUrl(Map<String, dynamic> chapter) {
    // Try direct audio_url first
    if (chapter['audio_url'] != null) {
      return chapter['audio_url'] as String;
    }

    // Construct URL from audio_storage_path (same logic as AudioProvider)
    if (chapter['audio_storage_path'] != null) {
      try {
        final path = chapter['audio_storage_path'] as String;
        final url = Supabase.instance.client.storage
            .from(Env.audioBucket)
            .getPublicUrl(path);

        final chapterIndex = chapter['chapter_index'] as int? ?? -1;
        AppLogger.audioNotif('[AUTO_NEXT_IOS] URL constructed from storage_path - '
            'chapterIndex=$chapterIndex, pathLength=${path.length}, urlLength=${url.length}');
        return url;
      } catch (e) {
        AppLogger.audioNotif('[AUTO_NEXT_IOS] ERROR: Failed to construct URL from storage_path - $e');
        return null;
      }
    }

    return null;
  }

  /// Load and play a chapter
  Future<void> playChapter({
    required Map<String, dynamic> audiobook,
    required List<Map<String, dynamic>> chapters,
    required int chapterIndex,
    String? audioUrl,
    Duration? startPosition,
    bool isLocalFile = false,
  }) async {
    // [AUTO_NEXT] Log playChapter call for tracking auto-next flow
    AppLogger.audio('[AUTO_NEXT] CH_PLAYCHAPTER: audiobookId=${audiobook['id']}, '
        'chapterIndex=$chapterIndex, totalChapters=${chapters.length}');
    AppLogger.audioNotif('HANDLER: playChapter() ENTRY - '
        'audiobookId=${audiobook['id']}, chapterIndex=$chapterIndex, '
        'totalChapters=${chapters.length}, isLocalFile=$isLocalFile');

    if (chapters.isEmpty || chapterIndex < 0 || chapterIndex >= chapters.length) {
      AppLogger.audioNotif('HANDLER: playChapter() FAILED - invalid chapter index: $chapterIndex');
      AppLogger.e('HANDLER: Invalid chapter index: $chapterIndex');
      return;
    }

    // Dedupe guard: ignore duplicate requests for same audiobook+chapter+source while loading
    // Including audioUrl hash ensures we don't dedupe when source changes (e.g., download completed)
    final urlHash = audioUrl?.hashCode ?? 0;
    final sourceType = isLocalFile ? 'local' : 'remote';
    final loadKey = '${audiobook['id']}_${chapterIndex}_${sourceType}_$urlHash';
    if (_currentLoadingKey == loadKey) {
      AppLogger.audioNotif('[SERIAL] playChapter DEDUPE: ignoring duplicate request for loadKey=${audiobook['id']}_$chapterIndex ($sourceType)');
      return;
    }
    _currentLoadingKey = loadKey;

    // CRITICAL: Update metadata IMMEDIATELY (before enqueue) so stream listeners
    // show correct audiobook/chapter even while previous operation is finishing.
    // This prevents log messages from showing stale chapter index.
    _currentAudiobook = audiobook;
    _chapters = chapters;
    _currentChapterIndex = chapterIndex;

    // Enqueue this operation so it runs after any pending play/pause/stop
    return _enqueue(() => _playChapterInternal(
      audiobook: audiobook,
      chapters: chapters,
      chapterIndex: chapterIndex,
      audioUrl: audioUrl,
      startPosition: startPosition,
      isLocalFile: isLocalFile,
    ), opName: 'playChapter($loadKey)');
  }

  /// Internal implementation of playChapter - runs inside serialized queue
  Future<void> _playChapterInternal({
    required Map<String, dynamic> audiobook,
    required List<Map<String, dynamic>> chapters,
    required int chapterIndex,
    String? audioUrl,
    Duration? startPosition,
    bool isLocalFile = false,
  }) async {
    // Recreate the loadKey for supersession checks during retries
    final urlHash = audioUrl?.hashCode ?? 0;
    final sourceType = isLocalFile ? 'local' : 'remote';
    final loadKey = '${audiobook['id']}_${chapterIndex}_${sourceType}_$urlHash';
    AppLogger.audioNotif('[SERIAL] playChapter executing for ${audiobook['id']}_$chapterIndex ($sourceType)');

    // Clear user pause flag - we're starting new playback
    _userRequestedPause = false;

    final chapter = chapters[chapterIndex];
    final title = (chapter['title_fa'] as String?) ?? 'فصل ${chapterIndex + 1}';
    final bookTitle = (audiobook['title'] as String?) ??
        (audiobook['title_fa'] as String?) ??
        'کتاب صوتی';
    final coverUrl = audiobook['cover_url'] as String?;

    AppLogger.audio(
      'HANDLER: playChapter() - index=$chapterIndex, title="$title", '
      'isLocal=$isLocalFile',
    );

    // CRITICAL FIX: ALWAYS stop the player before loading new source
    // This prevents state corruption from rapid chapter switches
    try {
      AppLogger.audio('HANDLER: Stopping player before loading new source');
      await _player.stop();
      // PERF FIX: Removed unnecessary 30ms delay - player stop is synchronous
    } catch (e) {
      AppLogger.audioNotif('[SERIAL] Error stopping player: $e - continuing anyway');
    }

    _currentAudiobook = audiobook;
    _chapters = chapters;
    _currentChapterIndex = chapterIndex;

    // Get narrator/artist name for display from correct metadata table
    // (not profiles which is the uploader account, not the actual narrator/artist)
    // Priority: is_parasto_brand > metadata table > author field > default "پرستو"
    final isMusic = (audiobook['is_music'] as bool?) ?? false;
    final isParastoBrand = (audiobook['is_parasto_brand'] as bool?) ?? false;
    String artistName = 'پرستو';
    if (isParastoBrand) {
      artistName = 'پرستو';
    } else if (isMusic) {
      final musicMeta = audiobook['music_metadata'] as Map<String, dynamic>?;
      artistName = (musicMeta?['artist_name'] as String?) ??
          (audiobook['author_fa'] as String?) ??
          'پرستو';
    } else {
      final bookMeta = audiobook['book_metadata'] as Map<String, dynamic>?;
      artistName = (bookMeta?['narrator_name'] as String?) ??
          (audiobook['author_fa'] as String?) ??
          'پرستو';
    }

    // Update media item for notification/lock screen (iOS Control Center & Android notification)
    final durationSeconds = (chapter['duration_seconds'] as int?) ?? 0;
    final chapterSubtitle = _buildChapterSubtitle(chapterIndex, isMusic: isMusic);
    final newMediaItem = MediaItem(
      id: '${audiobook['id']}_$chapterIndex',
      album: bookTitle,
      title: title,
      artist: artistName,
      displaySubtitle: chapterSubtitle,
      duration: Duration(seconds: durationSeconds),
      artUri: coverUrl != null ? Uri.parse(coverUrl) : null,
      extras: {
        'audiobook_id': audiobook['id'],
        'chapter_index': chapterIndex,
        'is_offline': isLocalFile,
      },
    );

    // CRITICAL: Log all MediaItem fields for Android notification debugging
    // Missing or malformed artUri can cause notification issues on some devices
    AppLogger.audioNotif('MEDIAITEM: Setting MediaItem for notification - '
        'id="${newMediaItem.id}", title="$title", album="$bookTitle", '
        'artist="$artistName", duration=${durationSeconds}s, '
        'artUri=${coverUrl != null ? "present (${coverUrl.length} chars)" : "NULL"}, '
        'artUriValid=${coverUrl != null && Uri.tryParse(coverUrl) != null}');

    if (coverUrl == null) {
      AppLogger.audioNotif('MEDIAITEM: WARNING - artUri is null, notification may lack artwork');
    } else if (Uri.tryParse(coverUrl) == null) {
      AppLogger.audioNotif('MEDIAITEM: WARNING - artUri is malformed: $coverUrl');
    }

    AppLogger.audio(
      'HANDLER(iOS): Now Playing info - title="$title", album="$bookTitle", '
      'artist="$artistName", artUri=${coverUrl != null ? "present" : "null"}',
    );

    mediaItem.add(newMediaItem);
    AppLogger.audioNotif('MEDIAITEM: mediaItem.add() called - notification should update');

    // [AUDIO_NOTIF] iOS-specific: Log media item set for Control Center / lockscreen debugging
    if (Platform.isIOS) {
      AppLogger.audioNotif('[AUDIO_NOTIF] IOS_MEDIA: media item set - title="$title", album="$bookTitle", '
          'artist="$artistName", duration=${durationSeconds}s, hasArtwork=${coverUrl != null}');
    }

    // Update queue (use same artistName derived above for consistency)
    queue.add(_chapters.asMap().entries.map((entry) {
      final idx = entry.key;
      final ch = entry.value;
      return MediaItem(
        id: '${audiobook['id']}_$idx',
        album: bookTitle,
        title: (ch['title_fa'] as String?) ?? 'فصل ${idx + 1}',
        artist: artistName,
        displaySubtitle: _buildChapterSubtitle(idx, isMusic: isMusic),
        duration: Duration(seconds: (ch['duration_seconds'] as int?) ?? 0),
        artUri: coverUrl != null ? Uri.parse(coverUrl) : null,
      );
    }).toList());

    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        AppLogger.audioNotif('HANDLER: Setting audio source - isLocal=$isLocalFile, urlLength=${audioUrl.length}');
        AppLogger.audio('HANDLER: Setting audio source');

        // FIX: Wrap setUrl/setFilePath in try-catch to handle "Platform player already exists"
        // This can happen during rapid chapter switches. If it fails, retry once after a short delay.
        try {
          if (isLocalFile) {
            await _player.setFilePath(audioUrl);
          } else {
            await _player.setUrl(audioUrl);
          }
        } catch (sourceError) {
          if (sourceError.toString().contains('Platform player already exists')) {
            AppLogger.audioNotif('[SERIAL] Platform player conflict - stopping and retrying');
            await _player.stop();
            await Future<void>.delayed(const Duration(milliseconds: 50));
            if (isLocalFile) {
              await _player.setFilePath(audioUrl);
            } else {
              await _player.setUrl(audioUrl);
            }
          } else {
            rethrow;
          }
        }
        AppLogger.audioNotif('HANDLER: Audio source set successfully');

        // Apply saved playback speed (persists across chapters)
        if (_currentSpeed != 1.0) {
          await _player.setSpeed(_currentSpeed);
        }
        // Only seek if a specific position was requested.
        // When startPosition is null, we're loading a new chapter and should start from 0.
        // When startPosition is provided (e.g., resume), seek to that position.
        if (startPosition != null && startPosition > Duration.zero) {
          AppLogger.audioNotif('HANDLER: Seeking to ${startPosition.inSeconds}s (resume)');
          await _player.seek(startPosition);
          AppLogger.audioNotif('HANDLER: Seek completed');
        }

        AppLogger.audioNotif('HANDLER: Calling _player.play() - this should trigger foreground service');
        AppLogger.audio('HANDLER: Starting playback');

        // AUDIO FOCUS FIX: Ensure audio session is active before play() on all platforms
        // This is critical for:
        // - iOS: Prevent auto-pause in background, maintain Control Center controls
        // - Android: Properly request audio focus so other apps pause and we receive interruption events
        //
        // IDEMPOTENCY: Only call setActive(true) if not already active.
        // Rapid activation calls can cause audio focus issues on iOS.
        if (!_audioSessionActive) {
          try {
            final session = await AudioSession.instance;
            if (Platform.isIOS) {
              AppLogger.audioNotif('[AUDIO_NOTIF] IOS_SESSION: setActive(true) before playChapter');
            } else {
              AppLogger.audioNotif('[AUDIO_NOTIF] FOCUS: Activating audio session before play() (Android)');
            }
            await session.setActive(true);
            _audioSessionActive = true;
            if (Platform.isIOS) {
              AppLogger.audioNotif('[AUDIO_NOTIF] IOS_SESSION: Audio session activated successfully');
            } else {
              AppLogger.audioNotif('[AUDIO_NOTIF] FOCUS: Audio session activated successfully');
            }
          } catch (e) {
            AppLogger.audioNotif('[AUDIO_NOTIF] ${Platform.isIOS ? "IOS_SESSION" : "FOCUS"}: Failed to activate audio session: $e');
          }
        } else {
          AppLogger.audioNotif('[AUDIO_NOTIF] ${Platform.isIOS ? "IOS_SESSION" : "FOCUS"}: Audio session already active, skipping setActive()');
        }

        await _player.play();
        AppLogger.audioNotif('HANDLER: _player.play() returned');

        // PERF FIX: Check playback immediately first, only retry if actually needed
        // This eliminates 300ms unnecessary delay when playback starts correctly
        if (!_userRequestedPause) {
          // Immediate check - no delay
          var isPlaying = _player.playing;
          var currentState = _player.processingState;

          if (!isPlaying && currentState != ProcessingState.loading) {
            // Only retry if playback didn't start
            for (int attempt = 1; attempt <= 2; attempt++) {
              await Future<void>.delayed(Duration(milliseconds: 50 * attempt));

              // CRITICAL FIX: Check if a newer request has superseded us
              if (_currentLoadingKey != null && _currentLoadingKey != loadKey) {
                AppLogger.audioNotif('[DIAG] Retry aborted - new request superseded us');
                return;
              }

              currentState = _player.processingState;
              isPlaying = _player.playing;

              AppLogger.audioNotif('[DIAG] Playback verify attempt $attempt - playing=$isPlaying, state=$currentState');

              if (_userRequestedPause || isPlaying) break;

              if (currentState == ProcessingState.idle) {
                // Player is idle - source may need reload
                if (attempt < 2) {
                  try {
                    if (isLocalFile) {
                      await _player.setFilePath(audioUrl);
                    } else {
                      await _player.setUrl(audioUrl);
                    }
                    await _player.play();
                  } catch (retryErr) {
                    AppLogger.audioNotif('[DIAG] Retry $attempt failed: $retryErr');
                  }
                }
              } else if (currentState == ProcessingState.ready || currentState == ProcessingState.buffering) {
                await _player.play();
              }
            }
          }
        }

        final finalPlaying = _player.playing;
        final finalState = _player.processingState;
        AppLogger.audioNotif('HANDLER: playChapter() COMPLETE - '
            '_player.playing=$finalPlaying, '
            'processingState=$finalState');

        if (!finalPlaying && !_userRequestedPause && finalState != ProcessingState.loading) {
          AppLogger.audioNotif('[WARNING] Playback may have failed to start - player not playing');
        }

        AppLogger.audio('HANDLER: Playback started successfully${isLocalFile ? " (offline)" : ""} at ${_currentSpeed}x', chapter: title);
        _currentLoadingKey = null;
      } catch (e, st) {
        _currentLoadingKey = null;
        // Handle "Loading interrupted" gracefully - this is expected when a new request supersedes
        if (e.toString().contains('Loading interrupted') ||
            e.toString().contains('abort')) {
          AppLogger.audioNotif('[SERIAL] playChapter aborted (superseded by newer request)');
          // Don't rethrow - this is a controlled cancellation
          return;
        }
        // Handle "Platform player already exists" - player state corrupted from rapid switches
        // This requires stopping the player and retrying
        if (e.toString().contains('Platform player already exists')) {
          AppLogger.audioNotif('[SERIAL] Platform player corrupted - stopping and retrying once');
          try {
            await _player.stop();
            await Future<void>.delayed(const Duration(milliseconds: 100));
            // Retry the entire operation
            if (isLocalFile) {
              await _player.setFilePath(audioUrl);
            } else {
              await _player.setUrl(audioUrl);
            }
            await _player.play();
            AppLogger.audioNotif('[SERIAL] Retry after platform player error succeeded');
            _currentLoadingKey = null;
            return;
          } catch (retryErr) {
            AppLogger.audioNotif('[SERIAL] Retry after platform player error failed: $retryErr');
            // Fall through to rethrow
          }
        }
        AppLogger.audioNotif('HANDLER: playChapter() FAILED - error: $e');
        AppLogger.e('HANDLER ERROR: Failed to play audio', error: e, stackTrace: st);
        rethrow;
      }
    } else {
      _currentLoadingKey = null;
      AppLogger.audioNotif('HANDLER: playChapter() FAILED - no audio URL provided');
      AppLogger.e('HANDLER: No audio URL provided');
    }
  }

  @override
  Future<void> play() async {
    AppLogger.audioNotif('[AUDIO_NOTIF] HANDLER: play() called, playing=${_player.playing}, state=${_player.processingState}');

    // User wants to play - clear the pause flag
    _userRequestedPause = false;

    // iOS: Ensure audio session is active before resuming playback
    // IDEMPOTENCY: Only call if not already active
    if (Platform.isIOS && !_audioSessionActive) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
        _audioSessionActive = true;
        AppLogger.audioNotif('[AUDIO_NOTIF] IOS_SESSION: setActive(true) in play()');
      } catch (e) {
        AppLogger.audioNotif('[AUDIO_NOTIF] IOS_SESSION: setActive failed: $e');
      }
    }

    await _player.play();
    AppLogger.audioNotif('[AUDIO_NOTIF] HANDLER: play() completed, playing=${_player.playing}');
  }

  @override
  Future<void> pause() async {
    AppLogger.audioNotif('[AUDIO_NOTIF] HANDLER: pause() called, playing=${_player.playing}, state=${_player.processingState}');

    // User wants to pause - set the flag so startup retry won't override
    _userRequestedPause = true;

    await _player.pause();
    onProgressSave?.call();
    AppLogger.audioNotif('[AUDIO_NOTIF] HANDLER: pause() completed, playing=${_player.playing}');
  }

  @override
  Future<void> stop() => _enqueue(() async {
    AppLogger.audioNotif('[SERIAL] stop() executing');
    _userRequestedPause = true;
    onProgressSave?.call();
    await _player.stop();
    _currentAudiobook = null;
    _chapters = [];
    _currentChapterIndex = 0;
    _currentLoadingKey = null;

    // Clear MediaItem from lock screen/notification center
    // This ensures the playback notification is removed immediately
    mediaItem.add(null);
    AppLogger.audioNotif('[CLEANUP] MediaItem cleared from notification');

    // Clear playback state to remove any stale playback UI
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    AppLogger.audioNotif('[CLEANUP] Playback state cleared');

    // Release audio focus when stopping playback
    // This allows other apps to resume their audio gracefully
    if (_audioSessionActive) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
        _audioSessionActive = false;
        AppLogger.audioNotif('[AUDIO_NOTIF] FOCUS: Audio session deactivated on stop');
      } catch (e) {
        AppLogger.audioNotif('[AUDIO_NOTIF] FOCUS: Failed to deactivate audio session: $e');
      }
    }

    await super.stop();
  }, opName: 'stop');

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentChapterIndex < _chapters.length - 1) {
      onProgressSave?.call();
      final nextIndex = _currentChapterIndex + 1;
      onChapterComplete?.call(nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentChapterIndex > 0) {
      onProgressSave?.call();
      final prevIndex = _currentChapterIndex - 1;
      onChapterComplete?.call(prevIndex);
    }
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + const Duration(seconds: 10);
    if (newPosition < (_player.duration ?? Duration.zero)) {
      await _player.seek(newPosition);
    }
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    await _player.seek(newPosition.isNegative ? Duration.zero : newPosition);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed;
    await _player.setSpeed(speed);
    // Update playback state to reflect new speed
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _chapters.length) {
      onProgressSave?.call();
      onChapterComplete?.call(index);
    }
  }

  /// Dispose handler and cancel all subscriptions to prevent memory leaks
  Future<void> dispose() async {
    AppLogger.audio('HANDLER: Disposing audio handler and cancelling subscriptions');

    // Cancel stream subscriptions to prevent memory leaks
    await _playbackEventSubscription?.cancel();
    await _processingStateSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();

    // Dispose the audio player
    await _player.dispose();

    AppLogger.audio('HANDLER: Disposed successfully');
  }
}

/// Initialize the audio service - call this in main() before runApp
Future<MynaAudioHandler> initAudioService() async {
  AppLogger.audioNotif('INIT: initAudioService() called - starting AudioService initialization');
  AppLogger.audioNotif('INIT: AudioServiceConfig - '
      'channelId="app.myna.audio", '
      'channelName="پرستو - پخش صوتی", '
      'ongoing=true, '
      'stopForegroundOnPause=false, '
      'icon="drawable/ic_notification"');

  try {
    final handler = await AudioService.init(
      builder: () {
        AppLogger.audioNotif('INIT: AudioService.init builder() called - constructing MynaAudioHandler');
        return MynaAudioHandler();
      },
      config: AudioServiceConfig(
        androidNotificationChannelId: 'app.myna.audio',
        androidNotificationChannelName: 'پرستو - پخش صوتی',
        androidNotificationOngoing: true,
        // Keep notification visible when paused (prevents background kill)
        androidStopForegroundOnPause: false,
        // Notification icon must exist in android/app/src/main/res/drawable/
        androidNotificationIcon: 'drawable/ic_notification',
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );

    AppLogger.audioNotif('INIT: AudioService.init() completed successfully - handler created');

    // Log notification diagnostics at startup to capture initial state
    await NotificationPermissionService().logNotificationDiagnostics('STARTUP');

    return handler;
  } catch (e, st) {
    AppLogger.audioNotif('INIT: AudioService.init() FAILED - error: $e');
    AppLogger.e('INIT: AudioService initialization failed', error: e, stackTrace: st);
    rethrow;
  }
}
