import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/dashboard_layout.dart';

/// Presentation extension for DashboardWidget UI properties
extension DashboardWidgetPresentation on DashboardWidget {
  /// Widget icon
  IconData get icon {
    switch (type) {
      case DashboardWidgetType.stats:
        return Icons.analytics_rounded;
      case DashboardWidgetType.approvalQueue:
        return Icons.pending_actions_rounded;
      case DashboardWidgetType.recentActivity:
        return Icons.history_rounded;
      case DashboardWidgetType.quickActions:
        return Icons.flash_on_rounded;
      case DashboardWidgetType.analyticsChart:
        return Icons.show_chart_rounded;
      case DashboardWidgetType.topContent:
        return Icons.star_rounded;
      case DashboardWidgetType.recentUsers:
        return Icons.person_add_rounded;
      case DashboardWidgetType.supportSummary:
        return Icons.support_rounded;
      case DashboardWidgetType.narratorRequests:
        return Icons.mic_rounded;
      case DashboardWidgetType.revenueChart:
        return Icons.attach_money_rounded;
    }
  }

  /// Widget color
  Color get color {
    switch (type) {
      case DashboardWidgetType.stats:
        return AppColors.primary;
      case DashboardWidgetType.approvalQueue:
        return AppColors.warning;
      case DashboardWidgetType.recentActivity:
        return AppColors.info;
      case DashboardWidgetType.quickActions:
        return AppColors.secondary;
      case DashboardWidgetType.analyticsChart:
        return AppColors.success;
      case DashboardWidgetType.topContent:
        return const Color(0xFFF59E0B);
      case DashboardWidgetType.recentUsers:
        return AppColors.primary;
      case DashboardWidgetType.supportSummary:
        return AppColors.warning;
      case DashboardWidgetType.narratorRequests:
        return AppColors.secondary;
      case DashboardWidgetType.revenueChart:
        return AppColors.success;
    }
  }
}
