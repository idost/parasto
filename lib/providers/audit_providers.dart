import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/audit_log.dart';
import 'package:myna/services/audit_service.dart';

/// Service provider
final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService();
});

/// Current filter state for audit logs
final auditFilterProvider = StateProvider<AuditLogFilter>((ref) {
  return const AuditLogFilter();
});

/// Main audit logs provider with filtering
final auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final service = ref.watch(auditServiceProvider);
  final filter = ref.watch(auditFilterProvider);
  return await service.getAuditLogs(filter: filter, limit: 100);
});

/// Paginated audit logs provider
final paginatedAuditLogsProvider = FutureProvider.autoDispose
    .family<List<AuditLog>, int>((ref, page) async {
  final service = ref.watch(auditServiceProvider);
  final filter = ref.watch(auditFilterProvider);
  const pageSize = 50;
  return await service.getAuditLogs(
    filter: filter,
    limit: pageSize,
    offset: page * pageSize,
  );
});

/// Audit logs for a specific entity
final entityAuditLogsProvider = FutureProvider.autoDispose
    .family<List<AuditLog>, ({AuditEntityType type, String id})>((ref, params) async {
  final service = ref.watch(auditServiceProvider);
  return await service.getEntityAuditLogs(
    entityType: params.type,
    entityId: params.id,
  );
});

/// Audit logs for a specific user (their activity)
final userActivityLogsProvider = FutureProvider.autoDispose
    .family<List<AuditLog>, String>((ref, userId) async {
  final service = ref.watch(auditServiceProvider);
  return await service.getUserActivityLogs(userId: userId);
});

/// Recent audit activity for admin audit log screens
/// NOTE: This is different from recentActivityProvider in recent_activity_feed.dart
/// which tracks content activity (plays, reviews, etc.)
final recentAuditActivityProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final service = ref.watch(auditServiceProvider);
  return await service.getRecentActivity(limit: 10);
});

/// Audit statistics
final auditStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final service = ref.watch(auditServiceProvider);
  // Last 30 days
  final fromDate = DateTime.now().subtract(const Duration(days: 30));
  return await service.getAuditStats(fromDate: fromDate);
});

/// Daily log counts for charts
final dailyLogCountsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(auditServiceProvider);
  final now = DateTime.now();
  final fromDate = now.subtract(const Duration(days: 30));
  return await service.getDailyLogCounts(fromDate: fromDate, toDate: now);
});
