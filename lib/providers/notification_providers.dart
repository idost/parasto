import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/admin_notification.dart';
import 'package:myna/services/notification_service.dart';

/// Provider for unread notification count
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  return NotificationService.getUnreadCount();
});

/// Provider for recent notifications (for panel preview)
final recentNotificationsProvider =
    FutureProvider<List<AdminNotification>>((ref) async {
  return NotificationService.getRecentNotifications(limit: 10);
});

/// State for notification filters
class NotificationFilterState {
  final bool unreadOnly;
  final NotificationType? type;

  const NotificationFilterState({
    this.unreadOnly = false,
    this.type,
  });

  NotificationFilterState copyWith({
    bool? unreadOnly,
    NotificationType? type,
    bool clearType = false,
  }) {
    return NotificationFilterState(
      unreadOnly: unreadOnly ?? this.unreadOnly,
      type: clearType ? null : (type ?? this.type),
    );
  }
}

/// Provider for notification filter state
final notificationFilterProvider =
    StateProvider<NotificationFilterState>((ref) {
  return const NotificationFilterState();
});

/// Provider for paginated notifications list
final notificationsListProvider =
    FutureProvider.family<List<AdminNotification>, int>((ref, page) async {
  final filter = ref.watch(notificationFilterProvider);
  const limit = 20;
  final offset = page * limit;

  return NotificationService.getNotifications(
    limit: limit,
    offset: offset,
    unreadOnly: filter.unreadOnly,
    type: filter.type,
  );
});

/// Provider for all notifications
/// Fetches ALL notifications (no arbitrary limit) - let service handle performance
final allNotificationsProvider =
    FutureProvider<List<AdminNotification>>((ref) async {
  final filter = ref.watch(notificationFilterProvider);

  return NotificationService.getNotifications(
    unreadOnly: filter.unreadOnly,
    type: filter.type,
  );
});

/// Provider for notification preferences
final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences?>((ref) async {
  return NotificationService.getPreferences();
});

/// Notifier for managing notification actions
class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotificationActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await NotificationService.markAsRead(notificationId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    state = const AsyncValue.loading();
    try {
      await NotificationService.markAllAsRead();
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a notification
  Future<void> delete(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await NotificationService.delete(notificationId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    state = const AsyncValue.loading();
    try {
      await NotificationService.clearAll();
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(unreadNotificationCountProvider);
    _ref.invalidate(recentNotificationsProvider);
    _ref.invalidate(allNotificationsProvider);
  }
}

/// Provider for notification actions
final notificationActionsProvider =
    StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>((ref) {
  return NotificationActionsNotifier(ref);
});

/// Notifier for managing notification preferences
class NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<NotificationPreferences?>> {
  final Ref _ref;

  NotificationPreferencesNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await NotificationService.getPreferences();
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update preferences
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    state = const AsyncValue.loading();
    try {
      final updated = await NotificationService.updatePreferences(preferences);
      state = AsyncValue.data(updated);
      _ref.invalidate(notificationPreferencesProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for notification preferences management
final notificationPreferencesNotifierProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, AsyncValue<NotificationPreferences?>>(
  NotificationPreferencesNotifier.new,
);

/// Stream provider for realtime notifications
final realtimeNotificationProvider = StreamProvider<AdminNotification>((ref) {
  return NotificationService.notificationStream;
});

/// Provider to initialize realtime subscription
final notificationInitializerProvider = FutureProvider<void>((ref) async {
  // This should be called with the admin ID when the admin logs in
  // For now, we'll get it from the current user
  // In practice, call NotificationService.initialize(adminId) from auth state
});
