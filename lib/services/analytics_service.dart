import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for fetching analytics data from Supabase
class AnalyticsService {
  static final _supabase = Supabase.instance.client;

  /// Get aggregated listening statistics for a date range
  /// [contentType] can be null (all), 'book', or 'music'
  static Future<ListeningStats> getListeningStats(
    AnalyticsDateRange range,
    String? contentType,
  ) async {
    try {
      // Fetch listening sessions with audiobook info for filtering
      final response = await _supabase
          .from('listening_sessions')
          .select('user_id, audiobook_id, duration_seconds, audiobooks!inner(is_music)')
          .gte('session_date', range.startDateString)
          .lte('session_date', range.endDateString);

      int totalSeconds = 0;
      final uniqueListeners = <String>{};
      final uniqueContent = <int>{};

      for (final row in response) {
        // Filter by content type if specified
        if (contentType != null) {
          final isMusic = row['audiobooks']['is_music'] as bool? ?? false;
          if (contentType == 'music' && !isMusic) continue;
          if (contentType == 'book' && isMusic) continue;
        }

        totalSeconds += (row['duration_seconds'] as num?)?.toInt() ?? 0;
        uniqueListeners.add(row['user_id'] as String);
        uniqueContent.add(row['audiobook_id'] as int);
      }

      return ListeningStats(
        totalSeconds: totalSeconds,
        uniqueListeners: uniqueListeners.length,
        uniqueContent: uniqueContent.length,
      );
    } catch (e) {
      AppLogger.e('Error fetching listening stats', error: e);
      return ListeningStats.empty();
    }
  }

  /// Get daily listening breakdown for charts
  static Future<List<DailyListening>> getDailyListening(
    AnalyticsDateRange range,
    String? contentType,
  ) async {
    try {
      final response = await _supabase
          .from('listening_sessions')
          .select('session_date, duration_seconds, audiobooks!inner(is_music)')
          .gte('session_date', range.startDateString)
          .lte('session_date', range.endDateString);

      // Aggregate by date
      final byDate = <String, int>{};
      for (final row in response) {
        // Filter by content type if specified
        if (contentType != null) {
          final isMusic = row['audiobooks']['is_music'] as bool? ?? false;
          if (contentType == 'music' && !isMusic) continue;
          if (contentType == 'book' && isMusic) continue;
        }

        final date = row['session_date'] as String;
        final seconds = (row['duration_seconds'] as num?)?.toInt() ?? 0;
        byDate[date] = (byDate[date] ?? 0) + seconds;
      }

      // Convert to list and sort by date
      final result = byDate.entries.map((e) => DailyListening(
            date: DateTime.parse(e.key),
            seconds: e.value,
          )).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return result;
    } catch (e) {
      AppLogger.e('Error fetching daily listening', error: e);
      return [];
    }
  }

  /// Get top content ranked by listening hours
  static Future<List<ContentRanking>> getTopContent(
    AnalyticsDateRange range,
    String? contentType, {
    int limit = 20,
  }) async {
    try {
      // Get listening sessions with user info for unique listeners
      final sessions = await _supabase
          .from('listening_sessions')
          .select('audiobook_id, user_id, duration_seconds')
          .gte('session_date', range.startDateString)
          .lte('session_date', range.endDateString);

      // Aggregate by audiobook
      final totals = <int, int>{};
      final listeners = <int, Set<String>>{};

      for (final row in sessions) {
        final id = row['audiobook_id'] as int;
        final userId = row['user_id'] as String;
        final seconds = (row['duration_seconds'] as num?)?.toInt() ?? 0;

        totals[id] = (totals[id] ?? 0) + seconds;
        listeners.putIfAbsent(id, () => {});
        listeners[id]!.add(userId);
      }

      if (totals.isEmpty) return [];

      // Get top IDs sorted by total seconds
      final topIds = totals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final ids = topIds.take(limit * 2).map((e) => e.key).toList(); // Fetch extra for filtering

      // Fetch audiobook details
      final audiobooks = await _supabase
          .from('audiobooks')
          .select('id, title_fa, cover_url, is_music, avg_rating, purchase_count, price_toman')
          .inFilter('id', ids);

      // Map to ContentRanking with content type filter
      final rankings = <ContentRanking>[];
      for (final a in audiobooks) {
        final isMusic = a['is_music'] as bool? ?? false;

        // Filter by content type
        if (contentType == 'music' && !isMusic) continue;
        if (contentType == 'book' && isMusic) continue;

        final id = a['id'] as int;
        final purchaseCount = (a['purchase_count'] as num?)?.toInt() ?? 0;
        final price = (a['price_toman'] as num?)?.toDouble() ?? 0;

        rankings.add(ContentRanking(
          audiobookId: id,
          title: a['title_fa'] as String? ?? '',
          coverUrl: a['cover_url'] as String?,
          isMusic: isMusic,
          totalSeconds: totals[id] ?? 0,
          uniqueListeners: listeners[id]?.length ?? 0,
          avgRating: (a['avg_rating'] as num?)?.toDouble() ?? 0,
          purchaseCount: purchaseCount,
          revenue: purchaseCount * price,
        ));
      }

      // Sort by total seconds and limit
      rankings.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
      return rankings.take(limit).toList();
    } catch (e) {
      AppLogger.e('Error fetching top content', error: e);
      return [];
    }
  }

