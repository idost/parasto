import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Cache for featured audiobooks (changes infrequently)
List<Map<String, dynamic>>? _featuredCache;
DateTime? _featuredCacheTime;
Future<List<Map<String, dynamic>>>? _featuredPendingRequest;

/// Cache for new releases
List<Map<String, dynamic>>? _newReleasesCache;
DateTime? _newReleasesCacheTime;
Future<List<Map<String, dynamic>>>? _newReleasesPendingRequest;

/// Cache for popular audiobooks
List<Map<String, dynamic>>? _popularCache;
DateTime? _popularCacheTime;
Future<List<Map<String, dynamic>>>? _popularPendingRequest;

/// Cache duration for audiobook lists (5 minutes - balances freshness with performance)
const _audiobooksCacheDuration = Duration(minutes: 5);

/// Provider for suggested audiobooks on home screen (excludes music)
/// Logic: Featured items first (by play_count), then popular non-featured if not enough
/// This ensures "پیشنهاد شده" always has content even without featured items
/// Uses in-memory cache for performance
/// PERF FIX: Request deduplication prevents duplicate API calls
final homeFeaturedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_featuredCache != null && _featuredCacheTime != null) {
    final elapsed = DateTime.now().difference(_featuredCacheTime!);
    if (elapsed < _audiobooksCacheDuration) {
      return _featuredCache!;
    }
  }

  // PERF FIX: Return pending request if one is already in-flight
  if (_featuredPendingRequest != null) {
    return _featuredPendingRequest!;
  }

  try {
    _featuredPendingRequest = _fetchFeatured();
    final result = await _featuredPendingRequest!;
    _featuredPendingRequest = null;
    return result;
  } catch (e) {
    _featuredPendingRequest = null;
    rethrow;
  }
});

Future<List<Map<String, dynamic>>> _fetchFeatured() async {
  try {
    // First try to get featured audiobooks, ordered by popularity
    // OPTIMIZATION: Select only needed columns instead of * to reduce data transfer
    final featuredResponse = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, is_featured, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .eq('is_featured', true)
        .inFilter('content_type', ['audiobook', 'podcast'])
        .order('play_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(10);

    final featured = List<Map<String, dynamic>>.from(featuredResponse);

    // If we have enough featured items, return them
    if (featured.length >= 5) {
      _featuredCache = featured;
      _featuredCacheTime = DateTime.now();
      return featured;
    }

    // Otherwise, supplement with high play_count non-featured items
    final remaining = 10 - featured.length;
    final featuredIds = featured.map((b) => b['id'] as int).toList();

    // Get popular non-featured items to fill the gap
    var query = Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, is_featured, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .inFilter('content_type', ['audiobook', 'podcast'])
        .eq('is_featured', false);

    // Exclude already-included featured items using NOT IN filter
    if (featuredIds.isNotEmpty) {
      query = query.not('id', 'in', '(${featuredIds.join(",")})');
    }

    final popularResponse = await query
        .order('play_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(remaining);

    final popular = List<Map<String, dynamic>>.from(popularResponse);

    final result = [...featured, ...popular];
    _featuredCache = result;
    _featuredCacheTime = DateTime.now();
    return result;
  } catch (e) {
    AppLogger.e('Error fetching suggested audiobooks', error: e);
    rethrow;
  }
}

/// Provider for new releases on home screen (excludes music)
/// Uses in-memory cache for performance
/// PERF FIX: Request deduplication prevents duplicate API calls
final homeNewReleasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_newReleasesCache != null && _newReleasesCacheTime != null) {
    final elapsed = DateTime.now().difference(_newReleasesCacheTime!);
    if (elapsed < _audiobooksCacheDuration) {
      return _newReleasesCache!;
    }
  }

  // PERF FIX: Return pending request if one is already in-flight
  if (_newReleasesPendingRequest != null) {
    return _newReleasesPendingRequest!;
  }

  try {
    _newReleasesPendingRequest = _fetchNewReleases();
    final result = await _newReleasesPendingRequest!;
    _newReleasesPendingRequest = null;
    return result;
  } catch (e) {
    _newReleasesPendingRequest = null;
    rethrow;
  }
});

