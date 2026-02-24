import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/dashboard_layout.dart';
import 'package:myna/models/dashboard_layout_presentation.dart';

/// Wrapper widget for dashboard widgets with edit mode controls
class DashboardWidgetWrapper extends StatelessWidget {
  final DashboardWidget widget;
  final bool isEditMode;
  final VoidCallback? onRemove;
  final VoidCallback? onConfigure;
  final Widget child;

  const DashboardWidgetWrapper({
    super.key,
    required this.widget,
    required this.isEditMode,
    this.onRemove,
    this.onConfigure,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditMode ? AppColors.primary.withValues(alpha: 0.5) : AppColors.borderSubtle,
          width: isEditMode ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: child,
          ),

          // Edit mode overlay
          if (isEditMode) ...[
            // Drag handle
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Widget name badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                children: [
                  // Configure button
                  if (onConfigure != null)
                    _ActionButton(
                      icon: Icons.settings_rounded,
                      color: AppColors.info,
                      onTap: onConfigure!,
                      tooltip: 'تنظیمات',
                    ),
                  const SizedBox(width: 4),
                  // Remove button
                  if (onRemove != null)
                    _ActionButton(
                      icon: Icons.visibility_off_rounded,
                      color: AppColors.error,
                      onTap: onRemove!,
                      tooltip: 'پنهان کردن',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for adding widgets to the dashboard
class WidgetPickerDialog extends StatelessWidget {
  final List<DashboardWidgetType> availableWidgets;
  final void Function(DashboardWidgetType) onSelect;

  const WidgetPickerDialog({
    super.key,
    required this.availableWidgets,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'افزودن ویجت',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: availableWidgets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'همه ویجت‌ها در حال نمایش هستند',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: availableWidgets.map((type) {
                      final tempWidget = DashboardWidget(
                        id: type.name,
                        type: type,
                        position: 0,
                      );
                      return _WidgetOption(
                        widget: tempWidget,
                        onSelect: () {
                          onSelect(type);
                          Navigator.of(context).pop();
                        },
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
}

class _WidgetOption extends StatelessWidget {
  final DashboardWidget widget;
  final VoidCallback onSelect;

  const _WidgetOption({
    required this.widget,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for configuring widget options
class WidgetConfigDialog extends StatefulWidget {
  final DashboardWidget dashboardWidget;
  final void Function(Map<String, dynamic>) onSave;

  const WidgetConfigDialog({
    super.key,
    required this.dashboardWidget,
    required this.onSave,
  });

  @override
  State<WidgetConfigDialog> createState() => _WidgetConfigDialogState();
}

class _WidgetConfigDialogState extends State<WidgetConfigDialog> {
  late Map<String, dynamic> _config;

  DashboardWidget get _dashboardWidget => widget.dashboardWidget;

  @override
  void initState() {
    super.initState();
    _config = Map.from(_dashboardWidget.config);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _dashboardWidget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _dashboardWidget.icon,
                color: _dashboardWidget.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تنظیمات ${_dashboardWidget.name}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: _buildConfigOptions(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onSave(_config);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigOptions() {
    switch (_dashboardWidget.type) {
      case DashboardWidgetType.approvalQueue:
      case DashboardWidgetType.recentActivity:
      case DashboardWidgetType.topContent:
      case DashboardWidgetType.recentUsers:
      case DashboardWidgetType.narratorRequests:
        return _buildLimitConfig();
      case DashboardWidgetType.analyticsChart:
      case DashboardWidgetType.revenueChart:
        return _buildRangeConfig();
      default:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'این ویجت تنظیمات قابل تغییری ندارد',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Widget _buildLimitConfig() {
    final limit = _config['limit'] as int? ?? 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تعداد آیتم‌ها',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [3, 5, 10, 15].map((value) {
            final isSelected = limit == value;
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: ChoiceChip(
                label: Text('$value'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _config['limit'] = value;
                    });
                  }
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRangeConfig() {
    final range = _config['range'] as String? ?? '7d';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'بازه زمانی',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('7d', '۷ روز'),
            ('14d', '۱۴ روز'),
            ('30d', '۳۰ روز'),
            ('90d', '۹۰ روز'),
          ].map((entry) {
            final isSelected = range == entry.$1;
            return ChoiceChip(
              label: Text(entry.$2),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _config['range'] = entry.$1;
                  });
                }
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
