import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/admin_message.dart';

/// UI presentation helpers for [AdminMessage].
extension AdminMessagePresentation on AdminMessage {
  /// Priority icon
  IconData get priorityIcon {
    switch (priority) {
      case MessagePriority.low:
        return Icons.arrow_downward_rounded;
      case MessagePriority.normal:
        return Icons.remove_rounded;
      case MessagePriority.high:
        return Icons.arrow_upward_rounded;
      case MessagePriority.urgent:
        return Icons.priority_high_rounded;
    }
  }

  /// Priority color
  Color get priorityColor {
    switch (priority) {
      case MessagePriority.low:
        return AppColors.textTertiary;
      case MessagePriority.normal:
        return AppColors.info;
      case MessagePriority.high:
        return AppColors.warning;
      case MessagePriority.urgent:
        return AppColors.error;
    }
  }

  /// Type icon
  IconData get typeIcon {
    switch (type) {
      case MessageType.direct:
        return Icons.mail_rounded;
      case MessageType.announcement:
        return Icons.campaign_rounded;
      case MessageType.system:
        return Icons.settings_rounded;
    }
  }

  /// Status color
  Color get statusColor {
    switch (status) {
      case MessageStatus.draft:
        return AppColors.textTertiary;
      case MessageStatus.scheduled:
        return AppColors.info;
      case MessageStatus.sent:
        return AppColors.success;
      case MessageStatus.failed:
        return AppColors.error;
    }
  }
}

/// UI presentation helpers for [MessageTemplate].
extension MessageTemplatePresentation on MessageTemplate {
  /// Category icon
  IconData get categoryIcon {
    switch (category) {
      case 'narrator':
        return Icons.record_voice_over_rounded;
      case 'content':
        return Icons.library_books_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'support':
        return Icons.support_rounded;
      default:
        return Icons.article_rounded;
    }
  }
}
