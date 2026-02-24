import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/narrator_request_providers.dart';
import 'package:myna/models/narrator_request.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/compact_stat_card.dart';
import 'package:myna/widgets/admin/filter_chip_group.dart';
import 'package:myna/widgets/admin/content_card.dart';
import 'package:myna/widgets/admin/status_badge.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/screens/admin/admin_narrator_request_detail_screen.dart';

/// Admin screen for managing narrator requests
///
/// Features:
/// - Stats cards (pending, approved, rejected)
/// - Filter by status
/// - List of requests with user info
/// - Navigate to detail screen for review
class AdminNarratorRequestsScreen extends ConsumerStatefulWidget {
  const AdminNarratorRequestsScreen({super.key});

  @override
  ConsumerState<AdminNarratorRequestsScreen> createState() => _AdminNarratorRequestsScreenState();
}

class _AdminNarratorRequestsScreenState extends ConsumerState<AdminNarratorRequestsScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(narratorRequestStatsProvider);
    final requestsAsync = ref.watch(adminNarratorRequestsProvider(_statusFilter));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Header
            const AdminScreenHeader(
              title: 'درخواست‌های گویندگی',
              icon: Icons.person_add_rounded,
            ),

            // Stats Bar
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: CompactStatCard(
                        icon: Icons.hourglass_empty_rounded,
                        value: FarsiUtils.toFarsiDigits(stats['pending']?.toString() ?? '0'),
                        label: 'در انتظار',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CompactStatCard(
                        icon: Icons.check_circle_rounded,
                        value: FarsiUtils.toFarsiDigits(stats['approved']?.toString() ?? '0'),
                        label: 'تأیید شده',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CompactStatCard(
                        icon: Icons.cancel_rounded,
                        value: FarsiUtils.toFarsiDigits(stats['rejected']?.toString() ?? '0'),
                        label: 'رد شده',
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChipGroup(
                label: 'فیلتر',
                options: const [
                  FilterOption(value: '', label: 'همه'),
                  FilterOption(value: 'pending', label: 'در انتظار'),
                  FilterOption(value: 'approved', label: 'تأیید شده'),
                  FilterOption(value: 'rejected', label: 'رد شده'),
                ],
                selectedValue: _statusFilter ?? '',
                onChanged: (value) {
                  setState(() => _statusFilter = value?.isEmpty == true ? null : value);
                  ref.invalidate(adminNarratorRequestsProvider(_statusFilter));
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Requests List
            Expanded(
              child: requestsAsync.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(
                  message: 'خطا در بارگذاری درخواست‌ها',
                  onRetry: () => ref.invalidate(adminNarratorRequestsProvider(_statusFilter)),
                  errorDetails: e.toString(),
                ),
                data: (requests) {
                  if (requests.isEmpty) {
                    return EmptyState(
                      icon: Icons.inbox_rounded,
                      message: _statusFilter == null ? 'درخواستی وجود ندارد' : 'درخواستی با این وضعیت یافت نشد',
                      subtitle: 'هنگامی که کاربران درخواست گویندگی می‌دهند، اینجا نمایش داده می‌شود',
                      iconColor: AppColors.textTertiary,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminNarratorRequestsProvider(_statusFilter));
                      ref.invalidate(narratorRequestStatsProvider);
                    },
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return _buildRequestCard(request);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(NarratorRequest request) {
    final statusColor = _getStatusColor(request.status);
    final statusLabel = request.status.label;

    return ContentCard(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(
          _getStatusIcon(request.status),
          color: statusColor,
          size: 20,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.userId.substring(0, 8) + '...',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            request.experienceText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                _formatDate(request.createdAt),
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
              if (request.reviewedAt != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.done_all, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'بررسی: ${_formatDate(request.reviewedAt!)}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
      badges: [
        StatusBadge(
          label: statusLabel,
          color: statusColor,
        ),
      ],
      actions: const [
        Icon(Icons.chevron_left, color: AppColors.textTertiary),
      ],
      onTap: () => _openRequestDetail(request),
    );
  }

  void _openRequestDetail(NarratorRequest request) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminNarratorRequestDetailScreen(request: request),
      ),
    );

    // Refresh data after returning
    ref.invalidate(adminNarratorRequestsProvider(_statusFilter));
    ref.invalidate(narratorRequestStatsProvider);
    ref.invalidate(pendingNarratorRequestsCountProvider);
  }

  Color _getStatusColor(NarratorRequestStatus status) {
    switch (status) {
      case NarratorRequestStatus.pending:
        return AppColors.warning;
      case NarratorRequestStatus.approved:
        return AppColors.success;
      case NarratorRequestStatus.rejected:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(NarratorRequestStatus status) {
    switch (status) {
      case NarratorRequestStatus.pending:
        return Icons.hourglass_empty_rounded;
      case NarratorRequestStatus.approved:
        return Icons.check_circle_rounded;
      case NarratorRequestStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final year = FarsiUtils.toFarsiDigits(date.year.toString());
    final month = FarsiUtils.toFarsiDigits(date.month.toString().padLeft(2, '0'));
    final day = FarsiUtils.toFarsiDigits(date.day.toString().padLeft(2, '0'));
    return '$year/$month/$day';
  }
}
