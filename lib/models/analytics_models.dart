/// Analytics data models for the admin dashboard
/// Provides structured data for listening, sales, and user analytics

/// Date range for analytics queries with preset factory methods
class AnalyticsDateRange {
  final DateTime start;
  final DateTime end;

  const AnalyticsDateRange(this.start, this.end);

  /// Today only
  factory AnalyticsDateRange.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return AnalyticsDateRange(start, end);
  }

  /// Last 7 days including today
  factory AnalyticsDateRange.last7Days() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return AnalyticsDateRange(start, end);
  }

  /// Last 30 days including today
  factory AnalyticsDateRange.last30Days() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return AnalyticsDateRange(start, end);
  }

  /// Current year from January 1st
  factory AnalyticsDateRange.thisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return AnalyticsDateRange(start, end);
  }

  /// Format start date for SQL query (YYYY-MM-DD)
  String get startDateString => '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

  /// Format end date for SQL query (YYYY-MM-DD)
  String get endDateString => '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

  /// Number of days in range
  int get dayCount => end.difference(start).inDays + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsDateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

/// Aggregated listening statistics
class ListeningStats {
  final int totalSeconds;
  final int uniqueListeners;
  final int uniqueContent;

  const ListeningStats({
    required this.totalSeconds,
    required this.uniqueListeners,
    required this.uniqueContent,
  });

  /// Total hours listened (rounded to 1 decimal)
  double get totalHours => totalSeconds / 3600;

  /// Create from empty/null data
  factory ListeningStats.empty() => const ListeningStats(
        totalSeconds: 0,
        uniqueListeners: 0,
        uniqueContent: 0,
      );

  factory ListeningStats.fromJson(Map<String, dynamic> json) {
    return ListeningStats(
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      uniqueListeners: (json['uniqueListeners'] as num?)?.toInt() ?? 0,
      uniqueContent: (json['uniqueContent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Daily listening data point for charts
class DailyListening {
  final DateTime date;
  final int seconds;

  const DailyListening({
    required this.date,
    required this.seconds,
  });

  /// Hours listened on this day
  double get hours => seconds / 3600;

  /// Format date as M/D
  String get shortDate => '${date.month}/${date.day}';

  /// Format date as YYYY/M/D
  String get fullDate => '${date.year}/${date.month}/${date.day}';
}

/// Content ranking for popularity lists
class ContentRanking {
  final int audiobookId;
  final String title;
  final String? coverUrl;
  final bool isMusic;
  final int totalSeconds;
  final int uniqueListeners;
  final double avgRating;
  final int purchaseCount;
  final double revenue;

  const ContentRanking({
    required this.audiobookId,
    required this.title,
    this.coverUrl,
    required this.isMusic,
    required this.totalSeconds,
    required this.uniqueListeners,
    required this.avgRating,
    required this.purchaseCount,
    required this.revenue,
  });

  /// Total hours listened
  double get totalHours => totalSeconds / 3600;

  /// Content type label in Farsi
  String get typeLabel => isMusic ? 'موسیقی' : 'کتاب';
}

/// Creator ranking for top creators
class CreatorRanking {
  final int creatorId;
  final String name;
  final String type;
  final int contentCount;
  final int totalListenSeconds;
  final double totalRevenue;

  const CreatorRanking({
    required this.creatorId,
    required this.name,
    required this.type,
    required this.contentCount,
    required this.totalListenSeconds,
    required this.totalRevenue,
  });

  /// Total hours of content listened
  double get totalHours => totalListenSeconds / 3600;

  /// Creator type label in Farsi
  String get typeLabel {
    switch (type) {
      case 'narrator':
        return 'گوینده';
      case 'author':
        return 'نویسنده';
      case 'artist':
        return 'هنرمند';
      case 'singer':
        return 'خواننده';
      case 'composer':
        return 'آهنگساز';
      case 'translator':
        return 'مترجم';
      default:
        return type;
    }
  }
}

/// Sales statistics
class SalesStats {
  final int totalPurchases;
  final double totalRevenue;
  final int uniqueBuyers;

  const SalesStats({
    required this.totalPurchases,
    required this.totalRevenue,
    required this.uniqueBuyers,
  });

  factory SalesStats.empty() => const SalesStats(
        totalPurchases: 0,
        totalRevenue: 0,
        uniqueBuyers: 0,
      );

  /// Format revenue with currency symbol
  String get formattedRevenue => '\$${totalRevenue.toStringAsFixed(2)}';
}

/// User activity statistics
class UserStats {
  final int dau; // Daily Active Users
  final int wau; // Weekly Active Users
  final int mau; // Monthly Active Users
  final int newSignups;
  final int totalUsers;
  final Map<String, int> roleBreakdown;

  const UserStats({
    required this.dau,
    required this.wau,
    required this.mau,
    required this.newSignups,
    required this.totalUsers,
    required this.roleBreakdown,
  });

  factory UserStats.empty() => const UserStats(
        dau: 0,
        wau: 0,
        mau: 0,
        newSignups: 0,
        totalUsers: 0,
        roleBreakdown: {},
      );

  /// Get listener count
  int get listenerCount => roleBreakdown['listener'] ?? 0;

  /// Get narrator count
  int get narratorCount => roleBreakdown['narrator'] ?? 0;

  /// Get admin count
  int get adminCount => roleBreakdown['admin'] ?? 0;
}

/// Daily signup data point
class DailySignups {
  final DateTime date;
  final int count;

  const DailySignups({
    required this.date,
    required this.count,
  });

  /// Format date as M/D
  String get shortDate => '${date.month}/${date.day}';
}
