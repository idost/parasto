import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  final int? audiobookId;
  final String? audiobookTitle;
  final String? prefilledType;

  const CreateTicketScreen({
    super.key,
    this.audiobookId,
    this.audiobookTitle,
    this.prefilledType,
  });

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedType = 'other';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledType != null) {
      _selectedType = widget.prefilledType!;
    } else if (widget.audiobookId != null) {
      _selectedType = 'book_issue';
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفا وارد حساب کاربری شوید'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create ticket
      final ticketResponse = await Supabase.instance.client.from('support_tickets').insert({
        'user_id': user.id,
        'audiobook_id': widget.audiobookId,
        'type': _selectedType,
        'subject': _subjectController.text.trim(),
        'status': 'open',
      }).select('id').maybeSingle();

      if (ticketResponse == null) {
        throw Exception('Failed to create ticket');
      }
      final ticketId = ticketResponse['id'] as int;

      // Create first message
      await Supabase.instance.client.from('support_messages').insert({
        'ticket_id': ticketId,
        'sender_type': 'user',
        'sender_id': user.id,
        'message_text': _messageController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تیکت با موفقیت ثبت شد'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('تیکت جدید'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Audiobook info if provided
                      if (widget.audiobookId != null && widget.audiobookTitle != null) ...[
                        const Text(
                          'کتاب مرتبط',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.book, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.audiobookTitle!,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Ticket Type
                      const Text(
                        'نوع درخواست',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildTypeChip('book_issue', 'مشکل کتاب', Icons.book),
                          _buildTypeChip('account', 'حساب کاربری', Icons.person),
                          _buildTypeChip('payment', 'پرداخت', Icons.payment),
                          _buildTypeChip('other', 'سایر', Icons.help),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Subject
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'موضوع *',
                          hintText: 'خلاصه مشکل یا درخواست شما',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'موضوع الزامی است' : null,
                        maxLength: 100,
                      ),
                      const SizedBox(height: 16),

                      // Message
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'پیام *',
                          hintText: 'توضیحات کامل مشکل یا درخواست خود را بنویسید...',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'پیام الزامی است' : null,
                        maxLines: 6,
                        minLines: 4,
                        maxLength: 2000,
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.send),
                          label: const Text('ارسال تیکت'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedType = value),
      avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      checkmarkColor: Colors.white,
    );
  }
}