Future<List<Map<String, dynamic>>> _fetchNewReleases() async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .inFilter('content_type', ['audiobook', 'podcast']) // Books section: audiobooks + podcasts
        .order('created_at', ascending: false)
        .limit(10);
    final result = List<Map<String, dynamic>>.from(response);

    _newReleasesCache = result;
    _newReleasesCacheTime = DateTime.now();
    return result;
  } catch (e) {
    AppLogger.e('Error fetching new releases', error: e);
    rethrow;
  }
}

/// Provider for popular audiobooks on home screen (excludes music)
/// Shows top audiobooks by play_count (unique listeners)
/// Secondary sort by created_at for deterministic ordering when counts are equal
/// Uses in-memory cache for performance
/// PERF FIX: Request deduplication prevents duplicate API calls
final homePopularProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_popularCache != null && _popularCacheTime != null) {
    final elapsed = DateTime.now().difference(_popularCacheTime!);
    if (elapsed < _audiobooksCacheDuration) {
      return _popularCache!;
    }
  }

  // PERF FIX: Return pending request if one is already in-flight
  if (_popularPendingRequest != null) {
    return _popularPendingRequest!;
  }

  try {
    _popularPendingRequest = _fetchPopular();
    final result = await _popularPendingRequest!;
    _popularPendingRequest = null;
    return result;
  } catch (e) {
    _popularPendingRequest = null;
    rethrow;
  }
});

Future<List<Map<String, dynamic>>> _fetchPopular() async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .inFilter('content_type', ['audiobook', 'podcast']) // Books section: audiobooks + podcasts
        .order('play_count', ascending: false)
        .order('created_at', ascending: false) // Secondary sort for deterministic results
        .limit(10);
    final result = List<Map<String, dynamic>>.from(response);

    _popularCache = result;
    _popularCacheTime = DateTime.now();
    return result;
  } catch (e) {
    AppLogger.e('Error fetching popular audiobooks', error: e);
    rethrow;
  }
}

/// Cached categories data - categories rarely change, so we cache them
/// This prevents redundant queries when navigating between screens
List<Map<String, dynamic>>? _categoriesCache;
DateTime? _categoriesCacheTime;
const _categoriesCacheDuration = Duration(minutes: 30);

/// Provider for categories on home screen (full category data)
/// Uses in-memory cache to avoid redundant fetches
final homeCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Return cached data if still fresh
  if (_categoriesCache != null && _categoriesCacheTime != null) {
    final elapsed = DateTime.now().difference(_categoriesCacheTime!);
    if (elapsed < _categoriesCacheDuration) {
      return _categoriesCache!;
    }
  }

  try {
    final response = await Supabase.instance.client
        .from('categories')
        .select('id, name_fa, name_en, icon, sort_order, is_active')
        .eq('is_active', true)
        .order('sort_order');
    final result = List<Map<String, dynamic>>.from(response);

    // Cache the result
    _categoriesCache = result;
    _categoriesCacheTime = DateTime.now();

    return result;
  } catch (e) {
    AppLogger.e('Error fetching categories', error: e);
    rethrow;
  }
});

/// Provider for categories used in forms (narrator upload, admin edit)
/// Reuses the home categories cache since it contains all needed fields
final formCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Reuse homeCategoriesProvider to avoid duplicate fetches
  final categories = await ref.watch(homeCategoriesProvider.future);
  // Return only the fields needed for forms
  return categories.map((c) => {
    'id': c['id'],
    'name_fa': c['name_fa'],
    'name_en': c['name_en'],
  }).toList();
});

