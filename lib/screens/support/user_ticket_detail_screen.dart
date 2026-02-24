import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/support_providers.dart';

class UserTicketDetailScreen extends ConsumerStatefulWidget {
  final int ticketId;

  const UserTicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<UserTicketDetailScreen> createState() => _UserTicketDetailScreenState();
}

class _UserTicketDetailScreenState extends ConsumerState<UserTicketDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('support_messages').insert({
        'ticket_id': widget.ticketId,
        'sender_type': 'user',
        'sender_id': user.id,
        'message_text': _messageController.text.trim(),
      });

      // Update ticket timestamp
      await Supabase.instance.client.from('support_tickets').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.ticketId);

      _messageController.clear();
      ref.invalidate(ticketDetailProvider(widget.ticketId));

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(ticketDetailProvider(widget.ticketId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('جزئیات تیکت'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(ticketDetailProvider(widget.ticketId)),
            ),
          ],
        ),
        body: ticketAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text('خطا در بارگذاری تیکت', style: TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(ticketDetailProvider(widget.ticketId)),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
          data: (ticket) {
            if (ticket == null) {
              return const Center(
                child: Text('تیکت یافت نشد', style: TextStyle(color: AppColors.textSecondary)),
              );
            }

            final status = ticket['status'] as String? ?? 'open';
            final isClosed = status == 'closed';
            final messages = ticket['messages'] as List<dynamic>? ?? [];
            final audiobook = ticket['audiobooks'] as Map<String, dynamic>?;

            return Column(
              children: [
                // Ticket Info Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket['subject'] as String? ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTypeChip(ticket['type'] as String? ?? 'other'),
                          const SizedBox(width: 12),
                          Text(
                            'شماره تیکت: #${widget.ticketId}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                          ),
                        ],
                      ),
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
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Messages List
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text('بدون پیام', style: TextStyle(color: AppColors.textTertiary)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index] as Map<String, dynamic>;
                            return _MessageBubble(message: message);
                          },
                        ),
                ),

                // Message Input or Closed Notice
                if (isClosed)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.surface,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: AppColors.textTertiary),
                        SizedBox(width: 8),
                        Text(
                          'این تیکت بسته شده است',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.surface,
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'پیام خود را بنویسید...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              maxLines: 3,
                              minLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isSending ? null : _sendMessage,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
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

  Widget _buildTypeChip(String type) {
    String label;
    switch (type) {
      case 'book_issue':
        label = 'مشکل کتاب';
        break;
      case 'account':
        label = 'حساب کاربری';
        break;
      case 'payment':
        label = 'پرداخت';
        break;
      default:
        label = 'سایر';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final senderType = message['sender_type'] as String? ?? 'user';
    final isAdmin = senderType == 'admin';
    final profile = message['profiles'] as Map<String, dynamic>?;
    final senderName = isAdmin
        ? 'پشتیبانی'
        : (profile?['display_name'] as String?) ?? (profile?['full_name'] as String?) ?? 'شما';
    final messageText = message['message_text'] as String? ?? '';
    final createdAt = message['created_at'] != null
        ? DateTime.tryParse(message['created_at'] as String)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAdmin) ...[
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAdmin ? AppColors.surface : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isAdmin ? const Radius.circular(4) : const Radius.circular(16),
                  bottomRight: isAdmin ? const Radius.circular(16) : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAdmin ? AppColors.primary : AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (createdAt != null)
                        Text(
                          '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    messageText,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          if (!isAdmin) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.person, color: AppColors.textSecondary, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
