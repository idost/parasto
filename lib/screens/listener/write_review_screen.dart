import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/review/rating_input.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  final int audiobookId;
  final String audiobookTitle;
  final Map<String, dynamic>? existingReview;
  const WriteReviewScreen({super.key, required this.audiobookId, required this.audiobookTitle, this.existingReview});
  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int _rating = 0;
  bool _isLoading = false;
  String? _error;
  bool get _isEditing => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _rating = widget.existingReview!['rating'] as int? ?? 0;
      _titleController.text = widget.existingReview!['title'] as String? ?? '';
      _contentController.text = widget.existingReview!['content'] as String? ?? '';
    }
  }

  @override
  void dispose() { _titleController.dispose(); _contentController.dispose(); super.dispose(); }

  Future<void> _submitReview() async {
    if (_rating == 0) { setState(() => _error = 'لطفاً امتیاز دهید'); return; }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { setState(() => _error = 'لطفاً وارد شوید'); return; }
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = {'user_id': user.id, 'audiobook_id': widget.audiobookId, 'rating': _rating,
        'title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'content': _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
        'is_verified_purchase': true, 'updated_at': DateTime.now().toIso8601String()};
      if (_isEditing) {
        data['edited_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('reviews').update(data).eq('id', widget.existingReview!['id'] as Object);
      } else {
        await Supabase.instance.client.from('reviews').insert(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'نظر ویرایش شد' : 'نظر ثبت شد'), backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString().contains('duplicate') ? 'قبلاً نظر داده‌اید' : 'خطا: $e');
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: Text(_isEditing ? 'ویرایش نظر' : 'ثبت نظر'), centerTitle: true),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [const Icon(Icons.book, color: AppColors.primary), const SizedBox(width: 12),
            Expanded(child: Text(widget.audiobookTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)))])),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [const Text('امتیاز شما', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16), RatingInput(rating: _rating, onRatingChanged: (v) => setState(() => _rating = v), size: 44)])),
        const SizedBox(height: 24),
        TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'عنوان نظر (اختیاری)', prefixIcon: Icon(Icons.title)), maxLength: 100),
        const SizedBox(height: 16),
        TextFormField(controller: _contentController, decoration: const InputDecoration(labelText: 'متن نظر (اختیاری)', prefixIcon: Icon(Icons.comment), alignLabelWithHint: true), maxLines: 5, maxLength: 1000),
        const SizedBox(height: 24),
        if (_error != null) ...[Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [const Icon(Icons.error, color: AppColors.error), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error)))])), const SizedBox(height: 16)],
        ElevatedButton(onPressed: _isLoading ? null : _submitReview, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary)) : Text(_isEditing ? 'ذخیره' : 'ثبت نظر', style: const TextStyle(fontSize: 16))),
        const SizedBox(height: 32)])))));
  }
}
