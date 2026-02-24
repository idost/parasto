import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/dashboard_layout.dart';
import 'package:myna/services/dashboard_service.dart';
import 'package:myna/utils/app_logger.dart';

/// Provider for the current dashboard layout
final dashboardLayoutProvider =
    StateNotifierProvider<DashboardLayoutNotifier, AsyncValue<DashboardLayout>>(
        (ref) {
  return DashboardLayoutNotifier();
});

/// Notifier for dashboard layout state
class DashboardLayoutNotifier
    extends StateNotifier<AsyncValue<DashboardLayout>> {
  DashboardLayoutNotifier() : super(const AsyncValue.loading()) {
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    state = const AsyncValue.loading();
    try {
      final layout = await DashboardService.getLayout();
      if (layout != null) {
        state = AsyncValue.data(layout);
      } else {
        state = AsyncValue.error('لایه‌بندی یافت نشد', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh layout from server
  Future<void> refresh() async {
    await _loadLayout();
  }

  /// Reorder widgets
  Future<void> reorderWidgets(int oldIndex, int newIndex) async {
    final currentLayout = state.valueOrNull;
    if (currentLayout == null) return;

    final visibleWidgets = currentLayout.visibleWidgets.toList();

    // Handle reorder logic
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final widget = visibleWidgets.removeAt(oldIndex);
    visibleWidgets.insert(newIndex, widget);

    // Update positions
    final updatedWidgets = <DashboardWidget>[];
    for (int i = 0; i < visibleWidgets.length; i++) {
      updatedWidgets.add(visibleWidgets[i].copyWith(position: i));
    }

    // Add hidden widgets back
    final hiddenWidgets = currentLayout.hiddenWidgets;
    final allWidgets = [...updatedWidgets, ...hiddenWidgets];

    // Optimistic update
    state = AsyncValue.data(currentLayout.copyWith(widgets: allWidgets));

    // Save to server
    try {
      await DashboardService.updateWidgetPositions(allWidgets);
    } catch (e) {
      // Revert on error
      await _loadLayout();
    }
  }

  /// Toggle widget visibility
  Future<void> toggleWidgetVisibility(String widgetId, bool visible) async {
    final currentLayout = state.valueOrNull;
    if (currentLayout == null) return;

    // Optimistic update
    final updatedWidgets = currentLayout.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(visible: visible);
      }
      return w;
    }).toList();

    state = AsyncValue.data(currentLayout.copyWith(widgets: updatedWidgets));

    // Save to server
    try {
      await DashboardService.toggleWidgetVisibility(widgetId, visible);
    } catch (e) {
      await _loadLayout();
    }
  }

  /// Add a widget
  Future<void> addWidget(DashboardWidgetType type) async {
    try {
      await DashboardService.addWidget(type);
      await _loadLayout();
    } catch (e, st) {
      AppLogger.e('Failed to add dashboard widget: $type', error: e, stackTrace: st);
      // Reload current layout to ensure UI is in sync
      await _loadLayout();
    }
  }

  /// Remove a widget (hide it)
  Future<void> removeWidget(String widgetId) async {
    await toggleWidgetVisibility(widgetId, false);
  }

  /// Update widget configuration
  Future<void> updateWidgetConfig(
    String widgetId,
    Map<String, dynamic> config,
  ) async {
    final currentLayout = state.valueOrNull;
    if (currentLayout == null) return;

    // Optimistic update
    final updatedWidgets = currentLayout.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(config: {...w.config, ...config});
      }
      return w;
    }).toList();

    state = AsyncValue.data(currentLayout.copyWith(widgets: updatedWidgets));

    // Save to server
    try {
      await DashboardService.updateWidgetConfig(widgetId, config);
    } catch (e) {
      await _loadLayout();
    }
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    state = const AsyncValue.loading();
    try {
      final layout = await DashboardService.resetToDefaults();
      if (layout != null) {
        state = AsyncValue.data(layout);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Save current layout
  Future<void> saveLayout() async {
    final currentLayout = state.valueOrNull;
    if (currentLayout == null) return;

    try {
      await DashboardService.saveLayout(currentLayout);
    } catch (e, st) {
      AppLogger.e('Failed to save dashboard layout', error: e, stackTrace: st);
      // Layout save failed - user's customization may be lost on next load
      // Consider showing a snackbar via a callback or state flag
    }
  }
}

/// Provider for edit mode state
final dashboardEditModeProvider = StateProvider<bool>((ref) => false);

/// Provider for available widgets (not currently visible)
final availableWidgetsProvider = Provider<List<DashboardWidgetType>>((ref) {
  final layout = ref.watch(dashboardLayoutProvider);

  return layout.maybeWhen(
    data: (data) => DashboardLayout.getAvailableWidgets(data),
    orElse: () => [],
  );
});

/// Provider for hidden widgets
final hiddenWidgetsProvider = Provider<List<DashboardWidget>>((ref) {
  final layout = ref.watch(dashboardLayoutProvider);

  return layout.maybeWhen(
    data: (data) => data.hiddenWidgets,
    orElse: () => [],
  );
});
