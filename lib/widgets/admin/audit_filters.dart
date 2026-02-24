import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/audit_log.dart';
import 'package:myna/providers/audit_providers.dart';
import 'package:myna/theme/app_theme.dart';

/// Filter panel for audit logs
class AuditFilters extends ConsumerStatefulWidget {
  const AuditFilters({super.key});

  @override
  ConsumerState<AuditFilters> createState() => _AuditFiltersState();
}

class _AuditFiltersState extends ConsumerState<AuditFilters> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(auditFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'فیلترها',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (filter.hasFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('پاک کردن'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Action filter
          _buildFilterSection(
            label: 'نوع عملیات',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AuditAction.values.map((action) {
                final isSelected = filter.action == action;
                return FilterChip(
                  label: Text(_getActionLabel(action)),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(auditFilterProvider.notifier).state = filter.copyWith(
                      action: selected ? action : null,
                      clearAction: !selected,
                    );
                  },
                  selectedColor: _getActionColor(action).withValues(alpha: 0.2),
                  checkmarkColor: _getActionColor(action),
                  labelStyle: TextStyle(
                    color: isSelected ? _getActionColor(action) : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide(
                    color: isSelected
                        ? _getActionColor(action).withValues(alpha: 0.3)
                        : AppColors.borderSubtle,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Entity type filter
          _buildFilterSection(
            label: 'نوع موجودیت',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AuditEntityType.values.map((type) {
                final isSelected = filter.entityType == type;
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getEntityTypeIcon(type),
                        size: 14,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(_getEntityTypeLabel(type)),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(auditFilterProvider.notifier).state = filter.copyWith(
                      entityType: selected ? type : null,
                      clearEntityType: !selected,
                    );
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.borderSubtle,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Date range filter
          _buildFilterSection(
            label: 'بازه زمانی',
            child: Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    label: 'از تاریخ',
                    value: filter.fromDate,
                    onTap: () => _selectDate(true),
                    onClear: filter.fromDate != null
                        ? () {
                            ref.read(auditFilterProvider.notifier).state =
                                filter.copyWith(clearFromDate: true);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateButton(
                    label: 'تا تاریخ',
                    value: filter.toDate,
                    onTap: () => _selectDate(false),
                    onClear: filter.toDate != null
                        ? () {
                            ref.read(auditFilterProvider.notifier).state =
                                filter.copyWith(clearToDate: true);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Quick date presets
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDatePresetChip('امروز', _getToday),
                const SizedBox(width: 8),
                _buildDatePresetChip('۷ روز', _getLast7Days),
                const SizedBox(width: 8),
                _buildDatePresetChip('۳۰ روز', _getLast30Days),
                const SizedBox(width: 8),
                _buildDatePresetChip('این ماه', _getThisMonth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? '${value.year}/${value.month}/${value.day}'
                        : 'انتخاب کنید',
                    style: TextStyle(
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              )
            else
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePresetChip(String label, Map<String, DateTime> Function() getRange) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      onPressed: () {
        final range = getRange();
        ref.read(auditFilterProvider.notifier).state =
            ref.read(auditFilterProvider).copyWith(
          fromDate: range['from'] as DateTime,
          toDate: range['to'] as DateTime,
        );
      },
      backgroundColor: AppColors.surfaceLight,
      side: const BorderSide(color: AppColors.borderSubtle),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _clearFilters() {
    ref.read(auditFilterProvider.notifier).state = const AuditLogFilter();
  }

  Future<void> _selectDate(bool isFromDate) async {
    final filter = ref.read(auditFilterProvider);
    final initialDate = isFromDate
        ? (filter.fromDate ?? DateTime.now())
        : (filter.toDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fa', 'IR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(auditFilterProvider.notifier).state = filter.copyWith(
        fromDate: isFromDate ? picked : null,
        toDate: isFromDate ? null : picked,
      );
    }
  }

  Map<String, DateTime> _getToday() {
    final now = DateTime.now();
    return {
      'from': DateTime(now.year, now.month, now.day),
      'to': DateTime(now.year, now.month, now.day, 23, 59, 59),
    };
  }

  Map<String, DateTime> _getLast7Days() {
    final now = DateTime.now();
    return {
      'from': DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
      'to': DateTime(now.year, now.month, now.day, 23, 59, 59),
    };
  }

  Map<String, DateTime> _getLast30Days() {
    final now = DateTime.now();
    return {
      'from': DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
      'to': DateTime(now.year, now.month, now.day, 23, 59, 59),
    };
  }

  Map<String, DateTime> _getThisMonth() {
    final now = DateTime.now();
    return {
      'from': DateTime(now.year, now.month, 1),
      'to': DateTime(now.year, now.month, now.day, 23, 59, 59),
    };
  }

  String _getActionLabel(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return 'ایجاد';
      case AuditAction.update:
        return 'ویرایش';
      case AuditAction.delete:
        return 'حذف';
      case AuditAction.approve:
        return 'تأیید';
      case AuditAction.reject:
        return 'رد';
      case AuditAction.feature:
        return 'ویژه';
      case AuditAction.unfeature:
        return 'حذف ویژه';
      case AuditAction.ban:
        return 'مسدود';
      case AuditAction.unban:
        return 'رفع مسدودیت';
      case AuditAction.roleChange:
        return 'تغییر نقش';
      case AuditAction.login:
        return 'ورود';
      case AuditAction.logout:
        return 'خروج';
      case AuditAction.export:
        return 'خروجی';
      case AuditAction.import:
        return 'ورودی';
      case AuditAction.bulkAction:
        return 'گروهی';
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return AppColors.success;
      case AuditAction.delete:
        return AppColors.error;
      case AuditAction.approve:
        return AppColors.success;
      case AuditAction.reject:
        return AppColors.error;
      case AuditAction.ban:
        return AppColors.error;
      case AuditAction.unban:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _getEntityTypeLabel(AuditEntityType type) {
    switch (type) {
      case AuditEntityType.audiobook:
        return 'محتوا';
      case AuditEntityType.user:
        return 'کاربر';
      case AuditEntityType.creator:
        return 'سازنده';
      case AuditEntityType.category:
        return 'دسته‌بندی';
      case AuditEntityType.ticket:
        return 'تیکت';
      case AuditEntityType.narratorRequest:
        return 'درخواست';
      case AuditEntityType.promotion:
        return 'تخفیف';
      case AuditEntityType.schedule:
        return 'زمان‌بندی';
      case AuditEntityType.settings:
        return 'تنظیمات';
    }
  }

  IconData _getEntityTypeIcon(AuditEntityType type) {
    switch (type) {
      case AuditEntityType.audiobook:
        return Icons.library_music_rounded;
      case AuditEntityType.user:
        return Icons.person_rounded;
      case AuditEntityType.creator:
        return Icons.record_voice_over_rounded;
      case AuditEntityType.category:
        return Icons.category_rounded;
      case AuditEntityType.ticket:
        return Icons.support_agent_rounded;
      case AuditEntityType.narratorRequest:
        return Icons.mic_rounded;
      case AuditEntityType.promotion:
        return Icons.local_offer_rounded;
      case AuditEntityType.schedule:
        return Icons.schedule_rounded;
      case AuditEntityType.settings:
        return Icons.settings_rounded;
    }
  }
}
