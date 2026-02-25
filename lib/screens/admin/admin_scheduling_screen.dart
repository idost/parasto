import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/scheduled_feature.dart';
import 'package:myna/models/scheduled_feature_presentation.dart';
import 'package:myna/providers/scheduling_providers.dart';
import 'package:myna/widgets/admin/schedule_card.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';

/// Admin screen for content scheduling management
class AdminSchedulingScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AdminSchedulingScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AdminSchedulingScreen> createState() => _AdminSchedulingScreenState();
}

class _AdminSchedulingScreenState extends ConsumerState<AdminSchedulingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final status = switch (_tabController.index) {
        0 => null, // All
        1 => ScheduleStatus.active,
        2 => ScheduleStatus.scheduled,
        3 => ScheduleStatus.completed,
        _ => null,
      };
      ref.read(scheduleFilterProvider.notifier).state =
          ref.read(scheduleFilterProvider).copyWith(
            status: status,
            clearStatus: status == null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            if (!widget.embedded) _buildHeader(),
            _buildFilterChips(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ScheduleListView(status: null),
                  _ScheduleListView(status: ScheduleStatus.active),
                  _ScheduleListView(status: ScheduleStatus.scheduled),
                  _ScheduleListView(status: ScheduleStatus.completed),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateScheduleDialog(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('زمان‌بندی جدید'),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'زمان‌بندی محتوا',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'مدیریت محتوای ویژه و تبلیغات زمان‌بندی شده',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildStatsChip(),
        ],
      ),
    );
  }

  Widget _buildStatsChip() {
    final schedules = ref.watch(activeAndUpcomingSchedulesProvider);

    return schedules.when(
      data: (list) {
        final activeCount = list.where((s) => s.isActive).length;
        final upcomingCount = list.where((s) => s.isPending).length;

        return Row(
          children: [
            _buildMiniStat('فعال', activeCount, AppColors.success),
            const SizedBox(width: 12),
            _buildMiniStat('در انتظار', upcomingCount, AppColors.info),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filter = ref.watch(scheduleFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'نوع:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            ...FeatureType.values.map((type) {
              final isSelected = filter.featureType == type;
              return Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: FilterChip(
                  label: Text(_getFeatureTypeLabel(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(scheduleFilterProvider.notifier).state =
                        filter.copyWith(
                          featureType: selected ? type : null,
                          clearFeatureType: !selected,
                        );
                  },
                  backgroundColor: AppColors.surfaceLight,
                  selectedColor: _getFeatureTypeColor(type).withValues(alpha: 0.2),
                  checkmarkColor: _getFeatureTypeColor(type),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? _getFeatureTypeColor(type)
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'همه'),
          Tab(text: 'فعال'),
          Tab(text: 'در انتظار'),
          Tab(text: 'تکمیل شده'),
        ],
      ),
    );
  }

  void _showCreateScheduleDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => const _CreateScheduleDialog(),
    );
  }

  String _getFeatureTypeLabel(FeatureType type) {
    switch (type) {
      case FeatureType.featured:
        return 'ویژه';
      case FeatureType.banner:
        return 'بنر';
      case FeatureType.hero:
        return 'قهرمان';
      case FeatureType.categoryHighlight:
        return 'برجسته';
    }
  }

  Color _getFeatureTypeColor(FeatureType type) {
    switch (type) {
      case FeatureType.featured:
        return AppColors.warning;
      case FeatureType.banner:
        return AppColors.primary;
      case FeatureType.hero:
        return AppColors.navy;
      case FeatureType.categoryHighlight:
        return AppColors.success;
    }
  }
}

/// Schedule list view for a specific status
class _ScheduleListView extends ConsumerWidget {
  final ScheduleStatus? status;

