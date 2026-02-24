import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/analytics_providers.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/utils/csv_export.dart';
import 'package:myna/screens/admin/analytics/tabs/listening_tab.dart';
import 'package:myna/screens/admin/analytics/tabs/popularity_tab.dart';
import 'package:myna/screens/admin/analytics/tabs/users_tab.dart';

/// Main analytics and reporting screen for admin dashboard
class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'آنالیتیکس و گزارش‌ها',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_rounded, color: AppColors.textSecondary),
              tooltip: 'خروجی CSV',
              onSelected: _handleExport,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'top_content',
                  child: Row(
                    children: [
                      Icon(Icons.library_music_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('محتوای برتر'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'top_creators',
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('سازندگان برتر'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'daily_listening',
                  child: Row(
                    children: [
                      Icon(Icons.headphones_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('شنیدن روزانه'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'user_stats',
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('آمار کاربران'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Filters section
            _buildFiltersSection(),

            // Tab bar
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.headphones_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('شنیدن'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('محبوبیت و فروش'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('کاربران'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  ListeningTab(),
                  PopularityTab(),
                  UsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    final dateRange = ref.watch(analyticsDateRangeProvider);
    final contentType = ref.watch(analyticsContentTypeProvider);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range filters
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'بازه زمانی:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDateChip('امروز', AnalyticsDateRange.today(), dateRange),
                      const SizedBox(width: 8),
                      _buildDateChip('۷ روز', AnalyticsDateRange.last7Days(), dateRange),
                      const SizedBox(width: 8),
                      _buildDateChip('۳۰ روز', AnalyticsDateRange.last30Days(), dateRange),
                      const SizedBox(width: 8),
                      _buildDateChip('امسال', AnalyticsDateRange.thisYear(), dateRange),
                      const SizedBox(width: 8),
                      _buildCustomDateChip(dateRange),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content type filters
          Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'نوع محتوا:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeChip('همه', null, contentType),
                      const SizedBox(width: 8),
                      _buildTypeChip('کتاب صوتی', 'book', contentType),
                      const SizedBox(width: 8),
                      _buildTypeChip('موسیقی', 'music', contentType),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, AnalyticsDateRange range, AnalyticsDateRange current) {
    final isSelected = _isSameDateRange(current, range);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(analyticsDateRangeProvider.notifier).state = range;
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: AppColors.surfaceLight,
      side: BorderSide(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderSubtle,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildCustomDateChip(AnalyticsDateRange current) {
    // Check if current range is a custom one (not a preset)
    final isCustom = !_isSameDateRange(current, AnalyticsDateRange.today()) &&
        !_isSameDateRange(current, AnalyticsDateRange.last7Days()) &&
        !_isSameDateRange(current, AnalyticsDateRange.last30Days()) &&
        !_isSameDateRange(current, AnalyticsDateRange.thisYear());

    return ActionChip(
      avatar: Icon(
        Icons.edit_calendar_rounded,
        size: 16,
        color: isCustom ? AppColors.primary : AppColors.textSecondary,
      ),
      label: Text(
        isCustom ? _formatDateRange(current) : 'سفارشی',
        style: TextStyle(
          color: isCustom ? AppColors.primary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isCustom ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: isCustom ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceLight,
      side: BorderSide(
        color: isCustom ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderSubtle,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () => _showDateRangePicker(current),
    );
  }

  Widget _buildTypeChip(String label, String? type, String? current) {
    final isSelected = current == type;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == null
                ? Icons.all_inclusive_rounded
                : type == 'book'
                    ? Icons.menu_book_rounded
                    : Icons.music_note_rounded,
            size: 14,
            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        ref.read(analyticsContentTypeProvider.notifier).state = type;
      },
      selectedColor: AppColors.secondary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.secondary,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.secondary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: AppColors.surfaceLight,
      side: BorderSide(
        color: isSelected ? AppColors.secondary.withValues(alpha: 0.3) : AppColors.borderSubtle,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  bool _isSameDateRange(AnalyticsDateRange a, AnalyticsDateRange b) {
    return a.start.year == b.start.year &&
        a.start.month == b.start.month &&
        a.start.day == b.start.day &&
        a.end.year == b.end.year &&
        a.end.month == b.end.month &&
        a.end.day == b.end.day;
  }

  String _formatDateRange(AnalyticsDateRange range) {
    final start = range.start;
    final end = range.end;
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  Future<void> _showDateRangePicker(AnalyticsDateRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
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
      ref.read(analyticsDateRangeProvider.notifier).state = AnalyticsDateRange(
        picked.start,
        picked.end,
      );
    }
  }

  Future<void> _handleExport(String type) async {
    try {
      switch (type) {
        case 'top_content':
          final data = await ref.read(topContentProvider.future);
          await CsvExport.exportTopContent(data);
          _showExportSuccess('محتوای برتر');
          break;

        case 'top_creators':
          final data = await ref.read(topCreatorsProvider.future);
          await CsvExport.exportTopCreators(data);
          _showExportSuccess('سازندگان برتر');
          break;

        case 'daily_listening':
          final data = await ref.read(dailyListeningProvider.future);
          await CsvExport.exportDailyListening(data);
          _showExportSuccess('شنیدن روزانه');
          break;

        case 'user_stats':
          final data = await ref.read(userStatsProvider.future);
          await CsvExport.exportUserStats(data);
          _showExportSuccess('آمار کاربران');
          break;
      }
    } catch (e) {
      _showExportError();
    }
  }

  void _showExportSuccess(String name) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('گزارش $name آماده شد'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showExportError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('خطا در تهیه گزارش'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
