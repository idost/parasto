import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/services/analytics_service.dart';
import 'package:myna/utils/app_logger.dart';

/// Data model for UNICEF Partner Metrics Snapshot
class UnicefSnapshotData {
  final DateTime reportStart;
  final DateTime reportEnd;
  final DateTime generatedAt;

  // Engagement metrics
  final int totalListeningSeconds;
  final int uniqueListeners;
  final int uniqueContent;

  // Active user metrics
  final int dau;
  final int wau;
  final int mau;

  // Growth metrics
  final int totalUsers;
  final int newSignups;
  final int totalNarrators;

  // Content library counts
  final int totalAudiobooks;
  final int totalMusic;
  final int totalPodcasts;
  final int totalEbooks;

  // Top lists (Top 5)
  final List<ContentRanking> topContent;
  final List<CreatorRanking> topCreators;

  const UnicefSnapshotData({
    required this.reportStart,
    required this.reportEnd,
    required this.generatedAt,
    required this.totalListeningSeconds,
    required this.uniqueListeners,
    required this.uniqueContent,
    required this.dau,
    required this.wau,
    required this.mau,
    required this.totalUsers,
    required this.newSignups,
    required this.totalNarrators,
    required this.totalAudiobooks,
    required this.totalMusic,
    required this.totalPodcasts,
    required this.totalEbooks,
    required this.topContent,
    required this.topCreators,
  });

  /// Total listening hours (calculated from seconds)
  double get totalHours => totalListeningSeconds / 3600;

  /// Total content items in library
  int get totalContentItems =>
      totalAudiobooks + totalMusic + totalPodcasts + totalEbooks;

  /// Factory for empty/error state
  factory UnicefSnapshotData.empty(AnalyticsDateRange range) {
    return UnicefSnapshotData(
      reportStart: range.start,
      reportEnd: range.end,
      generatedAt: DateTime.now(),
      totalListeningSeconds: 0,
      uniqueListeners: 0,
      uniqueContent: 0,
      dau: 0,
      wau: 0,
      mau: 0,
      totalUsers: 0,
      newSignups: 0,
      totalNarrators: 0,
      totalAudiobooks: 0,
      totalMusic: 0,
      totalPodcasts: 0,
      totalEbooks: 0,
      topContent: [],
      topCreators: [],
    );
  }
}

/// Service for generating UNICEF Partner Metrics Snapshots
/// Aggregates data from multiple analytics sources into a single report
class AdminUnicefReportService {
  static final _supabase = Supabase.instance.client;

  /// Generate a complete UNICEF snapshot for the given date range
  ///
  /// Fetches data from multiple sources in parallel for efficiency:
  /// - Listening stats (hours, listeners, content played)
  /// - User stats (DAU, WAU, MAU, signups)
  /// - Top content (by listening hours)
  /// - Top creators (by listening hours)
  /// - Content library counts (audiobooks, music, podcasts, ebooks)
  static Future<UnicefSnapshotData> generateSnapshot(
    AnalyticsDateRange range,
  ) async {
    try {
      // Fetch all data in parallel for efficiency
      final results = await Future.wait([
        AnalyticsService.getListeningStats(range, null),
        AnalyticsService.getUserStats(range),
        AnalyticsService.getTopContent(range, null, limit: 5),
        AnalyticsService.getTopCreators(range, null, limit: 5),
        _getContentLibraryCounts(),
      ]);

      final listeningStats = results[0] as ListeningStats;
      final userStats = results[1] as UserStats;
      final topContent = results[2] as List<ContentRanking>;
      final topCreators = results[3] as List<CreatorRanking>;
      final libraryCounts = results[4] as Map<String, int>;

      return UnicefSnapshotData(
        reportStart: range.start,
        reportEnd: range.end,
        generatedAt: DateTime.now(),
        totalListeningSeconds: listeningStats.totalSeconds,
        uniqueListeners: listeningStats.uniqueListeners,
        uniqueContent: listeningStats.uniqueContent,
        dau: userStats.dau,
        wau: userStats.wau,
        mau: userStats.mau,
        totalUsers: userStats.totalUsers,
        newSignups: userStats.newSignups,
        totalNarrators: userStats.narratorCount,
        totalAudiobooks: libraryCounts['audiobooks'] ?? 0,
        totalMusic: libraryCounts['music'] ?? 0,
        totalPodcasts: libraryCounts['podcasts'] ?? 0,
        totalEbooks: libraryCounts['ebooks'] ?? 0,
        topContent: topContent,
        topCreators: topCreators,
      );
    } catch (e) {
      AppLogger.e('Error generating UNICEF snapshot', error: e);
      return UnicefSnapshotData.empty(range);
    }
  }

  /// Get content library counts from database
  /// Returns counts for audiobooks, music, podcasts, and ebooks
  static Future<Map<String, int>> _getContentLibraryCounts() async {
    try {
      // Query audiobooks for different content types using content_type column
      final audiobooksResponse = await _supabase
          .from('audiobooks')
          .select('content_type')
          .eq('status', 'approved');

      int audiobooks = 0;
      int music = 0;
      int podcasts = 0;

      for (final row in audiobooksResponse) {
        final contentType = row['content_type'] as String? ?? 'audiobook';

        if (contentType == 'podcast') {
          podcasts++;
        } else if (contentType == 'music') {
          music++;
        } else {
          audiobooks++;
        }
      }

      // Query ebooks count
      final ebooksResponse = await _supabase
          .from('ebooks')
          .select('id')
          .eq('status', 'approved');

      return {
        'audiobooks': audiobooks,
        'music': music,
        'podcasts': podcasts,
        'ebooks': ebooksResponse.length,
      };
    } catch (e) {
      AppLogger.e('Error fetching content library counts', error: e);
      return {
        'audiobooks': 0,
        'music': 0,
        'podcasts': 0,
        'ebooks': 0,
      };
    }
  }

  /// Create an "All Time" date range starting from platform launch
  static AnalyticsDateRange allTimeRange() {
    final now = DateTime.now();
    // Platform launch date (adjust as needed)
    final start = DateTime(2020, 1, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return AnalyticsDateRange(start, end);
  }

  /// Create a "Last 12 Months" date range
  static AnalyticsDateRange last12MonthsRange() {
    final now = DateTime.now();
    final start = DateTime(now.year - 1, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return AnalyticsDateRange(start, end);
  }
}
