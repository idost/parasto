import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/support_providers.dart';
import 'package:myna/screens/support/create_ticket_screen.dart';
import 'package:myna/screens/support/user_ticket_detail_screen.dart';

class UserSupportScreen extends ConsumerWidget {
  const UserSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(userTicketsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('پشتیبانی'),
          centerTitle: true,
        ),
        body: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text('خطا در بارگذاری تیکت‌ها', style: TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userTicketsProvider),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
          data: (tickets) {
            if (tickets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.support_agent, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text('تیکتی ثبت نشده است', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    const Text(
                      'برای ارتباط با پشتیبانی از دکمه + استفاده کنید',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    // FAB already provides the "تیکت جدید" button
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(userTicketsProvider),
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return _TicketCard(
                    ticket: ticket,
                    onTap: () => _openTicket(context, ref, ticket),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _createTicket(context, ref),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add),
          label: const Text('تیکت جدید'),
        ),
      ),
    );
  }

  void _createTicket(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
    );
    if (result == true) {
      ref.invalidate(userTicketsProvider);
    }
  }

  void _openTicket(BuildContext context, WidgetRef ref, Map<String, dynamic> ticket) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserTicketDetailScreen(ticketId: ticket['id'] as int),
      ),
    );
    ref.invalidate(userTicketsProvider);
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'open';
    final type = ticket['type'] as String? ?? 'other';
    final subject = ticket['subject'] as String? ?? '';
    final createdAt = ticket['created_at'] != null
        ? DateTime.tryParse(ticket['created_at'] as String)
        : null;
    final audiobook = ticket['audiobooks'] as Map<String, dynamic>?;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeIcon(type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTypeLabel(type),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              if (audiobook != null) ...[
                const SizedBox(height: 12),
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
                  const Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null
                        ? '${createdAt.year}/${createdAt.month}/${createdAt.day}'
                        : '',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_left, color: AppColors.textTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'book_issue':
        icon = Icons.book;
        color = AppColors.warning;
        break;
      case 'account':
        icon = Icons.person;
        color = AppColors.primary;
        break;
      case 'payment':
        icon = Icons.payment;
        color = AppColors.success;
        break;
      default:
        icon = Icons.help;
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'book_issue':
        return 'مشکل کتاب';
      case 'account':
        return 'حساب کاربری';
      case 'payment':
        return 'پرداخت';
      default:
        return 'سایر';
    }
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color color;

    switch (status) {
      case 'open':
        label = 'باز';
        color = AppColors.warning;
        break;
      case 'in_progress':
        label = 'در حال بررسی';
        color = AppColors.primary;
        break;
      case 'closed':
        label = 'بسته شده';
        color = AppColors.success;
        break;
      default:
        label = status;
        color = AppColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
