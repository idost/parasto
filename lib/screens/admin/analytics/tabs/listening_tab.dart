import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/analytics_providers.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_line_chart.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_stat_card.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_bar_chart.dart';
import 'package:myna/utils/csv_export.dart';

/// Tab for displaying listening analytics
class ListeningTab extends ConsumerWidget {
  const ListeningTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listeningStats = ref.watch(listeningStatsProvider);
    final dailyListening = ref.watch(dailyListeningProvider);
    final topContent = ref.watch(topContentProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listeningStatsProvider);
        ref.invalidate(dailyListeningProvider);
        ref.invalidate(topContentProvider);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards row
            listeningStats.when(
              loading: () => const _StatsLoadingRow(),
              error: (e, _) => _ErrorCard(message: 'خطا در بارگذاری آمار'),
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.headphones_rounded,
                      label: 'کل ساعت‌های شنیدن',
                      value: stats.totalHours.toStringAsFixed(1),
                      subtitle: 'ساعت',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.people_rounded,
                      label: 'شنوندگان فعال',
                      value: stats.uniqueListeners.toString(),
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.library_music_rounded,
                      label: 'محتوای شنیده شده',
                      value: stats.uniqueContent.toString(),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Daily listening chart
            _SectionHeader(
              title: 'روند شنیدن روزانه',
              icon: Icons.show_chart_rounded,
              onExport: () async {
                final data = await ref.read(dailyListeningProvider.future);
                await CsvExport.exportDailyListening(data);
              },
            ),
            const SizedBox(height: 12),
            dailyListening.when(
              loading: () => const _ChartLoadingPlaceholder(),
              error: (e, _) => _ErrorCard(message: 'خطا در بارگذاری نمودار'),
              data: (data) => AnalyticsLineChart(
                data: data,
                yAxisLabel: 'ساعت',
                height: 220,
              ),
            ),

            const SizedBox(height: 24),

            // Top content by listening
            _SectionHeader(
              title: 'محبوب‌ترین محتوا',
              icon: Icons.trending_up_rounded,
              onExport: () async {
                final data = await ref.read(topContentProvider.future);
                await CsvExport.exportTopContent(data);
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: topContent.when(
                loading: () => const _ListLoadingPlaceholder(),
                error: (e, _) => _ErrorCard(message: 'خطا در بارگذاری لیست'),
                data: (items) => AnalyticsBarChart(
                  items: items.map((item) => BarChartItem(
                    title: item.title,
                    subtitle: item.typeLabel,
                    value: item.totalHours,
                    formattedValue: item.totalHours.toStringAsFixed(1),
                  )).toList(),
                  maxItems: 10,
                  valueLabel: 'ساعت',
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
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

/// Loading placeholder for charts
class _ChartLoadingPlaceholder extends StatelessWidget {
  const _ChartLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
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

/// Loading placeholder for lists
class _ListLoadingPlaceholder extends StatelessWidget {
  const _ListLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(
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
