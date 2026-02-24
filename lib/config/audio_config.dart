/// Audio System Configuration Constants
///
/// This class centralizes all timing values, thresholds, and configuration
/// constants used throughout the audio system. Keeping these in one place:
/// 1. Makes the system easier to tune and debug
/// 2. Documents why each value exists
/// 3. Prevents magic numbers scattered throughout the code
///
/// IMPORTANT: Change these values carefully - they affect audio reliability.
/// See the plan file for risk analysis of each timing value.
class AudioConfig {
  AudioConfig._(); // Private constructor - all members are static

  // ==========================================================================
  // DEBOUNCE & THROTTLING
  // ==========================================================================

  /// Debounce duration for play/pause button taps.
  /// Prevents rapid-fire play/pause calls that can cause race conditions.
  /// Value: 300ms is responsive enough for UX while preventing double-taps.
  static const Duration playPauseDebounce = Duration(milliseconds: 300);

  /// Throttle duration for position updates while playing.
  /// Controls how often we update UI with current position.
  /// Lower = smoother progress bar, higher = less CPU usage.
  static const Duration positionUpdateThrottlePlaying = Duration(milliseconds: 250);

  /// Throttle duration for position updates while paused.
  /// Less frequent updates needed when not playing.
  static const Duration positionUpdateThrottlePaused = Duration(milliseconds: 100);

  // ==========================================================================
  // CHAPTER COMPLETION & AUTO-NEXT GUARDS
  // ==========================================================================

  /// Guard reset delay after chapter completion handling (AudioNotifier).
  /// This delay prevents duplicate completion events from being processed.
  ///
  /// RISK: If too short, rapid chapter skips can drop completion events.
  /// If too long, legitimate back-to-back completions may be ignored.
  ///
  /// The guard flag is reset AFTER this delay, allowing new completions.
  /// Value should be long enough for UI state to settle but short enough
  /// not to block normal playback flow.
  static const Duration chapterCompleteGuardReset = Duration(milliseconds: 150);

  /// Guard reset delay for iOS auto-next in audio handler.
  /// Longer than UI guard because network latency may delay playback start.
  ///
  /// RISK: If too short on slow networks, guard resets before playback starts,
  /// potentially allowing duplicate auto-next triggers.
  ///
  /// Value accounts for: network latency + audio buffering + state sync.
  static const Duration autoNextGuardResetiOS = Duration(milliseconds: 800);

  // ==========================================================================
  // PROGRESS SAVING
  // ==========================================================================

  /// Interval between automatic progress saves during playback.
  /// Balances data freshness vs database load.
  static const Duration progressSaveInterval = Duration(seconds: 30);

  /// Maximum retries for failed progress saves.
  /// After this many failures, stop retrying to avoid battery drain.
  static const int progressSaveMaxRetries = 3;

  /// Delay between progress save retries (exponential backoff base).
  static const Duration progressSaveRetryDelay = Duration(seconds: 2);

  // ==========================================================================
  // NETWORK & OFFLINE
  // ==========================================================================

  /// How long to cache offline status check result.
  /// Prevents excessive network checks but may show stale status.
  static const Duration offlineStatusCacheDuration = Duration(seconds: 10);

  /// Timeout for offline status check.
  static const Duration offlineCheckTimeout = Duration(seconds: 2);

  /// Default timeout for database queries.
  /// Prevents app freezing on slow networks.
  static const Duration databaseQueryTimeout = Duration(seconds: 15);

  // ==========================================================================
  // COMPLETION THRESHOLDS
  // ==========================================================================

  /// Position percentage at which a chapter is considered "complete".
  /// Used for progress tracking and chapter completion detection.
  /// 95% accounts for audio files that may have trailing silence.
  static const double chapterCompletionThreshold = 0.95;

  /// Position percentage at which an audiobook is considered "nearly complete".
  /// Used for determining when to show "book finished" UI.
  static const double audiobookNearCompletionThreshold = 0.98;

  // ==========================================================================
  // PAYMENT & ENTITLEMENTS
  // ==========================================================================

  /// Maximum polling attempts for entitlement after payment.
  /// Stripe webhook may take time to process.
  static const int entitlementPollingMaxAttempts = 15;

  /// Interval between entitlement polling attempts.
  static const Duration entitlementPollingInterval = Duration(seconds: 1);

  /// Total timeout for entitlement polling (attempts × interval).
  static Duration get entitlementPollingTimeout =>
      entitlementPollingInterval * entitlementPollingMaxAttempts;

  // ==========================================================================
  // DOWNLOADS
  // ==========================================================================

  /// Maximum concurrent chapter downloads.
  static const int maxConcurrentDownloads = 3;

  // ==========================================================================
  // AUDIO SESSION
  // ==========================================================================

  /// Delay after stopping player before loading new source.
  /// Helps prevent iOS "Loading interrupted" errors.
  /// Set to 0 for performance - stop() is synchronous.
  static const Duration playerStopDelay = Duration.zero;

  /// Delay before clearing audio state after stop.
  /// Gives UI time to react to state change.
  static const Duration clearStateDelay = Duration(milliseconds: 100);

  // ==========================================================================
  // NETWORK ERROR AUTO-RETRY
  // ==========================================================================

  /// Maximum number of automatic retries for network errors.
  /// Prevents infinite loops while recovering from transient issues.
  static const int networkErrorMaxRetries = 2;

  /// Delay between automatic retry attempts for network errors.
  /// Gives network time to recover before retrying.
  static const Duration networkErrorRetryDelay = Duration(seconds: 2);

  // ==========================================================================
  // CIRCUIT BREAKER (Operation Queue)
  // ==========================================================================

  /// Number of consecutive failures before circuit breaker opens.
  /// Once open, operations fail fast without attempting execution.
  static const int circuitBreakerFailureThreshold = 3;

  /// Duration to keep circuit breaker open before allowing retry.
  /// After this period, one test operation is allowed through.
  static const Duration circuitBreakerResetTimeout = Duration(seconds: 10);

  /// Timeout for individual audio operations in the queue.
  /// Prevents single operations from blocking the entire queue.
  /// Note: 60s is generous but prevents premature timeouts on slow networks.
  static const Duration operationTimeout = Duration(seconds: 60);
}
