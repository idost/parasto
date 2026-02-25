import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/admin_notification.dart';
import 'package:myna/providers/notification_providers.dart';
import 'package:myna/widgets/admin/notification_item.dart';

/// Notification panel shown as bottom sheet
class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(recentNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'اعلان‌ها',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Unread count badge
                  unreadCount.when(
                    data: (count) {
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count خوانده نشده',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  // Mark all as read
                  unreadCount.when(
                    data: (count) {
                      if (count == 0) return const SizedBox.shrink();
                      return TextButton.icon(
                        onPressed: () {
                          ref
                              .read(notificationActionsProvider.notifier)
                              .markAllAsRead();
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('همه خوانده شد'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.borderSubtle),

            // Notifications list
            Expanded(
              child: notifications.when(
                data: (list) {
                  if (list.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final notification = list[index];
                      return NotificationItemCompact(
                        notification: notification,
                        onTap: () => _handleNotificationTap(
                          context,
                          ref,
                          notification,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (error, _) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'خطا در بارگذاری اعلان‌ها',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer - View all
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed('/admin/engage/notifications');
                  },
                  icon: const Icon(Icons.list_rounded, size: 18),
                  label: const Text('مشاهده همه اعلان‌ها'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              color: AppColors.textTertiary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'اعلانی وجود ندارد',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اعلان‌های جدید اینجا نمایش داده می‌شوند',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AdminNotification notification,
  ) {
    // Mark as read
    if (!notification.isRead) {
      ref
          .read(notificationActionsProvider.notifier)
          .markAsRead(notification.id);
    }

    // Navigate if route is available
    final route = notification.route;
    if (route != null) {
      Navigator.of(context).pop();
      Navigator.of(context).pushNamed(route);
    }
  }
}

/// Desktop-style notification dropdown panel
class NotificationDropdownPanel extends ConsumerWidget {
  const NotificationDropdownPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(recentNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'اعلان‌ها',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  unreadCount.when(
                    data: (count) {
                      if (count == 0) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () {
                          ref
                              .read(notificationActionsProvider.notifier)
                              .markAllAsRead();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('همه خوانده شد'),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.borderSubtle),

            // Notifications list
            Flexible(
              child: notifications.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_rounded,
                            color: AppColors.textTertiary,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'اعلانی وجود ندارد',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (context, index) {
                      final notification = list[index];
                      return NotificationItemCompact(
                        notification: notification,
                        onTap: () => _handleNotificationTap(
                          context,
                          ref,
                          notification,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'خطا در بارگذاری',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.borderSubtle),

            // Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/admin/engage/notifications');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('مشاهده همه'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AdminNotification notification,
  ) {
    if (!notification.isRead) {
      ref
          .read(notificationActionsProvider.notifier)
          .markAsRead(notification.id);
    }

    final route = notification.route;
    if (route != null) {
      Navigator.of(context).pushNamed(route);
    }
  }
}
