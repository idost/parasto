import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/narrator/chapter_management_screen.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/services/creator_service.dart';

class NarratorEditScreen extends ConsumerStatefulWidget {
  final int audiobookId;

  const NarratorEditScreen({
    super.key,
    required this.audiobookId,
  });

  @override
  ConsumerState<NarratorEditScreen> createState() => _NarratorEditScreenState();
}

class _NarratorEditScreenState extends ConsumerState<NarratorEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _titleFaController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _authorFaController = TextEditingController();
  final _authorEnController = TextEditingController();
  final _translatorFaController = TextEditingController();
  final _translatorEnController = TextEditingController();
  final _descriptionFaController = TextEditingController();
  final _descriptionEnController = TextEditingController();
  final _priceController = TextEditingController();
  
  // State
  Map<String, dynamic>? _audiobook;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _isFree = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;
  
  // Cover image
  Uint8List? _newCoverBytes;
  String? _newCoverFileName;
  String? _existingCoverUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleFaController.dispose();
    _titleEnController.dispose();
    _authorFaController.dispose();
    _authorEnController.dispose();
    _translatorFaController.dispose();
    _translatorEnController.dispose();
    _descriptionFaController.dispose();
    _descriptionEnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load audiobook
      final audiobook = await Supabase.instance.client
          .from('audiobooks')
          .select('*')
          .eq('id', widget.audiobookId)
          .maybeSingle();

      if (audiobook == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کتاب یافت نشد'), backgroundColor: AppColors.error),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Load categories
      final categories = await Supabase.instance.client
          .from('categories')
          .select('id, name_fa, name_en')
          .eq('is_active', true)
          .order('sort_order');

      setState(() {
        _audiobook = audiobook;
        _categories = List<Map<String, dynamic>>.from(categories);

        // Populate form
        _titleFaController.text = (audiobook['title_fa'] as String?) ?? '';
        _titleEnController.text = (audiobook['title_en'] as String?) ?? '';
        _authorFaController.text = (audiobook['author_fa'] as String?) ?? '';
        _authorEnController.text = (audiobook['author_en'] as String?) ?? '';
        _translatorFaController.text = (audiobook['translator_fa'] as String?) ?? '';
        _translatorEnController.text = (audiobook['translator_en'] as String?) ?? '';
        _descriptionFaController.text = (audiobook['description_fa'] as String?) ?? '';
        _descriptionEnController.text = (audiobook['description_en'] as String?) ?? '';
        _selectedCategoryId = audiobook['category_id'] as int?;
        _isFree = (audiobook['is_free'] as bool?) ?? true;
        _priceController.text = ((audiobook['price_toman'] as int?) ?? 0).toString();
        _existingCoverUrl = audiobook['cover_url'] as String?;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'خطا در بارگذاری: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _newCoverBytes = bytes;
          _newCoverFileName = image.name;
        });
      }
    } catch (e) {
      setState(() => _error = 'خطا در انتخاب تصویر: $e');
    }
  }

  Future<String?> _uploadNewCover() async {
    if (_newCoverBytes == null || _newCoverFileName == null) return null;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _newCoverFileName!.split('.').last;
    final path = '${user.id}/$timestamp.$extension';

    try {
      await Supabase.instance.client.storage
          .from('audiobook-covers')
          .uploadBinary(path, _newCoverBytes!);

      return Supabase.instance.client.storage
          .from('audiobook-covers')
          .getPublicUrl(path);
    } catch (e) {
      throw Exception('خطا در آپلود تصویر جدید');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      setState(() => _error = 'لطفاً دسته‌بندی را انتخاب کنید');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      String? coverUrl = _existingCoverUrl;
      String? newCoverPath; // Track new cover for cleanup if DB fails

      // Upload new cover if selected
      if (_newCoverBytes != null) {
        coverUrl = await _uploadNewCover();
        // Extract path from URL for potential cleanup
        if (coverUrl != null) {
          try {
            final uri = Uri.parse(coverUrl);
            final pathSegments = uri.pathSegments;
            final bucketIndex = pathSegments.indexOf('audiobook-covers');
            if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
              newCoverPath = pathSegments.sublist(bucketIndex + 1).join('/');
            }
          } catch (_) {}
        }
      }

      final price = _isFree ? 0 : int.tryParse(_priceController.text) ?? 0;

      // Update audiobook - with orphan cover cleanup on failure
      try {
        await Supabase.instance.client
            .from('audiobooks')
            .update({
              'title_fa': _titleFaController.text.trim(),
              'title_en': _titleEnController.text.trim().isEmpty
                  ? null
                  : _titleEnController.text.trim(),
              'author_fa': _authorFaController.text.trim().isEmpty
                  ? null
                  : _authorFaController.text.trim(),
              'author_en': _authorEnController.text.trim().isEmpty
                  ? null
                  : _authorEnController.text.trim(),
              'translator_fa': _translatorFaController.text.trim().isEmpty
                  ? null
                  : _translatorFaController.text.trim(),
              'translator_en': _translatorEnController.text.trim().isEmpty
                  ? null
                  : _translatorEnController.text.trim(),
              'description_fa': _descriptionFaController.text.trim(),
              'description_en': _descriptionEnController.text.trim().isEmpty
                  ? null
                  : _descriptionEnController.text.trim(),
              'category_id': _selectedCategoryId,
              'cover_url': coverUrl,
              'price_toman': price,
              'is_free': _isFree,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.audiobookId);
      } catch (dbError) {
        // DB update failed - clean up newly uploaded cover if any
        if (newCoverPath != null) {
          AppLogger.w('Narrator audiobook DB update failed, cleaning up new cover: $newCoverPath');
          try {
            await Supabase.instance.client.storage.from('audiobook-covers').remove([newCoverPath]);
          } catch (cleanupError) {
            AppLogger.e('Failed to cleanup orphan cover: $newCoverPath', error: cleanupError);
          }
        }
        rethrow;
      }

      // Auto-sync creators from author/translator fields
      try {
        final creatorService = CreatorService();
        await creatorService.syncCreatorsForAudiobook(
          audiobookId: widget.audiobookId,
          isMusic: false, // Narrators can only edit books
          authorName: _authorFaController.text,
          authorNameEn: _authorEnController.text,
          translatorName: _translatorFaController.text,
          translatorNameEn: _translatorEnController.text,
        );
        AppLogger.d('Creator sync completed for audiobook ${widget.audiobookId}');
      } catch (e) {
        // Log but don't fail the save
        AppLogger.e('Failed to sync creators', error: e);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تغییرات ذخیره شد'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes
      }
    } catch (e) {
      setState(() => _error = 'خطا در ذخیره: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAudiobook() async {
    // First confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 8),
              Text('حذف کتاب'),
            ],
          ),
          content: Text(
            'آیا از حذف "${(_audiobook?['title_fa'] as String?) ?? 'این کتاب'}" اطمینان دارید؟\n\n'
            'این عمل غیرقابل بازگشت است و تمام فصل‌ها نیز حذف خواهند شد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm1 != true) return;
    if (!mounted) return;

    // Second confirmation with typing
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('تایید نهایی'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('برای تایید، کلمه "حذف" را تایپ کنید:'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'حذف',
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim() == 'حذف') {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('لطفاً کلمه "حذف" را صحیح وارد کنید'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('تایید و حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirm2 != true) return;
    if (!mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      // 1. Get all chapters to delete their audio files
      final chapters = await Supabase.instance.client
          .from('chapters')
          .select('audio_storage_path')
          .eq('audiobook_id', widget.audiobookId);

      // 2. Delete audio files from storage
      final audioPaths = (chapters as List)
          .map((c) => (c['audio_storage_path'] as String?) ?? '')
          .where((p) => p.isNotEmpty)
          .cast<String>()
          .toList();

      if (audioPaths.isNotEmpty) {
        await Supabase.instance.client.storage
            .from('audiobook-audio')
            .remove(audioPaths);
      }

      // 3. Delete cover image from storage (extract path from URL)
      if (_existingCoverUrl != null && _existingCoverUrl!.isNotEmpty) {
        try {
          final uri = Uri.parse(_existingCoverUrl!);
          final pathSegments = uri.pathSegments;
          final coverIndex = pathSegments.indexOf('audiobook-covers');
          if (coverIndex != -1 && coverIndex < pathSegments.length - 1) {
            final coverPath = pathSegments.sublist(coverIndex + 1).join('/');
            await Supabase.instance.client.storage
                .from('audiobook-covers')
                .remove([coverPath]);
          }
        } catch (e) {
          AppLogger.w('Cover delete error (non-critical)', error: e);
        }
      }

      // 4. Delete chapters (cascade should handle this, but be explicit)
      await Supabase.instance.client
          .from('chapters')
          .delete()
          .eq('audiobook_id', widget.audiobookId);

      // 5. Delete audiobook
      await Supabase.instance.client
          .from('audiobooks')
          .delete()
          .eq('id', widget.audiobookId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کتاب حذف شد'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = 'خطا در حذف: $e');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _openChapterManagement() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChapterManagementScreen(
          audiobookId: widget.audiobookId,
          audiobookTitle: (_audiobook?['title_fa'] as String?) ?? '',
        ),
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'draft':
        return 'پیش‌نویس';
      case 'submitted':
        return 'در انتظار بررسی';
      case 'under_review':
        return 'در حال بررسی';
      case 'approved':
        return 'تایید شده';
      case 'rejected':
        return 'رد شده';
      default:
        return 'نامشخص';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'draft':
        return AppColors.textTertiary;
      case 'submitted':
      case 'under_review':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
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
          title: const Text('ویرایش کتاب'),
          centerTitle: true,
          actions: [
            if (!_isLoading && _audiobook != null)
              IconButton(
                onPressed: _isDeleting ? null : _deleteAudiobook,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete, color: AppColors.error),
                tooltip: 'حذف کتاب',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _audiobook == null
                ? Center(
                    child: Text(
                      _error ?? 'کتاب یافت نشد',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status badge
                          _buildStatusBadge(),
                          const SizedBox(height: 16),

                          // Cover Image
                          _buildCoverPicker(),
                          const SizedBox(height: 24),

                          // Persian Title
                          TextFormField(
                            controller: _titleFaController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان فارسی *',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'عنوان فارسی الزامی است';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // English Title
                          TextFormField(
                            controller: _titleEnController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان انگلیسی (اختیاری)',
                              prefixIcon: Icon(Icons.title),
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 24),

                          // Author/Translator Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.medium,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.person, color: AppColors.primary, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'اطلاعات نویسنده و مترجم',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Author Farsi
                                TextFormField(
                                  controller: _authorFaController,
                                  decoration: const InputDecoration(
                                    labelText: 'نام نویسنده (فارسی)',
                                    hintText: 'مثال: آنتوان دو سنت‌اگزوپری',
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Author English
                                TextFormField(
                                  controller: _authorEnController,
                                  decoration: const InputDecoration(
                                    labelText: 'نام نویسنده (انگلیسی - اختیاری)',
                                    hintText: 'Example: Antoine de Saint-Exupéry',
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                const SizedBox(height: 12),

                                // Translator Farsi
                                TextFormField(
                                  controller: _translatorFaController,
                                  decoration: const InputDecoration(
                                    labelText: 'نام مترجم (فارسی - اختیاری)',
                                    hintText: 'مثال: احمد شاملو',
                                    prefixIcon: Icon(Icons.translate),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Translator English
                                TextFormField(
                                  controller: _translatorEnController,
                                  decoration: const InputDecoration(
                                    labelText: 'نام مترجم (انگلیسی - اختیاری)',
                                    hintText: 'Example: Ahmad Shamlou',
                                    prefixIcon: Icon(Icons.translate),
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          DropdownButtonFormField<int>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'دسته‌بندی *',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat['id'] as int,
                                child: Text((cat['name_fa'] as String?) ?? ''),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Persian Description
                          TextFormField(
                            controller: _descriptionFaController,
                            decoration: const InputDecoration(
                              labelText: 'توضیحات فارسی *',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'توضیحات الزامی است';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // English Description
                          TextFormField(
                            controller: _descriptionEnController,
                            decoration: const InputDecoration(
                              labelText: 'توضیحات انگلیسی (اختیاری)',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 24),

                          // Price Section
                          _buildPriceSection(),
                          const SizedBox(height: 24),

                          // Chapter Management Button
                          OutlinedButton.icon(
                            onPressed: _openChapterManagement,
                            icon: const Icon(Icons.library_music),
                            label: Text(
                              'مدیریت فصل‌ها (${FarsiUtils.toFarsiDigits((_audiobook?['chapter_count'] as int?) ?? 0)} فصل)',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Error Message
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: AppRadius.small,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Save Button
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'ذخیره تغییرات',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = _audiobook?['status'] as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: AppRadius.small,
        border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            status == 'approved'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : Icons.pending,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 12),
          Text(
            'وضعیت: ${_getStatusText(status)}',
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${(_audiobook?['chapter_count'] as int?) ?? 0} فصل',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPicker() {
    final hasNewCover = _newCoverBytes != null;
    final hasExistingCover = _existingCoverUrl != null && _existingCoverUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: hasNewCover
                  ? Image.memory(_newCoverBytes!, fit: BoxFit.cover)
                  : hasExistingCover
                      ? Image.network(
                          _existingCoverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : const Icon(
                          Icons.image,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: AppColors.background.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: _pickCoverImage,
                ),
              ),
            ),
            if (hasNewCover)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: const Text(
                    'تصویر جدید',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text(
                'قیمت‌گذاری',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _isFree,
                onChanged: (value) {
                  setState(() => _isFree = value);
                },
                activeColor: AppColors.primary,
              ),
              Text(
                _isFree ? 'رایگان' : 'پولی',
                style: TextStyle(
                  color: _isFree ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (!_isFree) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'قیمت (دلار)',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'USD',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (!_isFree) {
                  final price = int.tryParse(value ?? '');
                  if (price == null || price <= 0) {
                    return 'قیمت معتبر وارد کنید';
                  }
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}