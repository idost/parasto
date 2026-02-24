import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/analytics_providers.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_stat_card.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_line_chart.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/utils/csv_export.dart';

/// Tab for displaying user activity analytics
class UsersTab extends ConsumerWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStats = ref.watch(userStatsProvider);
    final dailySignups = ref.watch(dailySignupsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userStatsProvider);
        ref.invalidate(dailySignupsProvider);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active users stats
            _SectionHeader(
              title: 'کاربران فعال',
              icon: Icons.people_rounded,
            ),
            const SizedBox(height: 12),
            userStats.when(
              loading: () => const _StatsLoadingRow(),
              error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری آمار'),
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.today_rounded,
                      label: 'روزانه (DAU)',
                      value: stats.dau.toString(),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.date_range_rounded,
                      label: 'هفتگی (WAU)',
                      value: stats.wau.toString(),
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.calendar_month_rounded,
                      label: 'ماهانه (MAU)',
                      value: stats.mau.toString(),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Total users and signups
            _SectionHeader(
              title: 'کل کاربران',
              icon: Icons.group_rounded,
              onExport: () async {
                final data = await ref.read(userStatsProvider.future);
                await CsvExport.exportUserStats(data);
              },
            ),
            const SizedBox(height: 12),
            userStats.when(
              loading: () => const _StatsLoadingRow(),
              error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری آمار'),
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.groups_rounded,
                      label: 'کل کاربران',
                      value: stats.totalUsers.toString(),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.person_add_rounded,
                      label: 'ثبت‌نام جدید',
                      value: stats.newSignups.toString(),
                      subtitle: 'در بازه انتخابی',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Role breakdown
            _SectionHeader(
              title: 'تفکیک نقش کاربران',
              icon: Icons.pie_chart_rounded,
            ),
            const SizedBox(height: 12),
            userStats.when(
              loading: () => const _RoleBreakdownLoading(),
              error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری'),
              data: (stats) => _RoleBreakdownCard(stats: stats),
            ),

            const SizedBox(height: 24),

            // Daily signups chart
            _SectionHeader(
              title: 'روند ثبت‌نام',
              icon: Icons.show_chart_rounded,
            ),
            const SizedBox(height: 12),
            dailySignups.when(
              loading: () => const _ChartLoadingPlaceholder(),
              error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری نمودار'),
              data: (data) => _SignupsChart(data: data),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Custom chart for signups (shows count instead of hours)
class _SignupsChart extends StatelessWidget {
  final List<DailySignups> data;

  const _SignupsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Center(
          child: Text(
            'داده‌ای موجود نیست',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Convert to DailyListening for the line chart
    final chartData = data.map((d) => DailyListening(
      date: d.date,
      seconds: d.count * 3600, // Multiply by 3600 so hours = count
    )).toList();

    return AnalyticsLineChart(
      data: chartData,
      yAxisLabel: 'نفر',
      height: 200,
    );
  }
}

/// Role breakdown card showing user distribution
class _RoleBreakdownCard extends StatelessWidget {
  final UserStats stats;

  const _RoleBreakdownCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalUsers;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Center(
          child: Text(
            'کاربری ثبت نشده',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          _RoleProgressBar(
            label: 'شنوندگان',
            count: stats.listenerCount,
            total: total,
            color: AppColors.primary,
            icon: Icons.headphones_rounded,
          ),
          const SizedBox(height: 16),
          _RoleProgressBar(
            label: 'گویندگان',
            count: stats.narratorCount,
            total: total,
            color: AppColors.secondary,
            icon: Icons.mic_rounded,
          ),
          const SizedBox(height: 16),
          _RoleProgressBar(
            label: 'مدیران',
            count: stats.adminCount,
            total: total,
            color: AppColors.success,
            icon: Icons.admin_panel_settings_rounded,
          ),
        ],
      ),
    );
  }
}

/// Progress bar for role distribution
class _RoleProgressBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _RoleProgressBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? count / total : 0.0;
    final percentText = (percentage * 100).toStringAsFixed(1);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$count ($percentText%)',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section header with title and optional export button
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onExport;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onExport != null)
          TextButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('CSV'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
      ],
    );
  }
}

/// Loading placeholder for stats row
class _StatsLoadingRow extends StatelessWidget {
  const _StatsLoadingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) => Expanded(
        child: Container(
          height: 100,
          margin: EdgeInsetsDirectional.only(start: index < 2 ? 12 : 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      )),
    );
  }
}

/// Loading placeholder for role breakdown
class _RoleBreakdownLoading extends StatelessWidget {
  const _RoleBreakdownLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Loading placeholder for charts
class _ChartLoadingPlaceholder extends StatelessWidget {
  const _ChartLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Error display card
class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
