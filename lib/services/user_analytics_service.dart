import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for fetching user-specific analytics data
class UserAnalyticsService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get listening stats for a specific user
  Future<ListenerStats> getListenerStats(String userId) async {
    try {
      // Get total listening time from listening_progress
      final progressResponse = await _client
          .from('listening_progress')
          .select('total_listen_time_seconds')
          .eq('user_id', userId);

      int totalListenSeconds = 0;
      int uniqueAudiobooks = 0;
      for (final row in progressResponse) {
        totalListenSeconds += (row['total_listen_time_seconds'] as int?) ?? 0;
        uniqueAudiobooks++;
      }

      // Get session count and active days from listening_sessions
      final sessionsResponse = await _client
          .from('listening_sessions')
          .select('session_date, duration_seconds')
          .eq('user_id', userId);

      int totalSessions = sessionsResponse.length;
      final activeDays = <String>{};
      for (final row in sessionsResponse) {
        activeDays.add(row['session_date'] as String);
      }

      // Get purchase count
      final purchasesResponse = await _client
          .from('purchases')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'completed');

      // Get entitlements count (owned audiobooks)
      final entitlementsResponse = await _client
          .from('entitlements')
          .select('id')
          .eq('user_id', userId);

      return ListenerStats(
        totalListenSeconds: totalListenSeconds,
        uniqueAudiobooks: uniqueAudiobooks,
        totalSessions: totalSessions,
        activeDays: activeDays.length,
        purchaseCount: purchasesResponse.length,
        libraryCount: entitlementsResponse.length,
      );
    } catch (e) {
      AppLogger.e('Error fetching listener stats for $userId', error: e);
      return ListenerStats.empty();
    }
  }

  /// Get recent listening activity for a user
  Future<List<ListeningActivity>> getRecentActivity(String userId, {int limit = 10}) async {
    try {
      final response = await _client
          .from('listening_sessions')
          .select('session_date, duration_seconds, audiobooks(id, title_fa, cover_url, is_music)')
          .eq('user_id', userId)
          .order('session_date', ascending: false)
          .limit(limit);

      return response.map((row) {
        final audiobook = row['audiobooks'] as Map<String, dynamic>?;
        return ListeningActivity(
          date: DateTime.parse(row['session_date'] as String),
          durationSeconds: row['duration_seconds'] as int,
          audiobookId: audiobook?['id'] as int?,
          audiobookTitle: audiobook?['title_fa'] as String?,
          coverUrl: audiobook?['cover_url'] as String?,
          isMusic: audiobook?['is_music'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Error fetching recent activity for $userId', error: e);
      return [];
    }
  }

  /// Get narrator performance stats
  Future<NarratorStats> getNarratorStats(String userId) async {
    try {
      // Get audiobooks created by this narrator
      final audiobooksResponse = await _client
          .from('audiobooks')
          .select('id, title_fa, status, play_count, purchase_count, avg_rating, price_toman, is_free, is_music')
          .eq('narrator_id', userId);

      int totalBooks = 0;
      int totalMusic = 0;
      int approvedCount = 0;
      int pendingCount = 0;
      int totalPlays = 0;
      int totalPurchases = 0;
      double totalRevenue = 0;
      double avgRating = 0;
      int ratingCount = 0;

      for (final book in audiobooksResponse) {
        if (book['is_music'] == true) {
          totalMusic++;
        } else {
          totalBooks++;
        }

        final status = book['status'] as String?;
        if (status == 'approved') approvedCount++;
        if (status == 'submitted' || status == 'under_review') pendingCount++;

        totalPlays += (book['play_count'] as int?) ?? 0;
        totalPurchases += (book['purchase_count'] as int?) ?? 0;

        if (book['is_free'] != true) {
          final price = (book['price_toman'] as num?)?.toDouble() ?? 0;
          totalRevenue += price * ((book['purchase_count'] as int?) ?? 0);
        }

        final rating = (book['avg_rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          avgRating += rating;
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        avgRating = avgRating / ratingCount;
      }

      // Get total listening hours for narrator's content
      final listeningResponse = await _client
          .from('listening_sessions')
          .select('duration_seconds, audiobooks!inner(narrator_id)')
          .eq('audiobooks.narrator_id', userId);

      int totalListenSeconds = 0;
      for (final row in listeningResponse) {
        totalListenSeconds += (row['duration_seconds'] as int?) ?? 0;
      }

      return NarratorStats(
        totalBooks: totalBooks,
        totalMusic: totalMusic,
        approvedCount: approvedCount,
        pendingCount: pendingCount,
        totalPlays: totalPlays,
        totalPurchases: totalPurchases,
        totalRevenue: totalRevenue,
        avgRating: avgRating,
        totalListenSeconds: totalListenSeconds,
      );
    } catch (e) {
      AppLogger.e('Error fetching narrator stats for $userId', error: e);
      return NarratorStats.empty();
    }
  }

  /// Get narrator's top performing content
  Future<List<ContentPerformance>> getNarratorTopContent(String userId, {int limit = 5}) async {
    try {
      final response = await _client
          .from('audiobooks')
          .select('id, title_fa, cover_url, is_music, play_count, purchase_count, avg_rating')
          .eq('narrator_id', userId)
          .eq('status', 'approved')
          .order('play_count', ascending: false)
          .limit(limit);

      return response.map((row) => ContentPerformance(
        audiobookId: row['id'] as int,
        title: row['title_fa'] as String,
        coverUrl: row['cover_url'] as String?,
        isMusic: row['is_music'] as bool? ?? false,
        playCount: row['play_count'] as int? ?? 0,
        purchaseCount: row['purchase_count'] as int? ?? 0,
        avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0,
      )).toList();
    } catch (e) {
      AppLogger.e('Error fetching narrator top content for $userId', error: e);
      return [];
    }
  }

  /// Get user's purchase history
  Future<List<PurchaseRecord>> getUserPurchases(String userId, {int limit = 20}) async {
    try {
      final response = await _client
          .from('purchases')
          .select('id, amount, status, created_at, audiobooks(id, title_fa, cover_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((row) {
        final audiobook = row['audiobooks'] as Map<String, dynamic>?;
        return PurchaseRecord(
          purchaseId: row['id'] as String,
          amount: (row['amount'] as num?)?.toDouble() ?? 0,
          status: row['status'] as String,
          date: DateTime.parse(row['created_at'] as String),
          audiobookId: audiobook?['id'] as int?,
          audiobookTitle: audiobook?['title_fa'] as String?,
          coverUrl: audiobook?['cover_url'] as String?,
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Error fetching user purchases for $userId', error: e);
      return [];
    }
  }

  /// Get user's library (entitlements)
  Future<List<LibraryItem>> getUserLibrary(String userId) async {
    try {
      final response = await _client
          .from('entitlements')
          .select('audiobook_id, granted_at, audiobooks(id, title_fa, cover_url, is_music)')
          .eq('user_id', userId)
          .order('granted_at', ascending: false);

      return response.map((row) {
        final audiobook = row['audiobooks'] as Map<String, dynamic>?;
        return LibraryItem(
          audiobookId: row['audiobook_id'] as int,
          title: audiobook?['title_fa'] as String? ?? '',
          coverUrl: audiobook?['cover_url'] as String?,
          isMusic: audiobook?['is_music'] as bool? ?? false,
          grantedAt: DateTime.parse(row['granted_at'] as String),
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Error fetching user library for $userId', error: e);
      return [];
    }
  }
}

/// Listener statistics
class ListenerStats {
  final int totalListenSeconds;
  final int uniqueAudiobooks;
  final int totalSessions;
  final int activeDays;
  final int purchaseCount;
  final int libraryCount;

  ListenerStats({
    required this.totalListenSeconds,
    required this.uniqueAudiobooks,
    required this.totalSessions,
    required this.activeDays,
    required this.purchaseCount,
    required this.libraryCount,
  });

  factory ListenerStats.empty() => ListenerStats(
    totalListenSeconds: 0,
    uniqueAudiobooks: 0,
    totalSessions: 0,
    activeDays: 0,
    purchaseCount: 0,
    libraryCount: 0,
  );

  double get totalHours => totalListenSeconds / 3600;
}

/// Recent listening activity item
class ListeningActivity {
  final DateTime date;
  final int durationSeconds;
  final int? audiobookId;
  final String? audiobookTitle;
  final String? coverUrl;
  final bool isMusic;

  ListeningActivity({
    required this.date,
    required this.durationSeconds,
    this.audiobookId,
    this.audiobookTitle,
    this.coverUrl,
    this.isMusic = false,
  });

  double get hours => durationSeconds / 3600;
}

/// Narrator performance statistics
class NarratorStats {
  final int totalBooks;
  final int totalMusic;
  final int approvedCount;
  final int pendingCount;
  final int totalPlays;
  final int totalPurchases;
  final double totalRevenue;
  final double avgRating;
  final int totalListenSeconds;

  NarratorStats({
    required this.totalBooks,
    required this.totalMusic,
    required this.approvedCount,
    required this.pendingCount,
    required this.totalPlays,
    required this.totalPurchases,
    required this.totalRevenue,
    required this.avgRating,
    required this.totalListenSeconds,
  });

  factory NarratorStats.empty() => NarratorStats(
    totalBooks: 0,
    totalMusic: 0,
    approvedCount: 0,
    pendingCount: 0,
    totalPlays: 0,
    totalPurchases: 0,
    totalRevenue: 0,
    avgRating: 0,
    totalListenSeconds: 0,
  );

  int get totalContent => totalBooks + totalMusic;
  double get totalListenHours => totalListenSeconds / 3600;
}

/// Content performance data
class ContentPerformance {
  final int audiobookId;
  final String title;
  final String? coverUrl;
  final bool isMusic;
  final int playCount;
  final int purchaseCount;
  final double avgRating;

  ContentPerformance({
    required this.audiobookId,
    required this.title,
    this.coverUrl,
    this.isMusic = false,
    this.playCount = 0,
    this.purchaseCount = 0,
    this.avgRating = 0,
  });
}

/// Purchase record
class PurchaseRecord {
  final String purchaseId;
  final double amount;
  final String status;
  final DateTime date;
  final int? audiobookId;
  final String? audiobookTitle;
  final String? coverUrl;

  PurchaseRecord({
    required this.purchaseId,
    required this.amount,
    required this.status,
    required this.date,
    this.audiobookId,
    this.audiobookTitle,
    this.coverUrl,
  });
}

/// Library item (user entitlement)
class LibraryItem {
  final int audiobookId;
  final String title;
  final String? coverUrl;
  final bool isMusic;
  final DateTime grantedAt;

  LibraryItem({
    required this.audiobookId,
    required this.title,
    this.coverUrl,
    this.isMusic = false,
    required this.grantedAt,
  });
}
