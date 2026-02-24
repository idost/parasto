/// Cache Configuration Constants
///
/// Centralizes all cache duration values used throughout the app.
/// Keeping these in one place makes it easy to tune performance vs freshness.
///
/// IMPORTANT: These values balance data freshness vs API load.
/// Shorter durations = fresher data but more API calls.
/// Longer durations = less API calls but potentially stale data.
class CacheConfig {
  CacheConfig._(); // Private constructor - all members are static

  // ==========================================================================
  // HOME SCREEN CACHING
  // ==========================================================================

  /// Cache duration for featured content on home screen.
  /// Featured books change infrequently (admin-curated).
  static const Duration homeFeaturedCache = Duration(minutes: 5);

  /// Cache duration for new releases section.
  /// New content is added periodically, 5 min is reasonable.
  static const Duration homeNewReleasesCache = Duration(minutes: 5);

  /// Cache duration for popular books section.
  /// Play counts change frequently but ranking changes slowly.
  static const Duration homePopularCache = Duration(minutes: 5);

  /// Cache duration for categories list.
  /// Categories rarely change (admin-managed).
  static const Duration homeCategoriesCache = Duration(minutes: 10);

  // ==========================================================================
  // USER-SPECIFIC CACHING
  // ==========================================================================

  /// Cache duration for user's continue listening section.
  /// Should be short since progress changes with each play session.
  static const Duration continueListeningCache = Duration(minutes: 1);

  /// Cache duration for user's recently played section.
  static const Duration recentlyPlayedCache = Duration(minutes: 1);

  /// Cache duration for user's library.
  /// Updates when user purchases/downloads content.
  static const Duration userLibraryCache = Duration(minutes: 2);

  /// Cache duration for user's playlists.
  static const Duration userPlaylistsCache = Duration(minutes: 2);

  // ==========================================================================
  // CONTENT CACHING
  // ==========================================================================

  /// Cache duration for category content lists.
  /// Content in categories changes when new books are approved.
  static const Duration categoryContentCache = Duration(minutes: 10);

  /// Cache duration for audiobook details.
  /// Details rarely change after approval.
  static const Duration audiobookDetailCache = Duration(minutes: 15);

  /// Cache duration for chapter lists.
  /// Chapters rarely change after initial upload.
  static const Duration chapterListCache = Duration(minutes: 15);

  // ==========================================================================
  // SEARCH CACHING
  // ==========================================================================

  /// Cache duration for search results.
  /// Short because users expect fresh results when searching.
  static const Duration searchResultsCache = Duration(minutes: 2);

  /// Cache duration for search suggestions/autocomplete.
  static const Duration searchSuggestionsCache = Duration(minutes: 5);

  // ==========================================================================
  // PROFILE & STATS CACHING
  // ==========================================================================

  /// Cache duration for user profile data.
  static const Duration userProfileCache = Duration(minutes: 5);

  /// Cache duration for listening statistics.
  /// Stats update after each listening session.
  static const Duration listeningStatsCache = Duration(minutes: 2);

  /// Cache duration for narrator statistics (narrator dashboard).
  static const Duration narratorStatsCache = Duration(minutes: 5);

  // ==========================================================================
  // ADMIN CACHING
  // ==========================================================================

  /// Cache duration for admin dashboard stats.
  /// Admins need relatively fresh data for decision making.
  static const Duration adminDashboardCache = Duration(minutes: 2);

  /// Cache duration for admin content lists.
  /// Content status changes frequently (approvals, etc).
  static const Duration adminContentListCache = Duration(minutes: 1);

  /// Cache duration for admin user lists.
  static const Duration adminUserListCache = Duration(minutes: 2);

  // ==========================================================================
  // NETWORK & OFFLINE
  // ==========================================================================

  /// How long to consider cached data "fresh" for offline scenarios.
  /// After this, show cached data but indicate it may be outdated.
  static const Duration offlineDataStaleness = Duration(hours: 24);

  /// Maximum age of cached data before forcing refresh.
  /// Even offline, data older than this should trigger refresh when online.
  static const Duration maxCacheAge = Duration(days: 7);

  // ==========================================================================
  // REQUEST DEDUPLICATION
  // ==========================================================================

  /// Window for deduplicating identical API requests.
  /// Multiple widgets requesting same data within this window share one request.
  static const Duration requestDedupeWindow = Duration(milliseconds: 100);

  // ==========================================================================
  // STALE-WHILE-REVALIDATE SETTINGS
  // ==========================================================================

  /// When using stale-while-revalidate pattern, this is how long
  /// stale data can be shown while refreshing in background.
  static const Duration staleDataMaxAge = Duration(minutes: 30);

  // ==========================================================================
  // NETWORK QUALITY FLAG
  // ==========================================================================

  /// Set to true when a slow network is detected to reduce request frequency.
  static bool slowNetworkMode = false;
}
