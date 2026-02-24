import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/audit_log.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for managing audit logs and activity tracking
class AuditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // READ METHODS
  // ============================================================================

  /// Get audit logs with pagination and optional filters
  Future<List<AuditLog>> getAuditLogs({
    int limit = 50,
    int offset = 0,
    AuditLogFilter? filter,
  }) async {
    try {
      dynamic query = _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false);

      // Apply filters
      if (filter != null) {
        if (filter.action != null) {
          query = query.eq('action', _actionToString(filter.action!));
        }
        if (filter.entityType != null) {
          query = query.eq('entity_type', _entityTypeToString(filter.entityType!));
        }
        if (filter.actorId != null) {
          query = query.eq('actor_id', filter.actorId);
        }
        if (filter.entityId != null) {
          query = query.eq('entity_id', filter.entityId);
        }
        if (filter.fromDate != null) {
          query = query.gte('created_at', filter.fromDate!.toIso8601String());
        }
        if (filter.toDate != null) {
          query = query.lte('created_at', filter.toDate!.toIso8601String());
        }
      }

      // Apply pagination
      query = query.range(offset, offset + limit - 1);

      final response = await query;

      return (response as List)
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching audit logs', error: e);
      return [];
    }
  }

  /// Get audit logs for a specific entity
  Future<List<AuditLog>> getEntityAuditLogs({
    required AuditEntityType entityType,
    required String entityId,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select()
          .eq('entity_type', _entityTypeToString(entityType))
          .eq('entity_id', entityId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching entity audit logs', error: e);
      return [];
    }
  }

  /// Get audit logs for a specific user (as actor)
  Future<List<AuditLog>> getUserActivityLogs({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select()
          .eq('actor_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching user activity logs', error: e);
      return [];
    }
  }

  /// Get recent activity for dashboard
  Future<List<AuditLog>> getRecentActivity({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching recent activity', error: e);
      return [];
    }
  }

  /// Get audit log statistics
  Future<Map<String, int>> getAuditStats({DateTime? fromDate}) async {
    try {
      dynamic query = _supabase.from('audit_logs').select('action');

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }

      final response = await query;
      final List<Map<String, dynamic>> data = (response as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();

      final stats = <String, int>{};
      for (final item in data) {
        final action = item['action'] as String;
        stats[action] = (stats[action] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      AppLogger.e('Error fetching audit stats', error: e);
      return {};
    }
  }

  /// Get count of logs by date for charts
  Future<List<Map<String, dynamic>>> getDailyLogCounts({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select('created_at')
          .gte('created_at', fromDate.toIso8601String())
          .lte('created_at', toDate.toIso8601String());

      // Aggregate by date
      final byDate = <String, int>{};
      for (final row in response) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final dateStr = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        byDate[dateStr] = (byDate[dateStr] ?? 0) + 1;
      }

      // Convert to list
      return byDate.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    } catch (e) {
      AppLogger.e('Error fetching daily log counts', error: e);
      return [];
    }
  }

  // ============================================================================
  // WRITE METHODS
  // ============================================================================

  /// Log an action manually (for app-level actions not caught by DB triggers)
  Future<void> logAction({
    required AuditAction action,
    required AuditEntityType entityType,
    required String entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    List<String>? changedFields,
    String? description,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      await _supabase.from('audit_logs').insert({
        'actor_id': currentUser?.id,
        'actor_email': currentUser?.email,
        'action': _actionToString(action),
        'entity_type': _entityTypeToString(entityType),
        'entity_id': entityId,
        'old_values': oldValues,
        'new_values': newValues,
        'changed_fields': changedFields,
        'description': description,
      });
    } catch (e) {
      AppLogger.e('Error logging action', error: e);
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Log a bulk action
  Future<void> logBulkAction({
    required AuditEntityType entityType,
    required List<String> entityIds,
    required String actionDescription,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      await _supabase.from('audit_logs').insert({
        'actor_id': currentUser?.id,
        'actor_email': currentUser?.email,
        'action': 'bulk_action',
        'entity_type': _entityTypeToString(entityType),
        'entity_id': entityIds.join(','),
        'description': actionDescription,
        'new_values': {'affected_count': entityIds.length, 'ids': entityIds},
      });
    } catch (e) {
      AppLogger.e('Error logging bulk action', error: e);
    }
  }

  /// Log a login event
  Future<void> logLogin() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('audit_logs').insert({
        'actor_id': currentUser.id,
        'actor_email': currentUser.email,
        'action': 'login',
        'entity_type': 'user',
        'entity_id': currentUser.id,
        'description': 'ورود به سیستم',
      });
    } catch (e) {
      AppLogger.e('Error logging login', error: e);
    }
  }

  /// Log a logout event
  Future<void> logLogout() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('audit_logs').insert({
        'actor_id': currentUser.id,
        'actor_email': currentUser.email,
        'action': 'logout',
        'entity_type': 'user',
        'entity_id': currentUser.id,
        'description': 'خروج از سیستم',
      });
    } catch (e) {
      AppLogger.e('Error logging logout', error: e);
    }
  }

  /// Log an export action
  Future<void> logExport({
    required String exportType,
    required int rowCount,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      await _supabase.from('audit_logs').insert({
        'actor_id': currentUser?.id,
        'actor_email': currentUser?.email,
        'action': 'export',
        'entity_type': exportType,
        'entity_id': 'export_${DateTime.now().millisecondsSinceEpoch}',
        'description': 'خروجی $exportType - $rowCount ردیف',
        'new_values': {
          'export_type': exportType,
          'row_count': rowCount,
          'filters': filters,
        },
      });
    } catch (e) {
      AppLogger.e('Error logging export', error: e);
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  String _actionToString(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return 'create';
      case AuditAction.update:
        return 'update';
      case AuditAction.delete:
        return 'delete';
      case AuditAction.approve:
        return 'approve';
      case AuditAction.reject:
        return 'reject';
      case AuditAction.feature:
        return 'feature';
      case AuditAction.unfeature:
        return 'unfeature';
      case AuditAction.ban:
        return 'ban';
      case AuditAction.unban:
        return 'unban';
      case AuditAction.roleChange:
        return 'role_change';
      case AuditAction.login:
        return 'login';
      case AuditAction.logout:
        return 'logout';
      case AuditAction.export:
        return 'export';
      case AuditAction.import:
        return 'import';
      case AuditAction.bulkAction:
        return 'bulk_action';
    }
  }

  String _entityTypeToString(AuditEntityType type) {
    switch (type) {
      case AuditEntityType.audiobook:
        return 'audiobook';
      case AuditEntityType.user:
        return 'user';
      case AuditEntityType.creator:
        return 'creator';
      case AuditEntityType.category:
        return 'category';
      case AuditEntityType.ticket:
        return 'ticket';
      case AuditEntityType.narratorRequest:
        return 'narrator_request';
      case AuditEntityType.promotion:
        return 'promotion';
      case AuditEntityType.schedule:
        return 'schedule';
      case AuditEntityType.settings:
        return 'settings';
    }
  }

  /// Get field label in Persian
  static String getFieldLabel(String field) {
    final labels = {
      'title_fa': 'عنوان فارسی',
      'title_en': 'عنوان انگلیسی',
      'description_fa': 'توضیحات',
      'status': 'وضعیت',
      'is_featured': 'ویژه',
      'is_free': 'رایگان',
      'price_toman': 'قیمت',
      'category_id': 'دسته‌بندی',
      'cover_url': 'تصویر جلد',
      'role': 'نقش',
      'is_disabled': 'غیرفعال',
      'display_name': 'نام نمایشی',
      'full_name': 'نام کامل',
      'email': 'ایمیل',
      'bio': 'بیوگرافی',
      'avatar_url': 'تصویر پروفایل',
      'name_fa': 'نام فارسی',
      'name_en': 'نام انگلیسی',
      'is_active': 'فعال',
      'sort_order': 'ترتیب',
      'priority': 'اولویت',
      'subject': 'موضوع',
      'message': 'پیام',
    };
    return labels[field] ?? field;
  }

  /// Format a value for display
  static String formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'بله' : 'خیر';
    if (value is DateTime) return '${value.year}/${value.month}/${value.day}';
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }
}
