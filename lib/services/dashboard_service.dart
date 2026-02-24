import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/dashboard_layout.dart';

/// Service for managing dashboard layouts
class DashboardService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // LAYOUT OPERATIONS
  // ============================================================================

  /// Get the current admin's dashboard layout
  static Future<DashboardLayout?> getLayout() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('dashboard_layouts')
        .select()
        .eq('admin_id', userId)
        .maybeSingle();

    if (response == null) {
      return DashboardLayout.defaults(userId);
    }

    return DashboardLayout.fromJson(response);
  }

  /// Save or update dashboard layout
  static Future<DashboardLayout?> saveLayout(DashboardLayout layout) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = {
      'admin_id': userId,
      'widgets': layout.widgets.map((w) => w.toJson()).toList(),
      'theme': layout.theme,
      'sidebar_collapsed': layout.sidebarCollapsed,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('dashboard_layouts')
        .upsert(data, onConflict: 'admin_id')
        .select()
        .single();

    return DashboardLayout.fromJson(response);
  }

  /// Update widget positions after reordering
  static Future<void> updateWidgetPositions(
      List<DashboardWidget> widgets) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('dashboard_layouts').update({
      'widgets': widgets.map((w) => w.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('admin_id', userId);
  }

  /// Toggle widget visibility
  static Future<void> toggleWidgetVisibility(
    String widgetId,
    bool visible,
  ) async {
    final layout = await getLayout();
    if (layout == null) return;

    final updatedWidgets = layout.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(visible: visible);
      }
      return w;
    }).toList();

    await _supabase.from('dashboard_layouts').update({
      'widgets': updatedWidgets.map((w) => w.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('admin_id', layout.adminId);
  }

  /// Update widget configuration
  static Future<void> updateWidgetConfig(
    String widgetId,
    Map<String, dynamic> config,
  ) async {
    final layout = await getLayout();
    if (layout == null) return;

    final updatedWidgets = layout.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(config: {...w.config, ...config});
      }
      return w;
    }).toList();

    await _supabase.from('dashboard_layouts').update({
      'widgets': updatedWidgets.map((w) => w.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('admin_id', layout.adminId);
  }

  /// Add a new widget to dashboard
  static Future<void> addWidget(DashboardWidgetType type) async {
    final layout = await getLayout();
    if (layout == null) return;

    // Check if widget already exists
    if (layout.widgets.any((w) => w.type == type)) {
      // Just make it visible
      final widgetId =
          layout.widgets.firstWhere((w) => w.type == type).id;
      await toggleWidgetVisibility(widgetId, true);
      return;
    }

    // Add new widget at the end
    final newWidget = DashboardWidget(
      id: type.name,
      type: type,
      position: layout.widgets.length,
      visible: true,
    );

    final updatedWidgets = [...layout.widgets, newWidget];

    await _supabase.from('dashboard_layouts').update({
      'widgets': updatedWidgets.map((w) => w.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('admin_id', layout.adminId);
  }

  /// Remove a widget from dashboard (set invisible)
  static Future<void> removeWidget(String widgetId) async {
    await toggleWidgetVisibility(widgetId, false);
  }

  /// Reset to default layout
  static Future<DashboardLayout?> resetToDefaults() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final defaultLayout = DashboardLayout.defaults(userId);

    await _supabase.from('dashboard_layouts').upsert({
      'admin_id': userId,
      'widgets': defaultLayout.widgets.map((w) => w.toJson()).toList(),
      'theme': defaultLayout.theme,
      'sidebar_collapsed': defaultLayout.sidebarCollapsed,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'admin_id');

    return defaultLayout;
  }

  // ============================================================================
  // THEME OPERATIONS
  // ============================================================================

  /// Update theme preference
  static Future<void> updateTheme(String theme) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('dashboard_layouts').upsert({
      'admin_id': userId,
      'theme': theme,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'admin_id');
  }

  /// Update sidebar collapsed state
  static Future<void> updateSidebarState(bool collapsed) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('dashboard_layouts').upsert({
      'admin_id': userId,
      'sidebar_collapsed': collapsed,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'admin_id');
  }
}
