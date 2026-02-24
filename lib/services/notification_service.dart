import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/admin_notification.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for managing admin notifications with realtime support
class NotificationService {
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _channel;
  static final _notificationController =
      StreamController<AdminNotification>.broadcast();

  /// Stream of new notifications (realtime)
  static Stream<AdminNotification> get notificationStream =>
      _notificationController.stream;

  /// Initialize realtime subscription for notifications.
  /// Safe to call multiple times — disposes previous subscription first.
  static Future<void> initialize(String adminId) async {
    try {
      await dispose(); // Clean up any existing subscription before creating new one

      _channel = _supabase
          .channel('admin_notifications_$adminId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'admin_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'admin_id',
              value: adminId,
            ),
            callback: (payload) {
              try {
                final notification =
                    AdminNotification.fromJson(payload.newRecord);
                _notificationController.add(notification);
              } catch (e) {
                AppLogger.e('Error parsing realtime notification', error: e);
              }
            },
          )
          .subscribe();

      AppLogger.i('Notification realtime subscription initialized');
    } catch (e) {
      AppLogger.e('Error initializing notification subscription', error: e);
    }
  }

  /// Dispose realtime subscription.
  /// Always nulls out _channel even if unsubscribe fails, to prevent leaks.
  static Future<void> dispose() async {
    final channel = _channel;
    _channel = null; // Null out immediately to prevent re-use
    try {
      await channel?.unsubscribe();
    } catch (e) {
      AppLogger.e('Error disposing notification subscription', error: e);
    }
  }

  /// Get unread notification count for current admin
  static Future<int> getUnreadCount() async {
    try {
      final response = await _supabase
          .from('admin_notifications')
          .select('id')
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      AppLogger.e('Error fetching unread count', error: e);
      return 0;
    }
  }

  /// Get notifications with optional pagination
  /// If limit is null, fetches ALL notifications
  static Future<List<AdminNotification>> getNotifications({
    int? limit,
    int offset = 0,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    try {
      var query = _supabase.from('admin_notifications').select();

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      if (type != null) {
        query = query.eq('type', _typeToString(type));
      }

      final orderedQuery = query.order('created_at', ascending: false);

      // Apply pagination if limit specified, otherwise fetch all
      final List<dynamic> response;
      if (limit != null) {
        response = await orderedQuery.range(offset, offset + limit - 1);
      } else {
        response = await orderedQuery;
      }

      return response.map((json) => AdminNotification.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.e('Error fetching notifications', error: e);
      return [];
    }
  }

  /// Get recent notifications (for panel preview)
  static Future<List<AdminNotification>> getRecentNotifications({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map(AdminNotification.fromJson).toList();
    } catch (e) {
      AppLogger.e('Error fetching recent notifications', error: e);
      return [];
    }
  }

  /// Mark single notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase.from('admin_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);
    } catch (e) {
      AppLogger.e('Error marking notification as read', error: e);
      rethrow;
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      await _supabase.from('admin_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('is_read', false);
    } catch (e) {
      AppLogger.e('Error marking all notifications as read', error: e);
      rethrow;
    }
  }

  /// Delete a notification
  static Future<void> delete(String notificationId) async {
    try {
      await _supabase
          .from('admin_notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      AppLogger.e('Error deleting notification', error: e);
      rethrow;
    }
  }

  /// Clear all notifications
  static Future<void> clearAll() async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return;

      await _supabase
          .from('admin_notifications')
          .delete()
          .eq('admin_id', adminId);
    } catch (e) {
      AppLogger.e('Error clearing all notifications', error: e);
      rethrow;
    }
  }

  /// Create a notification (for system/manual notifications)
  static Future<AdminNotification?> createNotification({
    required String adminId,
    required NotificationType type,
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _supabase
          .from('admin_notifications')
          .insert({
            'admin_id': adminId,
            'type': _typeToString(type),
            'title': title,
            'body': body,
            'data': data ?? {},
          })
          .select()
          .single();

      return AdminNotification.fromJson(response);
    } catch (e) {
      AppLogger.e('Error creating notification', error: e);
      return null;
    }
  }

  /// Broadcast notification to all admins
  static Future<void> broadcastToAllAdmins({
    required NotificationType type,
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all admin IDs
      final admins = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      final inserts = admins.map((admin) => {
        'admin_id': admin['id'],
        'type': _typeToString(type),
        'title': title,
        'body': body,
        'data': data ?? {},
      }).toList();

      if (inserts.isNotEmpty) {
        await _supabase.from('admin_notifications').insert(inserts);
      }
    } catch (e) {
      AppLogger.e('Error broadcasting notification', error: e);
      rethrow;
    }
  }

  // ============================================================================
  // NOTIFICATION PREFERENCES
  // ============================================================================

  /// Get notification preferences for current admin
  static Future<NotificationPreferences?> getPreferences() async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return null;

      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('admin_id', adminId)
          .maybeSingle();

      if (response == null) {
        // Create default preferences
        return await _createDefaultPreferences(adminId);
      }

      return NotificationPreferences.fromJson(response);
    } catch (e) {
      AppLogger.e('Error fetching notification preferences', error: e);
      return null;
    }
  }

  /// Update notification preferences
  static Future<NotificationPreferences?> updatePreferences(
      NotificationPreferences preferences) async {
    try {
      final response = await _supabase
          .from('notification_preferences')
          .update(preferences.toJson())
          .eq('id', preferences.id)
          .select()
          .single();

      return NotificationPreferences.fromJson(response);
    } catch (e) {
      AppLogger.e('Error updating notification preferences', error: e);
      return null;
    }
  }

  /// Create default preferences for new admin
  static Future<NotificationPreferences?> _createDefaultPreferences(
      String adminId) async {
    try {
      final now = DateTime.now();
      final response = await _supabase
          .from('notification_preferences')
          .insert({
            'admin_id': adminId,
            'in_app_new_content': true,
            'in_app_narrator_requests': true,
            'in_app_support_tickets': true,
            'in_app_new_users': true,
            'in_app_purchases': true,
            'in_app_reviews': true,
            'email_daily_summary': true,
            'email_critical_alerts': true,
            'email_weekly_report': false,
            'push_enabled': false,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();

      return NotificationPreferences.fromJson(response);
    } catch (e) {
      AppLogger.e('Error creating default preferences', error: e);
      return null;
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.newContentSubmitted:
        return 'new_content_submitted';
      case NotificationType.narratorRequest:
        return 'narrator_request';
      case NotificationType.supportTicket:
        return 'support_ticket';
      case NotificationType.contentApproved:
        return 'content_approved';
      case NotificationType.contentRejected:
        return 'content_rejected';
      case NotificationType.newUserSignup:
        return 'new_user_signup';
      case NotificationType.purchaseCompleted:
        return 'purchase_completed';
      case NotificationType.reviewPosted:
        return 'review_posted';
      case NotificationType.systemAlert:
        return 'system_alert';
    }
  }
}
