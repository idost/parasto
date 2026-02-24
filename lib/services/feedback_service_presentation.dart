import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/feedback_service.dart';

extension FeedbackTypePresentationExtension on FeedbackType {
  Color get color {
    switch (this) {
      case FeedbackType.info:
        return AppColors.primary;
      case FeedbackType.changeRequired:
        return AppColors.warning;
      case FeedbackType.rejectionReason:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case FeedbackType.info:
        return Icons.info_outline;
      case FeedbackType.changeRequired:
        return Icons.edit_note;
      case FeedbackType.rejectionReason:
        return Icons.cancel_outlined;
    }
  }
}
