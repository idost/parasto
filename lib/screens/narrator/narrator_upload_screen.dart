import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/config/env.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/screens/narrator/chapter_management_screen.dart';
import 'package:myna/screens/narrator/narrator_main_shell.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/services/creator_service.dart';
import 'package:myna/widgets/common/multi_field_input.dart';

class NarratorUploadScreen extends ConsumerStatefulWidget {
  const NarratorUploadScreen({super.key});

  @override
  ConsumerState<NarratorUploadScreen> createState() => _NarratorUploadScreenState();
}

class _NarratorUploadScreenState extends ConsumerState<NarratorUploadScreen> {
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
  final _priceController = TextEditingController(text: '0');

  // Additional book metadata controllers
  final _publisherController = TextEditingController();     // ناشر
  final _archiveController = TextEditingController();       // آرشیف
  final _collectionController = TextEditingController();    // بایگانی
  List<String> _narratorNames = [];                         // گوینده - for MultiFieldInput
  
  // State
  int? _selectedCategoryId;
  bool _isFree = true;
  // NOTE: Narrators can only upload audiobooks, not music.
  // Music upload is restricted to admin role only.
  // _isMusic is always false for narrators.
  final bool _isMusic = false;
  bool _isLoading = false;
  String? _error;
  
  // Cover image
  Uint8List? _coverImageBytes;
  String? _coverFileName;

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
    // Additional book metadata controllers
    _publisherController.dispose();
    _archiveController.dispose();
    _collectionController.dispose();
    super.dispose();
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
          _coverImageBytes = bytes;
          _coverFileName = image.name;
        });
      }
    } catch (e) {
      setState(() => _error = 'خطا در انتخاب تصویر: $e');
    }
  }

  Future<String?> _uploadCoverImage() async {
    if (_coverImageBytes == null || _coverFileName == null) return null;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _coverFileName!.split('.').last;
    final path = '${user.id}/$timestamp.$extension';

    try {
      await Supabase.instance.client.storage
          .from(Env.coversBucket)
          .uploadBinary(path, _coverImageBytes!);

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from(Env.coversBucket)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      AppLogger.e('Cover upload error', error: e);
      throw Exception('خطا در آپلود تصویر جلد');
    }
  }

  Future<void> _submitBook() async {
    // Dismiss keyboard before validation/submission
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      setState(() => _error = 'لطفاً دسته‌بندی را انتخاب کنید');
      return;
    }

    if (_coverImageBytes == null) {
      setState(() => _error = 'لطفاً تصویر جلد را انتخاب کنید');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'لطفاً وارد شوید');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Upload cover image
      final coverUrl = await _uploadCoverImage();

      if (coverUrl == null) {
        throw Exception('خطا در آپلود تصویر جلد');
      }

      // 2. Create audiobook record - with orphan cover cleanup on failure
      final price = _isFree ? 0 : int.tryParse(_priceController.text) ?? 0;

      // Extract cover path from URL for potential cleanup
      String? coverPath;
      try {
        final uri = Uri.parse(coverUrl);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf('audiobook-covers');
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          coverPath = pathSegments.sublist(bucketIndex + 1).join('/');
        }
      } catch (_) {}

      Map<String, dynamic>? response;
      try {
        response = await Supabase.instance.client
            .from('audiobooks')
            .insert({
              'title_fa': _titleFaController.text.trim(),
              'title_en': _titleEnController.text.trim().isEmpty
                  ? null
                  : _titleEnController.text.trim(),
              'author_fa': _authorFaController.text.trim(),
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
              'narrator_id': user.id,
              'cover_url': coverUrl,
              'price_toman': price,
              'is_free': _isFree,
              'content_type': 'audiobook', // Narrators can only upload audiobooks
              'status': 'draft',
              'language': 'fa',
              'chapter_count': 0,
              'total_duration_seconds': 0,
              'play_count': 0,
              'purchase_count': 0,
              'review_count': 0,
              'is_featured': false,
            })
            .select()
            .maybeSingle();
      } catch (dbError) {
        // DB insert failed - clean up orphan cover file from storage
        if (coverPath != null) {
          AppLogger.w('Narrator audiobook DB insert failed, cleaning up cover: $coverPath');
          try {
            await Supabase.instance.client.storage.from(Env.coversBucket).remove([coverPath]);
          } catch (cleanupError) {
            AppLogger.e('Failed to cleanup orphan cover: $coverPath', error: cleanupError);
          }
        }
        rethrow;
      }

      if (response == null) {
        throw Exception('Failed to create audiobook');
      }
      final audiobookId = response['id'] as int?;
      final audiobookTitle = (response['title_fa'] as String?) ?? '';

      AppLogger.i('Book created successfully with ID: $audiobookId');

      if (audiobookId == null || audiobookId <= 0) {
        AppLogger.e('Invalid audiobook ID returned: $audiobookId');
        throw Exception('شناسه کتاب برگردانده نشد');
      }

      // 3. Insert book metadata into the new book_metadata table
      try {
        final narratorNamesCombined = _narratorNames.where((n) => n.isNotEmpty).join(', ');
        await Supabase.instance.client
            .from('book_metadata')
            .insert({
              'audiobook_id': audiobookId,
              'author_name': _authorFaController.text.trim().isEmpty
                  ? null : _authorFaController.text.trim(),
              'author_name_en': _authorEnController.text.trim().isEmpty
                  ? null : _authorEnController.text.trim(),
              'translator': _translatorFaController.text.trim().isEmpty
                  ? null : _translatorFaController.text.trim(),
              'translator_en': _translatorEnController.text.trim().isEmpty
                  ? null : _translatorEnController.text.trim(),
              'narrator_name': narratorNamesCombined.isEmpty
                  ? null : narratorNamesCombined,
              'publisher': _publisherController.text.trim().isEmpty
                  ? null : _publisherController.text.trim(),
            });
        AppLogger.i('Book metadata inserted for audiobook $audiobookId');
      } catch (e) {
        // Log but don't fail if metadata insert fails
        // The legacy columns have the data as backup
        AppLogger.e('Failed to insert book_metadata', error: e);
      }

      // 4. Auto-sync creators from author/translator fields
      try {
        final creatorService = CreatorService();
        await creatorService.syncCreatorsForAudiobook(
          audiobookId: audiobookId,
          contentType: 'audiobook', // Narrators can only upload books
          authorName: _authorFaController.text,
          authorNameEn: _authorEnController.text,
          translatorName: _translatorFaController.text,
          translatorNameEn: _translatorEnController.text,
        );
        AppLogger.i('Creator sync completed for audiobook $audiobookId');
      } catch (e) {
        // Log but don't fail if creator sync fails
        AppLogger.e('Failed to sync creators', error: e);
      }

      if (!mounted) return;

      // 3. Show success and navigate to chapter management
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کتاب با موفقیت ایجاد شد. حالا فصل‌ها را اضافه کنید.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Clear form before navigation so it's ready for next upload
      _clearForm();

      // Navigate to chapter management and wait for result
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(
          builder: (context) => ChapterManagementScreen(
            audiobookId: audiobookId,
            audiobookTitle: audiobookTitle,
          ),
        ),
      );

      if (!mounted) return;

      // If user submitted the book for review, navigate to audiobooks list
      // so they can see their newly submitted book and its status
      if (result == 'submitted') {
        // Switch to audiobooks tab (index 1) in the narrator shell
        ref.read(narratorShellIndexProvider.notifier).state = 1;
      }
    } catch (e) {
      AppLogger.e('Submit error', error: e);
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _titleFaController.clear();
    _titleEnController.clear();
    _authorFaController.clear();
    _authorEnController.clear();
    _translatorFaController.clear();
    _translatorEnController.clear();
    _descriptionFaController.clear();
    _descriptionEnController.clear();
    _priceController.text = '0';
    // Clear additional book metadata fields
    _publisherController.clear();
    _archiveController.clear();
    _collectionController.clear();
    setState(() {
      _selectedCategoryId = null;
      _isFree = true;
      // _isMusic is final (always false for narrators)
      _coverImageBytes = null;
      _coverFileName = null;
      _narratorNames = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(formCategoriesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        // Dismiss keyboard when tapping outside text fields
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('آپلود کتاب جدید'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image Picker
                _buildCoverPicker(),
                const SizedBox(height: 24),

                // NOTE: Content Type Toggle removed for narrators.
                // Narrators can only upload audiobooks (کتاب صوتی).
                // Music upload is restricted to admin role only.

                // Persian Title (Required)
                TextFormField(
                  controller: _titleFaController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان فارسی *',
                    hintText: 'مثال: شازده کوچولو',
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

                // English Title (Optional)
                TextFormField(
                  controller: _titleEnController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان انگلیسی (اختیاری)',
                    hintText: 'Example: The Little Prince',
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

                      // Author Farsi (Required)
                      TextFormField(
                        controller: _authorFaController,
                        decoration: const InputDecoration(
                          labelText: 'نام نویسنده (فارسی) *',
                          hintText: 'مثال: آنتوان دو سنت‌اگزوپری',
                          prefixIcon: Icon(Icons.edit),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'نام نویسنده الزامی است';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Author English (Optional)
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

                      // Translator Farsi (Optional)
                      TextFormField(
                        controller: _translatorFaController,
                        decoration: const InputDecoration(
                          labelText: 'نام مترجم (فارسی - اختیاری)',
                          hintText: 'مثال: احمد شاملو',
                          prefixIcon: Icon(Icons.translate),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Translator English (Optional)
                      TextFormField(
                        controller: _translatorEnController,
                        decoration: const InputDecoration(
                          labelText: 'نام مترجم (انگلیسی - اختیاری)',
                          hintText: 'Example: Ahmad Shamlou',
                          prefixIcon: Icon(Icons.translate),
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 16),

                      // Narrator (گوینده) - MultiFieldInput for multiple narrators
                      MultiFieldInput(
                        label: 'گوینده',
                        hintText: 'نام گوینده',
                        initialValues: _narratorNames,
                        onChanged: (values) {
                          setState(() => _narratorNames = values);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Publisher (ناشر)
                      TextFormField(
                        controller: _publisherController,
                        decoration: const InputDecoration(
                          labelText: 'ناشر (اختیاری)',
                          hintText: 'مثال: نشر چشمه',
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Archive (آرشیف)
                      TextFormField(
                        controller: _archiveController,
                        decoration: const InputDecoration(
                          labelText: 'آرشیف (اختیاری)',
                          hintText: 'منبع آرشیو',
                          prefixIcon: Icon(Icons.archive_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Collection (بایگانی)
                      TextFormField(
                        controller: _collectionController,
                        decoration: const InputDecoration(
                          labelText: 'بایگانی (اختیاری)',
                          hintText: 'نام مجموعه',
                          prefixIcon: Icon(Icons.library_books_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('خطا در بارگذاری دسته‌ها: $e'),
                  data: (categories) => DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'دسته‌بندی *',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['id'] as int,
                        child: Text((cat['name_fa'] as String?) ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                    validator: (value) {
                      if (value == null) return 'دسته‌بندی الزامی است';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Persian Description
                TextFormField(
                  controller: _descriptionFaController,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات فارسی *',
                    hintText: 'درباره کتاب بنویسید...',
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

                // English Description (Optional)
                TextFormField(
                  controller: _descriptionEnController,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات انگلیسی (اختیاری)',
                    hintText: 'Write about the book...',
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 24),

                // Free/Paid Toggle
                Container(
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
                ),
                const SizedBox(height: 24),

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

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBook,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'ذخیره و افزودن فصل‌ها',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  // NOTE: _buildContentTypeToggle() removed for narrator screen.
  // Narrators can only upload audiobooks. Music upload is admin-only.

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: _coverImageBytes != null 
                ? AppColors.primary 
                : AppColors.surfaceLight,
            width: 2,
          ),
        ),
        child: _coverImageBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.memory(
                      _coverImageBytes!,
                      fit: BoxFit.cover,
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
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تصویر جلد را انتخاب کنید',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'حداکثر ۱۰ مگابایت',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}