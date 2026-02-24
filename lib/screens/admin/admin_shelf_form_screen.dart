import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

class AdminShelfFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? shelf;

  const AdminShelfFormScreen({super.key, this.shelf});

  @override
  ConsumerState<AdminShelfFormScreen> createState() => _AdminShelfFormScreenState();
}

class _AdminShelfFormScreenState extends ConsumerState<AdminShelfFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;

  bool get _isEditing => widget.shelf != null;

  @override
  void initState() {
    super.initState();
    final shelf = widget.shelf;
    if (shelf != null) {
      _titleController.text = (shelf['title_fa'] as String?) ?? '';
      _descriptionController.text = (shelf['description_fa'] as String?) ?? '';
      _sortOrderController.text = (shelf['sort_order'] ?? 0).toString();
      _isActive = shelf['is_active'] == true;
    } else {
      _sortOrderController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'title_fa': _titleController.text.trim(),
        'description_fa': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'is_active': _isActive,
      };

      final shelf = widget.shelf;
      if (shelf != null) {
        await Supabase.instance.client
            .from('promo_shelves')
            .update(data)
            .eq('id', shelf['id'] as Object);
      } else {
        await Supabase.instance.client.from('promo_shelves').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'قفسه بروزرسانی شد' : 'قفسه ایجاد شد'),
            backgroundColor: AppColors.success,
          ),
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
          title: Text(_isEditing ? 'ویرایش قفسه' : 'افزودن قفسه'),
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
                      // Info Card
                      const SizedBox(height: 8),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان قفسه *',
                          hintText: 'مثال: ویژه‌ی این هفته',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'عنوان الزامی است' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'توضیحات (اختیاری)',
                          hintText: 'مثال: کتاب‌های منتخب این هفته',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Sort Order
                      TextFormField(
                        controller: _sortOrderController,
                        decoration: const InputDecoration(
                          labelText: 'ترتیب نمایش',
                          hintText: '0',
                          helperText: 'عدد کمتر = اولویت بالاتر',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Active Toggle
                      Card(
                        color: AppColors.surface,
                        child: SwitchListTile(
                          title: const Text('فعال', style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(
                            _isActive ? 'قفسه در صفحه اصلی نمایش داده می‌شود' : 'قفسه مخفی است',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(_isEditing ? 'بروزرسانی' : 'ایجاد قفسه'),
                        ),
                      ),

                      if (_isEditing) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'پس از ایجاد قفسه، می‌توانید از طریق دکمه "مدیریت کتاب‌ها" کتاب‌ها را به قفسه اضافه کنید.',
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
