import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/services/admin_unicef_report_service.dart';
import 'package:myna/utils/csv_export.dart';
import 'package:myna/utils/farsi_utils.dart';

/// State provider for the UNICEF snapshot time range
/// Defaults to last 30 days (index 1)
final unicefTimeRangeIndexProvider = StateProvider<int>((ref) => 1);

/// Available time ranges for UNICEF snapshot
final unicefTimeRanges = [
  ('۷ روز گذشته', AnalyticsDateRange.last7Days()),
  ('۳۰ روز گذشته', AnalyticsDateRange.last30Days()),
  ('۱۲ ماه گذشته', AdminUnicefReportService.last12MonthsRange()),
  ('همه زمان‌ها', AdminUnicefReportService.allTimeRange()),
];

/// Provider for UNICEF snapshot data based on selected time range
final unicefSnapshotProvider = FutureProvider<UnicefSnapshotData>((ref) async {
  final rangeIndex = ref.watch(unicefTimeRangeIndexProvider);
  final range = unicefTimeRanges[rangeIndex].$2;
  return AdminUnicefReportService.generateSnapshot(range);
});

/// Tab for displaying UNICEF Partner Metrics Snapshot
/// Screenshot-safe, clean layout for sharing with international partners
class UnicefTab extends ConsumerWidget {
  const UnicefTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeIndex = ref.watch(unicefTimeRangeIndexProvider);
    final snapshotAsync = ref.watch(unicefSnapshotProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unicefSnapshotProvider);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Time range selector
            _buildTimeRangeSelector(ref, rangeIndex),
            const SizedBox(height: 20),

            // Snapshot content
            snapshotAsync.when(
              loading: () => const _LoadingState(),
              error: (e, _) => _ErrorState(
                onRetry: () => ref.invalidate(unicefSnapshotProvider),
              ),
              data: (data) => _SnapshotContent(data: data, ref: ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
              Icons.assessment_rounded,
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
                  'گزارش یونیسف / شرکای بین‌المللی',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'UNICEF Partner Metrics',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(WidgetRef ref, int selectedIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'بازه زمانی:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(unicefTimeRanges.length, (index) {
            final isSelected = index == selectedIndex;
            return ChoiceChip(
              label: Text(unicefTimeRanges[index].$1),
              selected: isSelected,
              onSelected: (_) {
                ref.read(unicefTimeRangeIndexProvider.notifier).state = index;
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
            );
          }),
        ),
      ],
    );
  }
}

/// Main snapshot content widget
class _SnapshotContent extends StatelessWidget {
  final UnicefSnapshotData data;
  final WidgetRef ref;

  const _SnapshotContent({required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline metrics row
        _buildHeadlineMetrics(),
        const SizedBox(height: 20),

        // Content library section
        _buildContentLibrary(),
        const SizedBox(height: 20),

        // Top content and creators side by side
        _buildTopLists(),
        const SizedBox(height: 24),

        // Export button
        _buildExportButton(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeadlineMetrics() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.headphones_rounded,
            value: FarsiUtils.toFarsiDigits(data.totalHours.toStringAsFixed(1)),
            label: 'ساعت شنیدن',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.people_rounded,
            value: FarsiUtils.toFarsiDigits(data.uniqueListeners.toString()),
            label: 'شنونده فعال',
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.library_music_rounded,
            value: FarsiUtils.toFarsiDigits(data.uniqueContent.toString()),
            label: 'محتوای فعال',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildContentLibrary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.library_books_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'کتابخانه محتوا',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ContentTypeChip(
                icon: Icons.menu_book_rounded,
                label: 'کتاب صوتی',
                count: data.totalAudiobooks,
              ),
              const SizedBox(width: 12),
              _ContentTypeChip(
                icon: Icons.music_note_rounded,
                label: 'موسیقی',
                count: data.totalMusic,
              ),
              const SizedBox(width: 12),
              _ContentTypeChip(
                icon: Icons.podcasts_rounded,
                label: 'پادکست',
                count: data.totalPodcasts,
              ),
              const SizedBox(width: 12),
              _ContentTypeChip(
                icon: Icons.auto_stories_rounded,
                label: 'ای‌بوک',
                count: data.totalEbooks,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopLists() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top 3 content
        Expanded(
          child: _TopListCard(
            title: '۳ اثر پرشنونده',
            icon: Icons.star_rounded,
            items: data.topContent.take(3).map((item) => _TopListItem(
              rank: data.topContent.indexOf(item) + 1,
              title: item.title,
              subtitle: item.typeLabel,
              value: '${FarsiUtils.toFarsiDigits(item.totalHours.toStringAsFixed(1))} ساعت',
              icon: item.isMusic ? Icons.music_note_rounded : Icons.menu_book_rounded,
            )).toList(),
            emptyMessage: 'هیچ موردی نیست',
          ),
        ),
        const SizedBox(width: 12),
        // Top 3 creators
        Expanded(
          child: _TopListCard(
            title: '۳ خالق پرشنونده',
            icon: Icons.person_rounded,
            items: data.topCreators.take(3).map((item) => _TopListItem(
              rank: data.topCreators.indexOf(item) + 1,
              title: item.name,
              subtitle: item.typeLabel,
              value: '${FarsiUtils.toFarsiDigits(item.totalHours.toStringAsFixed(1))} ساعت',
              icon: Icons.person_rounded,
            )).toList(),
            emptyMessage: 'هیچ موردی نیست',
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final rangeIndex = ref.read(unicefTimeRangeIndexProvider);
          final range = unicefTimeRanges[rangeIndex].$2;

          // Show loading
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'در حال تهیه گزارش...',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          try {
            final snapshot = await AdminUnicefReportService.generateSnapshot(range);
            if (context.mounted) {
              Navigator.pop(context);
            }
            final success = await CsvExport.exportUnicefSnapshot(snapshot);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'گزارش یونیسف آماده شد' : 'خطا در تهیه گزارش'),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('خطا در تهیه گزارش'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.download_rounded),
        label: const Text('دانلود گزارش CSV'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Metric card widget for headline stats
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Content type chip for library section
class _ContentTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _ContentTypeChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              FarsiUtils.toFarsiDigits(count.toString()),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Top list card for content/creators
class _TopListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_TopListItem> items;
  final String emptyMessage;

  const _TopListCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ...items,
        ],
      ),
    );
  }
}

/// Individual item in top list
class _TopListItem extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  const _TopListItem({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                FarsiUtils.toFarsiDigits(rank.toString()),
                style: TextStyle(
                  color: rank == 1 ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Content info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(icon, size: 10, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Hours
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            SizedBox(height: 16),
            Text(
              'در حال بارگذاری...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state widget with retry button
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'خطا در بارگذاری داده‌ها',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تلاش مجدد'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