  /// Get sales statistics for a date range
  static Future<SalesStats> getSalesStats(
    AnalyticsDateRange range,
    String? contentType,
  ) async {
    try {
      final response = await _supabase
          .from('purchases')
          .select('amount, user_id, audiobook_id, audiobooks!inner(is_music)')
          .eq('status', 'completed')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      double revenue = 0;
      final buyers = <String>{};
      int count = 0;

      for (final row in response) {
        // Filter by content type if specified
        if (contentType != null) {
          final isMusic = row['audiobooks']['is_music'] as bool? ?? false;
          if (contentType == 'music' && !isMusic) continue;
          if (contentType == 'book' && isMusic) continue;
        }

        revenue += (row['amount'] as num?)?.toDouble() ?? 0;
        buyers.add(row['user_id'] as String);
        count++;
      }

      return SalesStats(
        totalPurchases: count,
        totalRevenue: revenue,
        uniqueBuyers: buyers.length,
      );
    } catch (e) {
      AppLogger.e('Error fetching sales stats', error: e);
      return SalesStats.empty();
    }
  }

  /// Get user activity statistics
  static Future<UserStats> getUserStats(AnalyticsDateRange range) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final weekAgoStr = now.subtract(const Duration(days: 7));
      final weekAgoDateStr = '${weekAgoStr.year}-${weekAgoStr.month.toString().padLeft(2, '0')}-${weekAgoStr.day.toString().padLeft(2, '0')}';
      final monthAgoStr = now.subtract(const Duration(days: 30));
      final monthAgoDateStr = '${monthAgoStr.year}-${monthAgoStr.month.toString().padLeft(2, '0')}-${monthAgoStr.day.toString().padLeft(2, '0')}';

      // DAU: unique users who listened today
      final dauResponse = await _supabase
          .from('listening_sessions')
          .select('user_id')
          .eq('session_date', todayStr);
      final dau = dauResponse.map((r) => r['user_id']).toSet().length;

      // WAU: unique users who listened in last 7 days
      final wauResponse = await _supabase
          .from('listening_sessions')
          .select('user_id')
          .gte('session_date', weekAgoDateStr);
      final wau = wauResponse.map((r) => r['user_id']).toSet().length;

      // MAU: unique users who listened in last 30 days
      final mauResponse = await _supabase
          .from('listening_sessions')
          .select('user_id')
          .gte('session_date', monthAgoDateStr);
      final mau = mauResponse.map((r) => r['user_id']).toSet().length;

      // New signups in range
      final signupsResponse = await _supabase
          .from('profiles')
          .select('id')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      // Total users and role breakdown
      final usersResponse = await _supabase.from('profiles').select('role');

      final roleBreakdown = <String, int>{};
      for (final row in usersResponse) {
        final role = row['role'] as String? ?? 'listener';
        roleBreakdown[role] = (roleBreakdown[role] ?? 0) + 1;
      }

