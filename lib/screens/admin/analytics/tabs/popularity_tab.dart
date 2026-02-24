import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/analytics_providers.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_stat_card.dart';
import 'package:myna/screens/admin/analytics/widgets/analytics_bar_chart.dart';
import 'package:myna/utils/csv_export.dart';

/// Tab for displaying popularity and sales analytics
class PopularityTab extends ConsumerWidget {
  const PopularityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesStats = ref.watch(salesStatsProvider);
    final topContent = ref.watch(topContentProvider);
    final topCreators = ref.watch(topCreatorsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesStatsProvider);
        ref.invalidate(topContentProvider);
        ref.invalidate(topCreatorsProvider);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sales stats cards
            salesStats.when(
              loading: () => const _StatsLoadingRow(),
              error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری آمار فروش'),
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.shopping_cart_rounded,
                      label: 'کل خرید',
                      value: stats.totalPurchases.toString(),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.attach_money_rounded,
                      label: 'کل درآمد',
                      value: stats.formattedRevenue,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnalyticsStatCard(
                      icon: Icons.person_rounded,
                      label: 'خریداران یکتا',
                      value: stats.uniqueBuyers.toString(),
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Top content by purchases
            _SectionHeader(
              title: 'پرفروش‌ترین محتوا',
              icon: Icons.star_rounded,
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
                error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری لیست'),
                data: (items) {
                  // Sort by purchase count for this view
                  final sorted = List.of(items)
                    ..sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));
                  return AnalyticsBarChart(
                    items: sorted.map((item) => BarChartItem(
                      title: item.title,
                      subtitle: '${item.purchaseCount} فروش',
                      value: item.revenue,
                      formattedValue: '\$${item.revenue.toStringAsFixed(0)}',
                    )).toList(),
                    maxItems: 10,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Top creators
            _SectionHeader(
              title: 'سازندگان برتر',
              icon: Icons.workspace_premium_rounded,
              onExport: () async {
                final data = await ref.read(topCreatorsProvider.future);
                await CsvExport.exportTopCreators(data);
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
              child: topCreators.when(
                loading: () => const _ListLoadingPlaceholder(),
                error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری لیست'),
                data: (items) => AnalyticsBarChart(
                  items: items.map((item) => BarChartItem(
                    title: item.name,
                    subtitle: item.typeLabel,
                    value: item.totalHours,
                    formattedValue: '${item.totalHours.toStringAsFixed(1)}h',
                  )).toList(),
                  maxItems: 10,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Top by rating
            _SectionHeader(
              title: 'بالاترین امتیاز',
              icon: Icons.thumb_up_rounded,
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
                error: (e, _) => const _ErrorCard(message: 'خطا در بارگذاری لیست'),
                data: (items) {
                  // Sort by rating for this view
                  final sorted = List.of(items)
                    ..sort((a, b) => b.avgRating.compareTo(a.avgRating));
                  return AnalyticsBarChart(
                    items: sorted.where((item) => item.avgRating > 0).map((item) => BarChartItem(
                      title: item.title,
                      subtitle: item.typeLabel,
                      value: item.avgRating,
                      formattedValue: '★ ${item.avgRating.toStringAsFixed(1)}',
                    )).toList(),
                    maxItems: 10,
                  );
                },
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
