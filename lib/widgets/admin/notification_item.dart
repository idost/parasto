import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/admin_notification.dart';
import 'package:myna/models/admin_notification_presentation.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/notification_providers.dart';

/// Single notification item widget
class NotificationItem extends ConsumerWidget {
  final AdminNotification notification;
  final VoidCallback? onTap;
  final bool showActions;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsetsDirectional.only(start: 20),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) {
        ref.read(notificationActionsProvider.notifier).delete(notification.id);
      },
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationActionsProvider.notifier)
                .markAsRead(notification.id);
          }
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : notification.color.withValues(alpha: 0.05),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.borderSubtle,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Type label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: notification.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            notification.typeLabel,
                            style: TextStyle(
                              color: notification.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Time
                        Text(
                          notification.timeAgo,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight:
                            notification.isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),

                    // Body
                    if (notification.body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsetsDirectional.only(end: 4, top: 4),
                  decoration: BoxDecoration(
                    color: notification.color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact notification item for panel preview
class NotificationItemCompact extends ConsumerWidget {
  final AdminNotification notification;
  final VoidCallback? onTap;

  const NotificationItemCompact({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          ref
              .read(notificationActionsProvider.notifier)
              .markAsRead(notification.id);
        }
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : notification.color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.timeAgo,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: notification.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
