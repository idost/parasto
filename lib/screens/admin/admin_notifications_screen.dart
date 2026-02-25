import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/admin_notification.dart';
import 'package:myna/providers/notification_providers.dart';
import 'package:myna/widgets/admin/notification_item.dart';
import 'package:myna/widgets/admin/notification_preferences_dialog.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';

/// Full notifications list screen for admin dashboard
class AdminNotificationsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AdminNotificationsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(allNotificationsProvider);
    final filter = ref.watch(notificationFilterProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.embedded ? null : AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
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
              // Unread badge
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
                      '$count',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          actions: [
            // Mark all as read
            unreadCount.when(
              data: (count) {
                if (count == 0) return const SizedBox.shrink();
                return IconButton(
                  onPressed: () {
                    ref
                        .read(notificationActionsProvider.notifier)
                        .markAllAsRead();
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  color: AppColors.textSecondary,
                  tooltip: 'همه را خوانده نشانه‌گذاری کن',
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            // Clear all
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('تنظیمات'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('پاک کردن همه',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Filters
            _buildFilters(filter),

            // Notifications list
            Expanded(
              child: notifications.when(
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.notifications_off_rounded,
                      message: filter.unreadOnly
                          ? 'همه اعلان‌ها خوانده شده‌اند'
                          : 'اعلانی وجود ندارد',
                      subtitle: filter.unreadOnly
                          ? 'اعلان خوانده نشده‌ای وجود ندارد'
                          : 'اعلان‌های جدید اینجا نمایش داده می‌شوند',
                    );
                  }

                  // Group notifications by date
                  final grouped = _groupNotificationsByDate(list);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(allNotificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        return _buildDateGroup(entry.key, entry.value);
                      },
                    ),
                  );
                },
                loading: () => const LoadingState(
                  message: 'در حال بارگذاری اعلان‌ها...',
                ),
                error: (error, _) => ErrorState(
                  message: 'خطا در بارگذاری اعلان‌ها',
                  onRetry: () => ref.invalidate(allNotificationsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(NotificationFilterState filter) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread filter toggle
          Row(
            children: [
              FilterChip(
                label: const Text('همه'),
                selected: !filter.unreadOnly && filter.type == null,
                onSelected: (_) {
                  ref.read(notificationFilterProvider.notifier).state =
                      const NotificationFilterState();
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: !filter.unreadOnly && filter.type == null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.surfaceLight,
                side: BorderSide(
                  color: !filter.unreadOnly && filter.type == null
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.borderSubtle,
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('خوانده نشده'),
                selected: filter.unreadOnly,
                onSelected: (selected) {
                  ref.read(notificationFilterProvider.notifier).state =
                      filter.copyWith(unreadOnly: selected);
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: filter.unreadOnly
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.surfaceLight,
                side: BorderSide(
                  color: filter.unreadOnly
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.borderSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Type filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: NotificationType.values.map((type) {
                final isSelected = filter.type == type;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: FilterChip(
                    avatar: Icon(
                      _getTypeIcon(type),
                      size: 14,
                      color: isSelected
                          ? _getTypeColor(type)
                          : AppColors.textSecondary,
                    ),
                    label: Text(_getTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref.read(notificationFilterProvider.notifier).state =
                          filter.copyWith(
                        type: selected ? type : null,
                        clearType: !selected,
                      );
                    },
                    selectedColor: _getTypeColor(type).withValues(alpha: 0.15),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? _getTypeColor(type)
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    backgroundColor: AppColors.surfaceLight,
                    side: BorderSide(
                      color: isSelected
                          ? _getTypeColor(type).withValues(alpha: 0.3)
                          : AppColors.borderSubtle,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(String dateLabel, List<AdminNotification> notifications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            dateLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Notifications
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: notifications.map((notification) {
                return NotificationItem(
                  notification: notification,
                  onTap: () => _handleNotificationTap(notification),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, List<AdminNotification>> _groupNotificationsByDate(
      List<AdminNotification> notifications) {
    final Map<String, List<AdminNotification>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final notification in notifications) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      String label;
      if (date == today) {
        label = 'امروز';
      } else if (date == yesterday) {
        label = 'دیروز';
      } else if (now.difference(date).inDays < 7) {
        label = 'این هفته';
      } else if (now.difference(date).inDays < 30) {
        label = 'این ماه';
      } else {
        label = 'قدیمی‌تر';
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(notification);
    }

    return grouped;
  }

  void _handleNotificationTap(AdminNotification notification) {
    // Mark as read
    if (!notification.isRead) {
      ref
          .read(notificationActionsProvider.notifier)
          .markAsRead(notification.id);
    }

    // Navigate if route is available
    final route = notification.route;
    if (route != null) {
      Navigator.of(context).pushNamed(route);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        showDialog<void>(
          context: context,
          builder: (context) => const NotificationPreferencesDialog(),
        );
        break;
      case 'clear_all':
        _showClearAllConfirmation();
        break;
    }
  }

  void _showClearAllConfirmation() {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              SizedBox(width: 12),
              Text(
                'پاک کردن همه اعلان‌ها',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید همه اعلان‌ها را پاک کنید؟ این عمل قابل بازگشت نیست.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(notificationActionsProvider.notifier).clearAll();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('پاک کردن'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newContentSubmitted:
        return Icons.library_add_rounded;
      case NotificationType.narratorRequest:
        return Icons.record_voice_over_rounded;
      case NotificationType.supportTicket:
        return Icons.support_agent_rounded;
      case NotificationType.contentApproved:
        return Icons.check_circle_rounded;
      case NotificationType.contentRejected:
        return Icons.cancel_rounded;
      case NotificationType.newUserSignup:
        return Icons.person_add_rounded;
      case NotificationType.purchaseCompleted:
        return Icons.shopping_cart_checkout_rounded;
      case NotificationType.reviewPosted:
        return Icons.rate_review_rounded;
      case NotificationType.systemAlert:
        return Icons.warning_rounded;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.newContentSubmitted:
        return AppColors.primary;
      case NotificationType.narratorRequest:
        return AppColors.secondary;
      case NotificationType.supportTicket:
        return AppColors.warning;
      case NotificationType.contentApproved:
        return AppColors.success;
      case NotificationType.contentRejected:
        return AppColors.error;
      case NotificationType.newUserSignup:
        return AppColors.info;
      case NotificationType.purchaseCompleted:
        return AppColors.success;
      case NotificationType.reviewPosted:
        return AppColors.navy;
      case NotificationType.systemAlert:
        return AppColors.error;
    }
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.newContentSubmitted:
        return 'محتوا';
      case NotificationType.narratorRequest:
        return 'گویندگی';
      case NotificationType.supportTicket:
        return 'پشتیبانی';
      case NotificationType.contentApproved:
        return 'تأیید';
      case NotificationType.contentRejected:
        return 'رد';
      case NotificationType.newUserSignup:
        return 'کاربر';
      case NotificationType.purchaseCompleted:
        return 'خرید';
      case NotificationType.reviewPosted:
        return 'نظر';
      case NotificationType.systemAlert:
        return 'سیستم';
    }
  }
}