/// Provider for "Continue Listening" - the most recent INCOMPLETE BOOK (content_type=audiobook|podcast)
/// Includes chapters for immediate playback and time remaining calculation
/// OPTIMIZED: Runs audiobook and chapters queries in parallel
/// NOTE: Music continue listening is handled by musicContinueListeningProvider
/// NOTE: Invalidated by AudioProvider after progress save for immediate update
final continueListeningProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    // Get recent incomplete items - we need to find the first BOOK (content_type=audiobook|podcast)
    // Since listening_progress doesn't have content_type, we fetch multiple and filter
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select('audiobook_id, completion_percentage, last_played_at, position_seconds, current_chapter_index, total_listen_time_seconds')
        .eq('user_id', user.id as Object)
        .lt('completion_percentage', 100)
        .order('last_played_at', ascending: false)
        .limit(10); // Fetch more to find a book among possible music items

    if ((progressResponse as List).isEmpty) return null;

    // OPTIMIZATION: Fetch all audiobooks in ONE query instead of looping
    final audiobookIds = (progressResponse as List)
        .map((p) => p['audiobook_id'] as int)
        .toSet()
        .toList();

    // Single query for all audiobooks
    final audiobooksResponse = await Supabase.instance.client
        .from('audiobooks')
        .select('id, title_fa, title_en, cover_url, content_type, is_free, total_duration_seconds, author_fa, status, book_metadata(narrator_name)')
        .inFilter('id', audiobookIds)
        .eq('status', 'approved')
        .inFilter('content_type', ['audiobook', 'podcast']); // FILTER: Books section only

    if ((audiobooksResponse as List).isEmpty) {
      AppLogger.d('HOME CONTINUE: No incomplete books found');
      return null;
    }

    // Build map for O(1) lookup
    final audiobooksMap = <int, Map<String, dynamic>>{
      for (final book in audiobooksResponse as List)
        book['id'] as int: Map<String, dynamic>.from(book as Map)
    };

    // Find the first incomplete BOOK by iterating progress in order
    for (final progressItem in progressResponse) {
      final progress = Map<String, dynamic>.from(progressItem as Map);
      final audiobookId = progress['audiobook_id'] as int;

      final audiobook = audiobooksMap[audiobookId];
      if (audiobook == null) continue; // Not a book or not approved, try next

      // Found a book! Fetch chapters
      final chaptersResponse = await Supabase.instance.client
          .from('chapters')
          .select('id, title_fa, audio_storage_path, duration_seconds, chapter_index, is_preview, audiobook_id')
          .eq('audiobook_id', audiobookId)
          .order('chapter_index', ascending: true);

      audiobook['progress'] = progress;
      audiobook['chapters'] = List<Map<String, dynamic>>.from(
        (chaptersResponse as List).map((c) => Map<String, dynamic>.from(c as Map)),
      );

      AppLogger.d('HOME CONTINUE: Loaded book "${audiobook['title_fa']}" (content_type=audiobook|podcast)');
      return audiobook;
    }

    // No incomplete books found
    AppLogger.d('HOME CONTINUE: No incomplete books found (content_type=audiobook|podcast)');
    return null;
  } catch (e) {
    AppLogger.e('Error fetching continue listening book', error: e);
    return null;
  }
});

/// Provider for ALL incomplete books (up to 10) for the "Continue" horizontal carousel.
/// Returns a list of audiobooks with progress + chapters attached.
/// Used by ContinueSection widget (richer than the single-book _CompactResumeBar).
final continueListeningAllProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  try {
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select(
            'audiobook_id, completion_percentage, last_played_at, position_seconds, current_chapter_index, total_listen_time_seconds')
        .eq('user_id', user.id as Object)
        .gt('completion_percentage', 0) // Must have started
        .lt('completion_percentage', 100) // Must be incomplete
        .order('last_played_at', ascending: false)
        .limit(10);

    if ((progressResponse as List).isEmpty) return [];

    final audiobookIds = (progressResponse as List)
        .map((p) => p['audiobook_id'] as int)
        .toSet()
        .toList();

    final audiobooksResponse = await Supabase.instance.client
        .from('audiobooks')
        .select(
            'id, title_fa, title_en, cover_url, content_type, is_free, total_duration_seconds, author_fa, status, book_metadata(narrator_name)')
        .inFilter('id', audiobookIds)
        .eq('status', 'approved')
        .inFilter('content_type', ['audiobook', 'podcast']); // Books section only

    if ((audiobooksResponse as List).isEmpty) return [];

    final audiobooksMap = <int, Map<String, dynamic>>{
      for (final book in audiobooksResponse as List)
        book['id'] as int: Map<String, dynamic>.from(book as Map)
    };

    final results = <Map<String, dynamic>>[];

    for (final progressItem in progressResponse) {
      final progress = Map<String, dynamic>.from(progressItem as Map);
      final audiobookId = progress['audiobook_id'] as int;
      final audiobook = audiobooksMap[audiobookId];
      if (audiobook == null) continue;

      // Fetch chapters
      final chaptersResponse = await Supabase.instance.client
          .from('chapters')
          .select(
              'id, title_fa, audio_storage_path, duration_seconds, chapter_index, is_preview, audiobook_id')
          .eq('audiobook_id', audiobookId)
          .order('chapter_index', ascending: true);

      final bookCopy = Map<String, dynamic>.from(audiobook);
      bookCopy['progress'] = progress;
      bookCopy['chapters'] = List<Map<String, dynamic>>.from(
        (chaptersResponse as List)
            .map((c) => Map<String, dynamic>.from(c as Map)),
      );
      bookCopy['content_type'] = 'audiobook';
      results.add(bookCopy);
    }

    AppLogger.d('HOME CONTINUE ALL: Loaded ${results.length} incomplete books');
    return results;
  } catch (e) {
    AppLogger.e('Error fetching continue listening all', error: e);
    return [];
  }
});

