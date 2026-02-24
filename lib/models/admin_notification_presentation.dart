import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

import 'package:myna/models/admin_notification.dart';

/// Presentation-layer extension on [AdminNotification] for UI-related getters.
extension AdminNotificationPresentation on AdminNotification {
  /// Icon for the notification type
  IconData get icon {
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

  /// Color for the notification type
  Color get color {
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
        return const Color(0xFF22C55E); // Green
      case NotificationType.reviewPosted:
        return const Color(0xFFA855F7); // Purple
      case NotificationType.systemAlert:
        return AppColors.error;
    }
  }

  /// Type label in Persian
  String get typeLabel {
    switch (type) {
      case NotificationType.newContentSubmitted:
        return 'محتوای جدید';
      case NotificationType.narratorRequest:
        return 'درخواست گویندگی';
      case NotificationType.supportTicket:
        return 'تیکت پشتیبانی';
      case NotificationType.contentApproved:
        return 'تأیید محتوا';
      case NotificationType.contentRejected:
        return 'رد محتوا';
      case NotificationType.newUserSignup:
        return 'کاربر جدید';
      case NotificationType.purchaseCompleted:
        return 'خرید';
      case NotificationType.reviewPosted:
        return 'نظر جدید';
      case NotificationType.systemAlert:
        return 'هشدار سیستم';
    }
  }
}
