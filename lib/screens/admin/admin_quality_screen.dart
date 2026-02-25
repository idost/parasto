import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/quality_issue.dart';
import 'package:myna/models/quality_issue_presentation.dart';
import 'package:myna/providers/quality_providers.dart';
import 'package:myna/widgets/admin/quality_issue_card.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';

/// Admin screen for content quality management
class AdminQualityScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AdminQualityScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AdminQualityScreen> createState() => _AdminQualityScreenState();
}

class _AdminQualityScreenState extends ConsumerState<AdminQualityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        0 => QualityIssueStatus.open,
        1 => QualityIssueStatus.resolved,
        2 => QualityIssueStatus.ignored,
        _ => QualityIssueStatus.open,
      };
      ref.read(qualityFilterProvider.notifier).state =
          ref.read(qualityFilterProvider).copyWith(status: status);
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
            _buildStatsCards(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _IssuesListView(status: QualityIssueStatus.open),
                  _IssuesListView(status: QualityIssueStatus.resolved),
                  _IssuesListView(status: QualityIssueStatus.ignored),
                ],
              ),
            ),
          ],
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
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.warning,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کنترل کیفیت محتوا',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'بررسی و رفع مشکلات کیفی محتواها',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildRunCheckButton(),
        ],
      ),
    );
  }

  Widget _buildRunCheckButton() {
    final currentRun = ref.watch(runningCheckProvider);

    return currentRun.when(
      data: (run) {
        if (run != null && run.isRunning) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'در حال بررسی... ${run.checkedItems}/${run.totalItems}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ElevatedButton.icon(
          onPressed: _runBatchCheck,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('اجرای بررسی کیفیت'),
        );
      },
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => ElevatedButton.icon(
        onPressed: _runBatchCheck,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('اجرای بررسی کیفیت'),
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = ref.watch(qualityStatsProvider);

    return stats.when(
      data: (data) {
        final criticalCount = data.bySeverity[QualitySeverity.critical] ?? 0;
        final warningCount = data.bySeverity[QualitySeverity.warning] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatCard(
                'مشکلات باز',
                data.openIssues.toString(),
                Icons.error_outline_rounded,
                AppColors.error,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'بحرانی',
                criticalCount.toString(),
                Icons.warning_rounded,
                AppColors.error,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'هشدار',
                warningCount.toString(),
                Icons.warning_amber_rounded,
                AppColors.warning,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'حل شده',
                data.resolvedIssues.toString(),
                Icons.check_circle_outline_rounded,
                AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'نادیده',
                data.ignoredIssues.toString(),
                Icons.visibility_off_outlined,
                AppColors.textTertiary,
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
          Tab(text: 'مشکلات باز'),
          Tab(text: 'حل شده'),
          Tab(text: 'نادیده گرفته شده'),
        ],
      ),
    );
  }

  void _runBatchCheck() async {
    try {
      await ref.read(qualityActionsProvider.notifier).runBatchCheck();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بررسی کیفیت آغاز شد'),
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
    }
  }
}

/// Issues list view for a specific status
class _IssuesListView extends ConsumerWidget {
  final QualityIssueStatus status;

  const _IssuesListView({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(qualityIssuesProvider);

    return issues.when(
      data: (list) {
        // Filter by status locally
        final filteredList = list.where((i) => i.status == status).toList();

        if (filteredList.isEmpty) {
          return EmptyState(
            icon: status == QualityIssueStatus.open
                ? Icons.check_circle_rounded
                : Icons.inbox_rounded,
            message: status == QualityIssueStatus.open
                ? 'مشکل کیفی یافت نشد'
                : 'موردی وجود ندارد',
            subtitle: status == QualityIssueStatus.open
                ? 'تمام محتواها از نظر کیفی تأیید شده‌اند'
                : null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final issue = filteredList[index];
            return QualityIssueCard(
              issue: issue,
              showAudiobookInfo: true,
              onTap: () => _showIssueDetails(context, ref, issue),
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: 'خطا در بارگذاری',
        onRetry: () => ref.invalidate(qualityIssuesProvider),
      ),
    );
  }

  void _showIssueDetails(BuildContext context, WidgetRef ref, QualityIssue issue) {
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
                  color: issue.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(issue.icon, color: issue.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  issue.typeLabel,
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
              Text(
                issue.message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              if (issue.details.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'جزئیات:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        issue.details.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join('\n'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (issue.resolutionNote != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue.resolutionNote!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                  '/admin/audiobooks/${issue.audiobookId}',
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
}
