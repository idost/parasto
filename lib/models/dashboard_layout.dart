/// Available dashboard widgets
enum DashboardWidgetType {
  stats,
  approvalQueue,
  recentActivity,
  quickActions,
  analyticsChart,
  topContent,
  recentUsers,
  supportSummary,
  narratorRequests,
  revenueChart,
}

/// Dashboard widget configuration
class DashboardWidget {
  final String id;
  final DashboardWidgetType type;
  final int position;
  final bool visible;
  final Map<String, dynamic> config;

  const DashboardWidget({
    required this.id,
    required this.type,
    required this.position,
    this.visible = true,
    this.config = const {},
  });

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      id: json['id'] as String,
      type: _parseType(json['type'] as String? ?? json['id'] as String),
      position: json['position'] as int? ?? 0,
      visible: json['visible'] as bool? ?? true,
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'position': position,
      'visible': visible,
      'config': config,
    };
  }

  DashboardWidget copyWith({
    int? position,
    bool? visible,
    Map<String, dynamic>? config,
  }) {
    return DashboardWidget(
      id: id,
      type: type,
      position: position ?? this.position,
      visible: visible ?? this.visible,
      config: config ?? this.config,
    );
  }

  // ============================================================================
  // METADATA
  // ============================================================================

  /// Widget name in Persian
  String get name {
    switch (type) {
      case DashboardWidgetType.stats:
        return 'آمار کلی';
      case DashboardWidgetType.approvalQueue:
        return 'صف تأیید';
      case DashboardWidgetType.recentActivity:
        return 'فعالیت‌های اخیر';
      case DashboardWidgetType.quickActions:
        return 'اقدامات سریع';
      case DashboardWidgetType.analyticsChart:
        return 'نمودار آنالیتیکس';
      case DashboardWidgetType.topContent:
        return 'محتوای برتر';
      case DashboardWidgetType.recentUsers:
        return 'کاربران جدید';
      case DashboardWidgetType.supportSummary:
        return 'خلاصه پشتیبانی';
      case DashboardWidgetType.narratorRequests:
        return 'درخواست‌های گویندگی';
      case DashboardWidgetType.revenueChart:
        return 'نمودار درآمد';
    }
  }

  /// Widget description
  String get description {
    switch (type) {
      case DashboardWidgetType.stats:
        return 'نمایش آمار کلی سیستم';
      case DashboardWidgetType.approvalQueue:
        return 'محتوای در انتظار تأیید';
      case DashboardWidgetType.recentActivity:
        return 'آخرین فعالیت‌های سیستم';
      case DashboardWidgetType.quickActions:
        return 'دکمه‌های دسترسی سریع';
      case DashboardWidgetType.analyticsChart:
        return 'نمودار بازدید و استفاده';
      case DashboardWidgetType.topContent:
        return 'پرفروش‌ترین محتواها';
      case DashboardWidgetType.recentUsers:
        return 'کاربران تازه ثبت‌نام';
      case DashboardWidgetType.supportSummary:
        return 'خلاصه تیکت‌های پشتیبانی';
      case DashboardWidgetType.narratorRequests:
        return 'درخواست‌های در انتظار';
      case DashboardWidgetType.revenueChart:
        return 'نمودار درآمد و فروش';
    }
  }

  static DashboardWidgetType _parseType(String type) {
    switch (type) {
      case 'stats':
        return DashboardWidgetType.stats;
      case 'approval_queue':
      case 'approvalQueue':
        return DashboardWidgetType.approvalQueue;
      case 'recent_activity':
      case 'recentActivity':
        return DashboardWidgetType.recentActivity;
      case 'quick_actions':
      case 'quickActions':
        return DashboardWidgetType.quickActions;
      case 'analytics_chart':
      case 'analyticsChart':
        return DashboardWidgetType.analyticsChart;
      case 'top_content':
      case 'topContent':
        return DashboardWidgetType.topContent;
      case 'recent_users':
      case 'recentUsers':
        return DashboardWidgetType.recentUsers;
      case 'support_summary':
      case 'supportSummary':
        return DashboardWidgetType.supportSummary;
      case 'narrator_requests':
      case 'narratorRequests':
        return DashboardWidgetType.narratorRequests;
      case 'revenue_chart':
      case 'revenueChart':
        return DashboardWidgetType.revenueChart;
      default:
        return DashboardWidgetType.stats;
    }
  }
}

/// Dashboard layout configuration
class DashboardLayout {
  final String id;
  final String adminId;
  final List<DashboardWidget> widgets;
  final String theme;
  final bool sidebarCollapsed;
  final DateTime updatedAt;

  const DashboardLayout({
    required this.id,
    required this.adminId,
    required this.widgets,
    this.theme = 'dark',
    this.sidebarCollapsed = false,
    required this.updatedAt,
  });

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    final widgetsJson = json['widgets'] as List<dynamic>? ?? [];

    return DashboardLayout(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      widgets: widgetsJson
          .map((w) => DashboardWidget.fromJson(w as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)),
      theme: json['theme'] as String? ?? 'dark',
      sidebarCollapsed: json['sidebar_collapsed'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'widgets': widgets.map((w) => w.toJson()).toList(),
      'theme': theme,
      'sidebar_collapsed': sidebarCollapsed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DashboardLayout copyWith({
    List<DashboardWidget>? widgets,
    String? theme,
    bool? sidebarCollapsed,
  }) {
    return DashboardLayout(
      id: id,
      adminId: adminId,
      widgets: widgets ?? this.widgets,
      theme: theme ?? this.theme,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      updatedAt: DateTime.now(),
    );
  }

  /// Get only visible widgets
  List<DashboardWidget> get visibleWidgets =>
      widgets.where((w) => w.visible).toList();

  /// Get hidden widgets
  List<DashboardWidget> get hiddenWidgets =>
      widgets.where((w) => !w.visible).toList();

  /// Create default layout
  factory DashboardLayout.defaults(String adminId) {
    return DashboardLayout(
      id: '',
      adminId: adminId,
      widgets: [
        const DashboardWidget(
          id: 'stats',
          type: DashboardWidgetType.stats,
          position: 0,
        ),
        const DashboardWidget(
          id: 'approval_queue',
          type: DashboardWidgetType.approvalQueue,
          position: 1,
          config: {'limit': 5},
        ),
        const DashboardWidget(
          id: 'recent_activity',
          type: DashboardWidgetType.recentActivity,
          position: 2,
          config: {'limit': 10},
        ),
        const DashboardWidget(
          id: 'quick_actions',
          type: DashboardWidgetType.quickActions,
          position: 3,
        ),
        const DashboardWidget(
          id: 'analytics_chart',
          type: DashboardWidgetType.analyticsChart,
          position: 4,
          config: {'range': '7d'},
        ),
      ],
      updatedAt: DateTime.now(),
    );
  }

  /// Get available widgets that are not in the layout
  static List<DashboardWidgetType> getAvailableWidgets(DashboardLayout layout) {
    final existingTypes = layout.widgets.map((w) => w.type).toSet();
    return DashboardWidgetType.values
        .where((t) => !existingTypes.contains(t))
        .toList();
  }
}