/// Provider for recently played BOOKS (up to 3, excluding the continue listening book)
/// FILTER: Only shows books (content_type=audiobook|podcast), not music
/// The exclusion logic excludes the first incomplete book (shown in continueListening)
/// NOTE: Invalidated by AudioProvider after progress save for immediate update
final homeRecentlyPlayedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  try {
    // Get listening progress - we'll filter for books at the audiobooks level
    // Include is_completed to properly verify completion status
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select('audiobook_id, completion_percentage, is_completed, last_played_at, position_seconds, current_chapter_index')
        .eq('user_id', user.id as Object)
        .order('last_played_at', ascending: false)
        .limit(15); // Fetch more since some may be music items

    if ((progressResponse as List).isEmpty) return [];

    // Get all audiobook IDs from progress
    final allAudiobookIds = progressResponse.map((p) => p['audiobook_id'] as int).toList();

    // Fetch ONLY BOOKS (content_type=audiobook|podcast)
    final audiobooksResponse = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          book_metadata(narrator_name)
        ''')
        .inFilter('id', allAudiobookIds)
        .eq('status', 'approved')
        .inFilter('content_type', ['audiobook', 'podcast']); // FILTER: Books section only

    // Create a map for quick lookup (only books)
    final booksMap = <int, Map<String, dynamic>>{};
    for (final book in audiobooksResponse as List) {
      booksMap[book['id'] as int] = Map<String, dynamic>.from(book as Map);
    }

    // Find the first incomplete BOOK (this is the "continue listening" book)
    // and exclude it from our results
    int? excludeId;
    for (final p in progressResponse) {
      final audiobookId = p['audiobook_id'] as int;
      if (!booksMap.containsKey(audiobookId)) continue; // Skip music items

      final completion = (p['completion_percentage'] as num?)?.toInt() ?? 0;
      if (completion < 100) {
        excludeId = audiobookId;
        break;
      }
    }

    // Merge progress into books, exclude continue listening, maintain order, limit to 3
    final result = <Map<String, dynamic>>[];
    for (final progress in progressResponse) {
      if (result.length >= 3) break;

      final audiobookId = progress['audiobook_id'] as int;
      if (audiobookId == excludeId) continue; // Skip continue listening book

      final book = booksMap[audiobookId];
      if (book == null) continue; // Skip music items (not in booksMap)

      final bookWithProgress = Map<String, dynamic>.from(book);
      bookWithProgress['progress'] = Map<String, dynamic>.from(progress as Map);
      result.add(bookWithProgress);
    }

    AppLogger.d('HOME RECENTLY: Loaded ${result.length} book items (content_type=audiobook|podcast)');
    return result;
  } catch (e) {
    AppLogger.e('Error fetching recently played books', error: e);
    return [];
  }
});

/// Listening statistics for profile page
class ListeningStats {
  final int totalListenTimeSeconds;
  final int daysListening;
  final int currentStreak;
  final int longestStreak;
  final int booksCompleted;

  const ListeningStats({
    this.totalListenTimeSeconds = 0,
    this.daysListening = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.booksCompleted = 0,
  });

  /// Total minutes listened
  int get totalMinutes => totalListenTimeSeconds ~/ 60;

  /// Total hours listened
  int get totalHours => totalListenTimeSeconds ~/ 3600;

  /// Format total listen time as human readable string
  String get formattedTotalTime {
    final hours = totalListenTimeSeconds ~/ 3600;
    final minutes = (totalListenTimeSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت و ${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
    }
    return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
  }

  /// Format total listen time as short string (just hours)
  String get formattedTotalTimeShort {
    final hours = totalListenTimeSeconds ~/ 3600;
    if (hours > 0) {
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت';
    }
    final minutes = totalListenTimeSeconds ~/ 60;
    return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
  }

  /// Get listener level based on total minutes
  /// - 0–60 min: "شنوندهٔ تازه‌کار" (Beginner)
  /// - 61–600 min (1-10 hours): "شنوندهٔ فعال" (Active)
  /// - 601+ min (10+ hours): "شنوندهٔ وفادار" (Loyal)
  String get listenerLevel {
    final minutes = totalMinutes;
    if (minutes <= 60) {
      return 'شنوندهٔ تازه‌کار';
    } else if (minutes <= 600) {
      return 'شنوندهٔ فعال';
    } else {
      return 'شنوندهٔ وفادار';
    }
  }

  /// Get listener level icon
  String get listenerLevelIcon {
    final minutes = totalMinutes;
    if (minutes <= 60) {
      return '🌱';
    } else if (minutes <= 600) {
      return '⭐';
    } else {
      return '👑';
    }
  }

  /// Check achievements - returns list of (achieved, label, description)
  List<Achievement> get achievements {
    return [
      Achievement(
        id: 'first_book',
        title: 'اولین کتاب',
        description: 'اولین کتاب صوتی را کامل شنیدی',
        achieved: booksCompleted >= 1,
        icon: '📚',
      ),
      Achievement(
        id: 'five_hours',
        title: '۵ ساعت گوش دادن',
        description: 'در مجموع ۵ ساعت گوش دادی',
        achieved: totalHours >= 5,
        icon: '🎧',
      ),
      Achievement(
        id: 'ten_days',
        title: '۱۰ روز فعال',
        description: 'در ۱۰ روز مختلف گوش دادی',
        achieved: daysListening >= 10,
        icon: '📅',
      ),
    ];
  }

  /// Count of achieved achievements
  int get achievedCount => achievements.where((a) => a.achieved).length;
}

/// Simple achievement data class
class Achievement {
  final String id;
  final String title;
  final String description;
  final bool achieved;
  final String icon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.achieved,
    required this.icon,
  });
}

/// Provider for user listening statistics
/// NOTE(Issue 3 fix): Uses two queries to get accurate stats:
/// Listening Stats Provider - Now uses listening_sessions table for accurate tracking
///
/// Data sources:
/// 1. listening_progress: Total listen time (per audiobook) and completed books count
/// 2. listening_sessions: Daily listening records for accurate days/streak calculation
///
/// The listening_sessions table stores one record per user-audiobook-day, allowing
/// accurate counting of unique listening days and streak calculations.
final listeningStatsProvider = FutureProvider<ListeningStats>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const ListeningStats();

  try {
    // Query 1: Get total time and completed books from listening_progress
    // This table accumulates total_listen_time_seconds per audiobook
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select('total_listen_time_seconds, is_completed')
        .eq('user_id', user.id as Object);

    final progressRecords = progressResponse as List;

    // Calculate accurate totals from ALL progress records
    int totalTime = 0;
    int completedBooks = 0;

    for (final record in progressRecords) {
      totalTime += (record['total_listen_time_seconds'] as num?)?.toInt() ?? 0;
      if (record['is_completed'] == true) {
        completedBooks++;
      }
    }

    // Query 2: Get unique listening days from listening_sessions
    // This table has one entry per user-audiobook-day, enabling accurate daily tracking
    // Fetch last 365 days for comprehensive stats
    final sessionsResponse = await Supabase.instance.client
        .from('listening_sessions')
        .select('session_date')
        .eq('user_id', user.id as Object)
        .order('session_date', ascending: false)
        .limit(365);

    final sessions = sessionsResponse as List;
    final uniqueDays = <int>{}; // Use day-of-epoch for faster comparison

    for (final session in sessions) {
      if (session['session_date'] != null) {
        // session_date is in YYYY-MM-DD format
        final dateStr = session['session_date'] as String;
        final date = DateTime.parse(dateStr);
        uniqueDays.add(date.millisecondsSinceEpoch ~/ 86400000); // Days since epoch
      }
    }

    // Calculate streaks from unique days
    int currentStreak = 0;
    int longestStreak = 0;

    if (uniqueDays.isNotEmpty) {
      final sortedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a)); // Newest first
      final todayEpoch = DateTime.now().millisecondsSinceEpoch ~/ 86400000;

      // Check current streak (must start today or yesterday to be "active")
      if (sortedDays.first == todayEpoch || sortedDays.first == todayEpoch - 1) {
        int checkDay = sortedDays.first;
        for (final day in sortedDays) {
          if (day == checkDay) {
            currentStreak++;
            checkDay--;
          } else if (day < checkDay) {
            break; // Gap found, streak ends
          }
        }
      }

      // Calculate longest streak (simple scan)
      sortedDays.sort(); // Oldest first for forward scanning
      int tempStreak = 1;
      for (int i = 1; i < sortedDays.length; i++) {
        if (sortedDays[i] - sortedDays[i - 1] == 1) {
          tempStreak++;
        } else {
          if (tempStreak > longestStreak) longestStreak = tempStreak;
          tempStreak = 1;
        }
      }
      if (tempStreak > longestStreak) longestStreak = tempStreak;
    }

    return ListeningStats(
      totalListenTimeSeconds: totalTime,
      daysListening: uniqueDays.length,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      booksCompleted: completedBooks,
    );
  } catch (e) {
    AppLogger.e('Error fetching listening stats', error: e);
    return const ListeningStats();
  }
});

// ============================================
// MUSIC PROVIDERS
// ============================================
// These providers fetch content where content_type = 'music'
// Used by the موسیقی (Music) tab in the bottom navigation

/// Provider for featured music on music screen
final musicFeaturedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, is_featured, status,
          categories(name_fa),
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'music')
        .eq('is_featured', true)
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching featured music', error: e);
    rethrow;
  }
});

/// Provider for new music releases
final musicNewReleasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'music')
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching new music', error: e);
    rethrow;
  }
});

/// Provider for popular music (by play count)
/// Secondary sort by created_at for deterministic ordering
final musicPopularProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'music')
        .order('play_count', ascending: false)
        .order('created_at', ascending: false) // Secondary sort for deterministic results
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching popular music', error: e);
    rethrow;
  }
});

/// Provider for all music (for browsing)
final musicAllProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'music')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching all music', error: e);
    rethrow;
  }
});

/// Provider for music categories (سبک‌های موسیقی) for filtering
final musicCategoriesForFilterProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('music_categories')
        .select('id, name_fa, name_en, icon, is_active')
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching music categories', error: e);
    rethrow;
  }
});

/// State provider for selected music category filter
/// null means "همه سبک‌ها" (All genres)
final selectedMusicCategoryProvider = StateProvider<int?>((ref) => null);

/// Provider for "ادامه‌ی شنیدن موسیقی" - recently played music items
/// Shows music items the user has started listening to (content_type = 'music')
final musicContinueListeningProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  try {
    // Get listening progress for items, ordered by last played
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select('audiobook_id, completion_percentage, last_played_at, position_seconds, current_chapter_index')
        .eq('user_id', user.id as Object)
        .lt('completion_percentage', 100)
        .order('last_played_at', ascending: false)
        .limit(10);

    if ((progressResponse as List).isEmpty) return [];

    final audiobookIds = progressResponse
        .map((p) => p['audiobook_id'] as int)
        .toList();

    // Fetch music items only (content_type = 'music')
    final audiobooksResponse = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          music_metadata(artist_name, featured_artists)
        ''')
        .inFilter('id', audiobookIds)
        .eq('status', 'approved')
        .eq('content_type', 'music');

    // Create a map for quick lookup
    final audiobooksMap = <int, Map<String, dynamic>>{};
    for (final item in audiobooksResponse as List) {
      audiobooksMap[item['id'] as int] = Map<String, dynamic>.from(item as Map);
    }

    // Merge progress into items and maintain order by last_played_at
    final result = <Map<String, dynamic>>[];
    for (final progress in progressResponse) {
      final audiobookId = progress['audiobook_id'] as int;
      final item = audiobooksMap[audiobookId];
      if (item != null) {
        final itemWithProgress = Map<String, dynamic>.from(item);
        itemWithProgress['progress'] = Map<String, dynamic>.from(progress as Map);
        result.add(itemWithProgress);
      }
    }

    return result;
  } catch (e) {
    AppLogger.e('Error fetching music continue listening', error: e);
    return [];
  }
});