      return UserStats(
        dau: dau,
        wau: wau,
        mau: mau,
        newSignups: signupsResponse.length,
        totalUsers: usersResponse.length,
        roleBreakdown: roleBreakdown,
      );
    } catch (e) {
      AppLogger.e('Error fetching user stats', error: e);
      return UserStats.empty();
    }
  }

  /// Get top creators ranked by total listening hours
  static Future<List<CreatorRanking>> getTopCreators(
    AnalyticsDateRange range,
    String? contentType, {
    int limit = 20,
  }) async {
    try {
      // Get listening totals per audiobook
      final sessions = await _supabase
          .from('listening_sessions')
          .select('audiobook_id, duration_seconds')
          .gte('session_date', range.startDateString)
          .lte('session_date', range.endDateString);

      final audiobookTotals = <int, int>{};
      for (final row in sessions) {
        final id = row['audiobook_id'] as int;
        audiobookTotals[id] = (audiobookTotals[id] ?? 0) + ((row['duration_seconds'] as num?)?.toInt() ?? 0);
      }

      if (audiobookTotals.isEmpty) return [];

      // Get creator-audiobook mappings
      final creatorLinks = await _supabase
          .from('audiobook_creators')
          .select('creator_id, audiobook_id, creators(id, name_fa, type), audiobooks(is_music)')
          .inFilter('audiobook_id', audiobookTotals.keys.toList());

      // Aggregate by creator
      final creatorStats = <int, _CreatorAggregation>{};
      for (final link in creatorLinks) {
        // Filter by content type if specified
        if (contentType != null) {
          final isMusic = link['audiobooks']?['is_music'] as bool? ?? false;
          if (contentType == 'music' && !isMusic) continue;
          if (contentType == 'book' && isMusic) continue;
        }

        final creator = link['creators'] as Map<String, dynamic>?;
        if (creator == null) continue;

        final creatorId = creator['id'] as int;
        final audiobookId = link['audiobook_id'] as int;
        final seconds = audiobookTotals[audiobookId] ?? 0;

        if (creatorStats.containsKey(creatorId)) {
          creatorStats[creatorId]!.contentCount++;
          creatorStats[creatorId]!.totalSeconds += seconds;
        } else {
          creatorStats[creatorId] = _CreatorAggregation(
            creatorId: creatorId,
            name: creator['name_fa'] as String? ?? '',
            type: creator['type'] as String? ?? '',
            contentCount: 1,
            totalSeconds: seconds,
          );
        }
      }

      // Convert to rankings and sort
      final rankings = creatorStats.values
          .map((c) => CreatorRanking(
                creatorId: c.creatorId,
                name: c.name,
                type: c.type,
                contentCount: c.contentCount,
                totalListenSeconds: c.totalSeconds,
                totalRevenue: 0, // Would need purchases join for accurate revenue
              ))
          .toList()
        ..sort((a, b) => b.totalListenSeconds.compareTo(a.totalListenSeconds));

      return rankings.take(limit).toList();
    } catch (e) {
      AppLogger.e('Error fetching top creators', error: e);
      return [];
    }
  }

  /// Get daily signup data for charts
  static Future<List<DailySignups>> getDailySignups(AnalyticsDateRange range) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('created_at')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      // Aggregate by date
      final byDate = <String, int>{};
      for (final row in response) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final dateStr = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        byDate[dateStr] = (byDate[dateStr] ?? 0) + 1;
      }

      // Convert to list and sort
      final result = byDate.entries
          .map((e) => DailySignups(
                date: DateTime.parse(e.key),
                count: e.value,
              ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return result;
    } catch (e) {
      AppLogger.e('Error fetching daily signups', error: e);
      return [];
    }
  }
}

/// Helper class for creator aggregation
class _CreatorAggregation {
  final int creatorId;
  final String name;
  final String type;
  int contentCount;
  int totalSeconds;

  _CreatorAggregation({
    required this.creatorId,
    required this.name,
    required this.type,
    required this.contentCount,
    required this.totalSeconds,
  });
}
