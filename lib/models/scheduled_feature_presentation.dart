import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

import 'package:myna/models/scheduled_feature.dart';

/// UI presentation helpers for [ScheduledFeature].
extension ScheduledFeaturePresentation on ScheduledFeature {
  /// Color for the feature type
  Color get color {
    switch (featureType) {
      case FeatureType.featured:
        return const Color(0xFFF59E0B); // Amber/Gold
      case FeatureType.banner:
        return AppColors.primary;
      case FeatureType.hero:
        return const Color(0xFF8B5CF6); // Purple
      case FeatureType.categoryHighlight:
        return AppColors.success;
    }
  }

  /// Icon for the feature type
  IconData get icon {
    switch (featureType) {
      case FeatureType.featured:
        return Icons.star_rounded;
      case FeatureType.banner:
        return Icons.view_carousel_rounded;
      case FeatureType.hero:
        return Icons.auto_awesome_rounded;
      case FeatureType.categoryHighlight:
        return Icons.category_rounded;
    }
  }

  /// Status color
  Color get statusColor {
    switch (status) {
      case ScheduleStatus.scheduled:
        return AppColors.info;
      case ScheduleStatus.active:
        return AppColors.success;
      case ScheduleStatus.completed:
        return AppColors.textTertiary;
      case ScheduleStatus.cancelled:
        return AppColors.error;
    }
  }
}
