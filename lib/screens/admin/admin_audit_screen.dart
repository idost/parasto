import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/audit_log.dart';
import 'package:myna/models/audit_log_presentation.dart';
import 'package:myna/providers/audit_providers.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/audit_log_item.dart';
import 'package:myna/widgets/admin/audit_filters.dart';
import 'package:myna/widgets/admin/audit_diff_viewer.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/widgets/admin/empty_state.dart';

/// Admin screen for viewing audit logs and activity history
class AdminAuditScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AdminAuditScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  bool _showFilters = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.embedded ? null : AppBar(
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
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'گزارش فعالیت‌ها',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            // Toggle filters
            IconButton(
              icon: Icon(
                _showFilters
                    ? Icons.filter_list_off_rounded
                    : Icons.filter_list_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              tooltip: _showFilters ? 'پنهان کردن فیلترها' : 'نمایش فیلترها',
            ),
            // Refresh button
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                ref.invalidate(auditLogsProvider);
              },
              tooltip: 'بروزرسانی',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Stats summary
            _buildStatsSummary(),

            // Filters
            if (_showFilters)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AuditFilters(),
              ),

            // Audit logs list
            Expanded(
              child: _buildAuditLogsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final statsAsync = ref.watch(auditStatsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: statsAsync.when(
        data: (stats) {
          final total = stats.values.fold<int>(0, (sum, count) => sum + count);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatChip(
                  icon: Icons.list_alt_rounded,
                  label: 'کل',
                  count: total,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.add_circle_rounded,
                  label: 'ایجاد',
                  count: stats['create'] ?? 0,
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.edit_rounded,
                  label: 'ویرایش',
                  count: stats['update'] ?? 0,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.delete_rounded,
                  label: 'حذف',
                  count: stats['delete'] ?? 0,
                  color: AppColors.error,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.check_circle_rounded,
                  label: 'تأیید',
                  count: stats['approve'] ?? 0,
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.cancel_rounded,
                  label: 'رد',
                  count: stats['reject'] ?? 0,
                  color: AppColors.error,
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => const SizedBox(height: 40),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsList() {
    final logsAsync = ref.watch(auditLogsProvider);
    final filter = ref.watch(auditFilterProvider);

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return EmptyState(
            icon: Icons.history_rounded,
            message: filter.hasFilters
                ? 'هیچ فعالیتی با این فیلترها یافت نشد'
                : 'هنوز فعالیتی ثبت نشده است',
            action: filter.hasFilters
                ? ElevatedButton.icon(
                    onPressed: () {
                      ref.read(auditFilterProvider.notifier).state =
                          const AuditLogFilter();
                    },
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('پاک کردن فیلترها'),
                  )
                : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(auditLogsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];

              // Group by date
              final showDateHeader = index == 0 ||
                  !_isSameDay(logs[index - 1].createdAt, log.createdAt);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) ...[
                    if (index != 0) const SizedBox(height: 16),
                    _buildDateHeader(log.createdAt),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AuditLogItem(
                      log: log,
                      showDetails: true,
                      onTap: () => _showLogDetails(log),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const LoadingState(message: 'در حال بارگذاری...'),
      error: (error, _) => ErrorState(
        message: 'خطا در دریافت گزارش‌ها',
        onRetry: () => ref.invalidate(auditLogsProvider),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDate = DateTime(date.year, date.month, date.day);

    String label;
    if (logDate == today) {
      label = 'امروز';
    } else if (logDate == yesterday) {
      label = 'دیروز';
    } else {
      label = '${date.year}/${date.month}/${date.day}';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: AppColors.borderSubtle),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showLogDetails(AuditLog log) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: log.actionColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            log.actionIcon,
                            color: log.actionColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: log.actionColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      log.actionLabel,
                                      style: TextStyle(
                                        color: log.actionColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.entityTypeLabel,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.formattedDate,
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: AppColors.borderSubtle, height: 1),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: AuditLogDetailView(
                        oldValues: log.oldValues,
                        newValues: log.newValues,
                        changedFields: log.changedFields,
                        description: log.description,
                        createdAt: log.createdAt,
                        actorEmail: log.actorEmail,
                        entityId: log.entityId,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
