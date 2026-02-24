import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/services/analytics_service.dart';

/// State provider for the selected date range
/// Defaults to last 7 days
final analyticsDateRangeProvider = StateProvider<AnalyticsDateRange>((ref) {
  return AnalyticsDateRange.last7Days();
});

/// State provider for content type filter
/// null = all, 'book' = audiobooks only, 'music' = music only
final analyticsContentTypeProvider = StateProvider<String?>((ref) => null);

/// Listening stats provider - total hours, unique listeners, unique content
final listeningStatsProvider = FutureProvider<ListeningStats>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final contentType = ref.watch(analyticsContentTypeProvider);
  return AnalyticsService.getListeningStats(range, contentType);
});

/// Daily listening data for line charts
final dailyListeningProvider = FutureProvider<List<DailyListening>>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final contentType = ref.watch(analyticsContentTypeProvider);
  return AnalyticsService.getDailyListening(range, contentType);
});

/// Top content ranked by listening hours
final topContentProvider = FutureProvider<List<ContentRanking>>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final contentType = ref.watch(analyticsContentTypeProvider);
  return AnalyticsService.getTopContent(range, contentType, limit: 20);
});

/// Sales statistics
final salesStatsProvider = FutureProvider<SalesStats>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final contentType = ref.watch(analyticsContentTypeProvider);
  return AnalyticsService.getSalesStats(range, contentType);
});

/// Top creators ranked by listening hours
final topCreatorsProvider = FutureProvider<List<CreatorRanking>>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final contentType = ref.watch(analyticsContentTypeProvider);
  return AnalyticsService.getTopCreators(range, contentType, limit: 20);
});

/// User activity stats (DAU, WAU, MAU, signups, role breakdown)
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  return AnalyticsService.getUserStats(range);
});

/// Daily signup data for charts
final dailySignupsProvider = FutureProvider<List<DailySignups>>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  return AnalyticsService.getDailySignups(range);
});