  const _ScheduleListView({this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(scheduledFeaturesProvider);

    return schedules.when(
      data: (list) {
        // Filter by status if specified
        final filteredList = status != null
            ? list.where((s) => s.status == status).toList()
            : list;

        if (filteredList.isEmpty) {
          return EmptyState(
            icon: Icons.schedule_rounded,
            message: 'زمان‌بندی یافت نشد',
            subtitle: status == null
                ? 'هنوز هیچ زمان‌بندی ثبت نشده است'
                : null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final schedule = filteredList[index];
            return ScheduleCard(
              schedule: schedule,
              onTap: () => _showScheduleDetails(context, schedule),
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: 'خطا در بارگذاری',
        onRetry: () => ref.invalidate(scheduledFeaturesProvider),
      ),
    );
  }

  void _showScheduleDetails(BuildContext context, ScheduledFeature schedule) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: schedule.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(schedule.icon, color: schedule.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  schedule.audiobookTitle ?? 'محتوای #${schedule.audiobookId}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('نوع', schedule.featureTypeLabel),
              _buildDetailRow('وضعیت', schedule.statusLabel),
              _buildDetailRow('شروع', _formatDate(schedule.startDate)),
              if (schedule.endDate != null)
                _buildDetailRow('پایان', _formatDate(schedule.endDate!))
              else
                _buildDetailRow('پایان', 'بدون محدودیت'),
              if (schedule.notes != null && schedule.notes!.isNotEmpty)
                _buildDetailRow('یادداشت', schedule.notes!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('بستن'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(
                  '/admin/audiobooks/${schedule.audiobookId}',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('مشاهده محتوا'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// Dialog for creating a new schedule
class _CreateScheduleDialog extends ConsumerStatefulWidget {
  const _CreateScheduleDialog();

  @override
  ConsumerState<_CreateScheduleDialog> createState() => _CreateScheduleDialogState();
}

class _CreateScheduleDialogState extends ConsumerState<_CreateScheduleDialog> {
  final _audiobookIdController = TextEditingController();
  FeatureType _selectedType = FeatureType.featured;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _hasEndDate = true;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _audiobookIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'زمان‌بندی جدید',
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audiobook ID input
                TextField(
                  controller: _audiobookIdController,
                  decoration: InputDecoration(
                    labelText: 'شناسه محتوا',
                    hintText: 'مثال: 123',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Feature type dropdown
                const Text(
                  'نوع نمایش',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<FeatureType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                  ),
                  items: FeatureType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Start date
                const Text(
                  'تاریخ شروع',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(isStart: true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(_formatDate(_startDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Has end date toggle
                Row(
                  children: [
                    Checkbox(
                      value: _hasEndDate,
                      onChanged: (value) {
                        setState(() {
                          _hasEndDate = value ?? true;
                          if (_hasEndDate && _endDate == null) {
                            _endDate = _startDate.add(const Duration(days: 7));
                          }
                        });
                      },
                    ),
                    const Text(
                      'تاریخ پایان',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                // End date
                if (_hasEndDate) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(_formatDate(_endDate ?? _startDate.add(const Duration(days: 7)))),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'یادداشت (اختیاری)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _createSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('ایجاد'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : (_endDate ?? _startDate.add(const Duration(days: 7)));
    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _startDate = result;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = result;
        }
      });
    }
  }

  Future<void> _createSchedule() async {
    final audiobookId = int.tryParse(_audiobookIdController.text);
    if (audiobookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شناسه محتوا معتبر نیست'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(schedulingActionsProvider.notifier).createSchedule(
        audiobookId: audiobookId,
        startDate: _startDate,
        endDate: _hasEndDate ? _endDate : null,
        featureType: _selectedType,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('زمان‌بندی با موفقیت ایجاد شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _getTypeLabel(FeatureType type) {
    switch (type) {
      case FeatureType.featured:
        return 'ویژه';
      case FeatureType.banner:
        return 'بنر';
      case FeatureType.hero:
        return 'قهرمان';
      case FeatureType.categoryHighlight:
        return 'برجسته دسته‌بندی';
    }
  }
}
