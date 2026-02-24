import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/admin/admin_ebooks_screen.dart';

/// Screen for uploading and editing ebooks
class AdminUploadEbookScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? ebook;

  const AdminUploadEbookScreen({super.key, this.ebook});

  @override
  ConsumerState<AdminUploadEbookScreen> createState() => _AdminUploadEbookScreenState();
}

class _AdminUploadEbookScreenState extends ConsumerState<AdminUploadEbookScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploading = false;
  String? _uploadProgress;

  // Form controllers
  late TextEditingController _titleFaController;
  late TextEditingController _titleEnController;
  late TextEditingController _subtitleFaController;
  late TextEditingController _descriptionFaController;
  late TextEditingController _authorFaController;
  late TextEditingController _authorEnController;
  late TextEditingController _translatorFaController;
  late TextEditingController _publisherFaController;
  late TextEditingController _priceTomanController;
  late TextEditingController _pageCountController;
  late TextEditingController _isbnController;
  late TextEditingController _publicationYearController;

  // Form state
  bool _isFree = false;
  bool _isFeatured = false;
  String _status = 'draft';
  int? _categoryId;

  // File state
  Uint8List? _coverBytes;
  String? _coverFileName;
  Uint8List? _epubBytes;
  String? _epubFileName;
  String? _existingCoverUrl;
  String? _existingEpubPath;

  // Categories
  List<Map<String, dynamic>> _categories = [];

  bool get isEditing => widget.ebook != null;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadCategories();
  }

  void _initControllers() {
    final ebook = widget.ebook;

    _titleFaController = TextEditingController(text: ebook?['title_fa'] as String? ?? '');
    _titleEnController = TextEditingController(text: ebook?['title_en'] as String? ?? '');
    _subtitleFaController = TextEditingController(text: ebook?['subtitle_fa'] as String? ?? '');
    _descriptionFaController = TextEditingController(text: ebook?['description_fa'] as String? ?? '');
    _authorFaController = TextEditingController(text: ebook?['author_fa'] as String? ?? '');
    _authorEnController = TextEditingController(text: ebook?['author_en'] as String? ?? '');
    _translatorFaController = TextEditingController(text: ebook?['translator_fa'] as String? ?? '');
    _publisherFaController = TextEditingController(text: ebook?['publisher_fa'] as String? ?? '');
    _priceTomanController = TextEditingController(text: (ebook?['price_toman'] as int?)?.toString() ?? '0');
    _pageCountController = TextEditingController(text: (ebook?['page_count'] as int?)?.toString() ?? '0');
    _isbnController = TextEditingController(text: ebook?['isbn'] as String? ?? '');
    _publicationYearController = TextEditingController(text: (ebook?['publication_year'] as int?)?.toString() ?? '');

    _isFree = ebook?['is_free'] as bool? ?? false;
    _isFeatured = ebook?['is_featured'] as bool? ?? false;
    _status = ebook?['status'] as String? ?? 'draft';
    _categoryId = ebook?['category_id'] as int?;
    _existingCoverUrl = ebook?['cover_url'] as String?;
    _existingEpubPath = ebook?['epub_storage_path'] as String?;
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name_fa, name_en')
          .eq('is_active', true)
          .order('sort_order');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _titleFaController.dispose();
    _titleEnController.dispose();
    _subtitleFaController.dispose();
    _descriptionFaController.dispose();
    _authorFaController.dispose();
    _authorEnController.dispose();
    _translatorFaController.dispose();
    _publisherFaController.dispose();
    _priceTomanController.dispose();
    _pageCountController.dispose();
    _isbnController.dispose();
    _publicationYearController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _coverBytes = bytes;
        _coverFileName = image.name;
      });
    }
  }

  Future<void> _pickEpub() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _epubBytes = result.files.single.bytes!;
        _epubFileName = result.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required files for new ebooks
    if (!isEditing && _epubBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً فایل EPUB را انتخاب کنید'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('کاربر وارد نشده است');
      }

      String? coverUrl = _existingCoverUrl;
      String? coverStoragePath;
      String? epubStoragePath = _existingEpubPath;

      // Upload cover if new
      if (_coverBytes != null) {
        setState(() => _uploadProgress = 'آپلود تصویر جلد...');

        final ext = _coverFileName?.split('.').last.toLowerCase() ?? 'jpg';
        final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}';
        final coverPath = 'covers/$uniqueId.$ext';

        // Map file extension to proper MIME type
        String mimeType;
        switch (ext) {
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
          default:
            mimeType = 'image/jpeg'; // Default to jpeg
        }

        await supabase.storage.from('ebook-files').uploadBinary(
          coverPath,
          _coverBytes!,
          fileOptions: FileOptions(contentType: mimeType),
        );

        // Try public URL first, fall back to signed URL if bucket is private
        try {
          // Create a signed URL with 10 year expiry for covers (they need to be accessible)
          coverUrl = await supabase.storage
              .from('ebook-files')
              .createSignedUrl(coverPath, 60 * 60 * 24 * 365 * 10); // 10 years
        } catch (e) {
          // Fallback to public URL if signed URL fails
          coverUrl = supabase.storage.from('ebook-files').getPublicUrl(coverPath);
        }
        coverStoragePath = coverPath;
      }

      // Upload EPUB if new
      if (_epubBytes != null) {
        setState(() => _uploadProgress = 'آپلود فایل EPUB...');

        final epubUniqueId = '${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}';
        final epubPath = 'epubs/$epubUniqueId.epub';

        await supabase.storage.from('ebook-files').uploadBinary(
          epubPath,
          _epubBytes!,
          fileOptions: const FileOptions(contentType: 'application/epub+zip'),
        );

        epubStoragePath = epubPath;
      }

      setState(() => _uploadProgress = 'ذخیره اطلاعات...');

      final data = {
        'title_fa': _titleFaController.text.trim(),
        'title_en': _titleEnController.text.trim().isEmpty ? null : _titleEnController.text.trim(),
        'subtitle_fa': _subtitleFaController.text.trim().isEmpty ? null : _subtitleFaController.text.trim(),
        'description_fa': _descriptionFaController.text.trim().isEmpty ? null : _descriptionFaController.text.trim(),
        'author_fa': _authorFaController.text.trim().isEmpty ? null : _authorFaController.text.trim(),
        'author_en': _authorEnController.text.trim().isEmpty ? null : _authorEnController.text.trim(),
        'translator_fa': _translatorFaController.text.trim().isEmpty ? null : _translatorFaController.text.trim(),
        'publisher_fa': _publisherFaController.text.trim().isEmpty ? null : _publisherFaController.text.trim(),
        'price_toman': int.tryParse(_priceTomanController.text) ?? 0,
        'page_count': int.tryParse(_pageCountController.text) ?? 0,
        'isbn': _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
        'publication_year': int.tryParse(_publicationYearController.text),
        'is_free': _isFree,
        'is_featured': _isFeatured,
        'status': _status,
        'category_id': _categoryId,
      };

      if (coverUrl != null) {
        data['cover_url'] = coverUrl;
      }
      if (coverStoragePath != null) {
        data['cover_storage_path'] = coverStoragePath;
      }
      if (epubStoragePath != null) {
        data['epub_storage_path'] = epubStoragePath;
      }

      if (isEditing) {
        final ebookId = widget.ebook!['id'] as int;
        await supabase.from('ebooks').update(data).eq('id', ebookId);
      } else {
        data['uploader_id'] = userId;
        await supabase.from('ebooks').insert(data);
      }

      // Refresh the ebooks list
      ref.invalidate(adminEbooksProvider('all'));
      ref.invalidate(adminEbooksProvider('pending'));
      ref.invalidate(adminEbooksProvider('approved'));
      ref.invalidate(adminEbooksProvider('featured'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'ایبوک بروزرسانی شد' : 'ایبوک اضافه شد'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(isEditing ? 'ویرایش ایبوک' : 'افزودن ایبوک'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('ذخیره'),
                onPressed: _save,
              ),
          ],
        ),
        body: _isUploading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      _uploadProgress ?? 'در حال آپلود...',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Files section
                      _buildSectionTitle('فایل‌ها'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover image
                          Expanded(
                            child: _buildFileCard(
                              title: 'تصویر جلد',
                              icon: Icons.image,
                              fileName: _coverFileName,
                              hasExisting: _existingCoverUrl != null,
                              existingPreview: _existingCoverUrl != null
                                  ? Image.network(_existingCoverUrl!, height: 120, fit: BoxFit.cover)
                                  : null,
                              newPreview: _coverBytes != null
                                  ? Image.memory(_coverBytes!, height: 120, fit: BoxFit.cover)
                                  : null,
                              onPick: _pickCover,
                              onClear: () => setState(() {
                                _coverBytes = null;
                                _coverFileName = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // EPUB file
                          Expanded(
                            child: _buildFileCard(
                              title: 'فایل EPUB',
                              icon: Icons.book,
                              fileName: _epubFileName,
                              hasExisting: _existingEpubPath != null,
                              existingLabel: _existingEpubPath != null ? 'فایل موجود' : null,
                              onPick: _pickEpub,
                              onClear: () => setState(() {
                                _epubBytes = null;
                                _epubFileName = null;
                              }),
                              required: !isEditing,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Basic info section
                      _buildSectionTitle('اطلاعات اصلی'),
                      _buildTextField(
                        controller: _titleFaController,
                        label: 'عنوان فارسی *',
                        validator: (v) => v?.isEmpty == true ? 'عنوان فارسی الزامی است' : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _titleEnController,
                              label: 'عنوان انگلیسی',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _subtitleFaController,
                              label: 'زیرعنوان فارسی',
                            ),
                          ),
                        ],
                      ),
                      _buildTextField(
                        controller: _descriptionFaController,
                        label: 'توضیحات',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      // Author info section
                      _buildSectionTitle('نویسنده و ناشر'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _authorFaController,
                              label: 'نویسنده (فارسی)',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _authorEnController,
                              label: 'نویسنده (انگلیسی)',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _translatorFaController,
                              label: 'مترجم',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _publisherFaController,
                              label: 'ناشر',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Classification section
                      _buildSectionTitle('دسته‌بندی'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField<int>(
                              label: 'دسته‌بندی',
                              value: _categoryId,
                              items: _categories.map((c) => DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['name_fa'] as String),
                              )).toList(),
                              onChanged: (v) => setState(() => _categoryId = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownField<String>(
                              label: 'وضعیت',
                              value: _status,
                              items: const [
                                DropdownMenuItem(value: 'draft', child: Text('پیش‌نویس')),
                                DropdownMenuItem(value: 'submitted', child: Text('ارسال شده')),
                                DropdownMenuItem(value: 'under_review', child: Text('در حال بررسی')),
                                DropdownMenuItem(value: 'approved', child: Text('تأیید شده')),
                                DropdownMenuItem(value: 'rejected', child: Text('رد شده')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? 'draft'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pricing section
                      _buildSectionTitle('قیمت‌گذاری'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _priceTomanController,
                              label: 'قیمت (تومان)',
                              keyboardType: TextInputType.number,
                              enabled: !_isFree,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('رایگان'),
                              value: _isFree,
                              onChanged: (v) => setState(() => _isFree = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('ویژه'),
                              value: _isFeatured,
                              onChanged: (v) => setState(() => _isFeatured = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Technical info section
                      _buildSectionTitle('اطلاعات فنی'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _pageCountController,
                              label: 'تعداد صفحات',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _isbnController,
                              label: 'شابک (ISBN)',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _publicationYearController,
                              label: 'سال انتشار',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(isEditing ? Icons.save : Icons.upload),
                          label: Text(isEditing ? 'ذخیره تغییرات' : 'افزودن ایبوک'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isLoading ? null : _save,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: AppRadius.small),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.small,
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: AppRadius.small),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.small,
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard({
    required String title,
    required IconData icon,
    String? fileName,
    bool hasExisting = false,
    Widget? existingPreview,
    Widget? newPreview,
    String? existingLabel,
    required VoidCallback onPick,
    required VoidCallback onClear,
    bool required = false,
  }) {
    final hasNew = fileName != null;

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(
          color: required && !hasNew && !hasExisting ? AppColors.error : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (required)
                  const Text(' *', style: TextStyle(color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 16),

            // Preview
            if (newPreview != null)
              ClipRRect(
                borderRadius: AppRadius.small,
                child: newPreview,
              )
            else if (existingPreview != null)
              ClipRRect(
                borderRadius: AppRadius.small,
                child: existingPreview,
              )
            else if (existingLabel != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadius.small,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(existingLabel, style: const TextStyle(color: AppColors.success)),
                  ],
                ),
              ),

            if (hasNew) ...[
              const SizedBox(height: 8),
              Text(
                fileName,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(hasNew || hasExisting ? Icons.refresh : Icons.add),
                    label: Text(hasNew || hasExisting ? 'تغییر' : 'انتخاب'),
                    onPressed: onPick,
                  ),
                ),
                if (hasNew) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.error),
                    onPressed: onClear,
                    tooltip: 'حذف',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
