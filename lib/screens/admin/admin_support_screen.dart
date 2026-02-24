import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/support_providers.dart';
import 'package:myna/screens/admin/admin_ticket_detail_screen.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/compact_stat_card.dart';
import 'package:myna/widgets/admin/filter_chip_group.dart';
import 'package:myna/widgets/admin/content_card.dart';
import 'package:myna/widgets/admin/status_badge.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/utils/farsi_utils.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(adminTicketsProvider(_statusFilter));
    final statsAsync = ref.watch(adminTicketStatsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Header
            const AdminScreenHeader(
              title: 'پشتیبانی',
              icon: Icons.support_agent_rounded,
            ),
            // Stats Bar with modern CompactStatCard
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: CompactStatCard(
                        icon: Icons.folder_open_rounded,
                        value: FarsiUtils.toFarsiDigits(stats['open'] ?? 0),
                        label: 'باز',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CompactStatCard(
                        icon: Icons.pending_actions_rounded,
                        value: FarsiUtils.toFarsiDigits(stats['in_progress'] ?? 0),
                        label: 'در حال بررسی',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CompactStatCard(
                        icon: Icons.check_circle_rounded,
                        value: FarsiUtils.toFarsiDigits(stats['closed'] ?? 0),
                        label: 'بسته شده',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Chips - scrollable to prevent overflow on small screens
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChipGroup(
                label: 'فیلتر',
                options: const [
                  FilterOption(value: '', label: 'همه'),
                  FilterOption(value: 'open', label: 'باز'),
                  FilterOption(value: 'in_progress', label: 'در حال بررسی'),
                  FilterOption(value: 'closed', label: 'بسته'),
                ],
                selectedValue: _statusFilter ?? '',
                onChanged: (value) {
                  setState(() => _statusFilter = value?.isEmpty == true ? null : value);
                  ref.invalidate(adminTicketsProvider(_statusFilter));
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Tickets List
            Expanded(
              child: ticketsAsync.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(
                  message: 'خطا در بارگذاری تیکت‌ها',
                  onRetry: () => ref.invalidate(adminTicketsProvider(_statusFilter)),
                  errorDetails: e.toString(),
                ),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return EmptyState(
                      icon: Icons.inbox_rounded,
                      message: _statusFilter == null ? 'تیکتی وجود ندارد' : 'تیکتی با این وضعیت یافت نشد',
                      subtitle: 'هنگامی که کاربران تیکت جدیدی ارسال کنند، اینجا نمایش داده می‌شود',
                      iconColor: AppColors.textTertiary,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminTicketsProvider(_statusFilter));
                      ref.invalidate(adminTicketStatsProvider);
                    },
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        final status = ticket['status'] as String? ?? 'open';
                        final type = ticket['type'] as String? ?? 'other';
                        final subject = ticket['subject'] as String? ?? '';
                        final profile = ticket['profiles'] as Map<String, dynamic>?;
                        final userName = (profile?['display_name'] as String?) ??
                            (profile?['full_name'] as String?) ??
                            (profile?['email'] as String?) ??
                            'کاربر ناشناس';
                        final userRole = profile?['role'] as String?;
                        final audiobook = ticket['audiobooks'] as Map<String, dynamic>?;
                        final updatedAt = ticket['updated_at'] != null
                            ? DateTime.tryParse(ticket['updated_at'] as String)
                            : null;

                        return ContentCard(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: _getRoleColor(userRole).withValues(alpha: 0.1),
                            child: Icon(
                              userRole == 'narrator' ? Icons.mic : Icons.person,
                              color: _getRoleColor(userRole),
                              size: 20,
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (audiobook != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.book, size: 16, color: AppColors.textTertiary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (audiobook['title_fa'] as String?) ?? '',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.tag, size: 14, color: AppColors.textTertiary),
                                  Text(
                                    ' #${ticket['id']}',
                                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    updatedAt != null
                                        ? '${updatedAt.month}/${updatedAt.day} - ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}'
                                        : '',
                                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          badges: [
                            if (userRole != null)
                              StatusBadge(
                                label: _getRoleLabel(userRole),
                                color: _getRoleColor(userRole),
                              ),
                            StatusBadge(
                              label: _getTypeLabel(type),
                              color: AppColors.textSecondary,
                            ),
                          ],
                          actions: [
                            StatusBadge(
                              label: _getStatusLabel(status),
                              color: _getStatusColor(status),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_left, color: AppColors.textTertiary),
                          ],
                          onTap: () => _openTicket(ticket),
                        );
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

  void _openTicket(Map<String, dynamic> ticket) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminTicketDetailScreen(ticketId: ticket['id'] as int),
      ),
    );
    ref.invalidate(adminTicketsProvider(_statusFilter));
    ref.invalidate(adminTicketStatsProvider);
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'narrator':
        return AppColors.secondary;
      case 'admin':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'narrator':
        return 'گوینده';
      case 'admin':
        return 'مدیر';
      default:
        return 'شنونده';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'book_issue':
        return 'کتاب';
      case 'account':
        return 'حساب';
      case 'payment':
        return 'پرداخت';
      default:
        return 'سایر';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'باز';
      case 'in_progress':
        return 'در حال بررسی';
      case 'closed':
        return 'بسته';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.primary;
      case 'closed':
        return AppColors.success;
      default:
        return AppColors.textTertiary;
    }
  }
}