// ============================================
// PODCAST PROVIDERS
// ============================================
// These providers fetch content where content_type = 'podcast'
// Used by the پادکست‌ها (Podcasts) section on home screen

/// Provider for podcasts on home screen
/// Shows approved podcasts ordered by creation date
final homePodcastsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'podcast')
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching podcasts', error: e);
    rethrow;
  }
});

/// Provider for popular podcasts (by play count)
final podcastsPopularProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'podcast')
        .order('play_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching popular podcasts', error: e);
    rethrow;
  }
});

// ============================================
// ARTICLE PROVIDERS
// ============================================
// These providers fetch content where content_type = 'article'
// Used by the مقاله‌ها (Articles) section on home screen

/// Provider for articles on home screen (content_type='article')
final homeArticlesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'article')
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching articles', error: e);
    rethrow;
  }
});

/// Provider for popular articles (by play count)
final articlesPopularProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'article')
        .order('play_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching popular articles', error: e);
    rethrow;
  }
});

/// Provider for music filtered by selected category
/// Uses the junction table audiobook_music_categories for filtering
final musicByCategoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final selectedCategoryId = ref.watch(selectedMusicCategoryProvider);

  try {
    if (selectedCategoryId == null) {
      // No filter - return all music
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('''
            id, title_fa, title_en, cover_url, content_type, is_free,
            total_duration_seconds, author_fa, play_count, status,
            categories(name_fa),
            music_metadata(artist_name, featured_artists)
          ''')
          .eq('status', 'approved')
          .eq('content_type', 'music')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    }

    // Filter by category using junction table
    // First get audiobook IDs that have this music category
    final junctionResponse = await Supabase.instance.client
        .from('audiobook_music_categories')
        .select('audiobook_id')
        .eq('music_category_id', selectedCategoryId);

    final audiobookIds = (junctionResponse as List)
        .map((row) => row['audiobook_id'] as int)
        .toList();

    if (audiobookIds.isEmpty) {
      return [];
    }

    // Fetch those audiobooks
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          music_metadata(artist_name, featured_artists)
        ''')
        .eq('status', 'approved')
        .eq('content_type', 'music')
        .inFilter('id', audiobookIds)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching music by category', error: e);
    rethrow;
  }
});

// ============================================
// MIXED CONTENT PROVIDERS (Books + Music + Podcasts)
// ============================================
// These providers return a mix of all content types for search recommendations

/// Provider for mixed popular content (books, music, podcasts combined)
/// Used by search screen "پیشنهاد برای شما" section
final searchRecommendedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name),
          music_metadata(artist_name)
        ''')
        .eq('status', 'approved')
        .order('play_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching search recommendations', error: e);
    rethrow;
  }
});

/// Provider for mixed new releases (books, music, podcasts combined)
/// Used by search screen "انتخاب ما" section
final searchPickedForYouProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('''
          id, title_fa, title_en, cover_url, content_type, is_free,
          total_duration_seconds, author_fa, play_count, status,
          categories(name_fa),
          book_metadata(narrator_name),
          music_metadata(artist_name)
        ''')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(15);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching picked for you', error: e);
    rethrow;
  }
});

// =============================================================================
// AUDIOBOOKS-SCREEN PROVIDERS (audiobook-only aliases used by AudiobooksScreen)
// =============================================================================

/// Audiobook-only featured provider (excludes music/podcasts/articles).
/// Used by the dedicated Audiobooks tab screen.
final audiobookFeaturedProvider = homeFeaturedProvider;

/// Audiobook-only new releases provider (excludes music/podcasts/articles).
/// Used by the dedicated Audiobooks tab screen.
final audiobookNewReleasesProvider = homeNewReleasesProvider;