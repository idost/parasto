import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/config/env.dart';

class AdminBannerFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? banner;

  const AdminBannerFormScreen({super.key, this.banner});

  @override
  ConsumerState<AdminBannerFormScreen> createState() => _AdminBannerFormScreenState();
}

class _AdminBannerFormScreenState extends ConsumerState<AdminBannerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _targetIdController = TextEditingController();
  final _sortOrderController = TextEditingController();

  String _targetType = 'audiobook';
  bool _isActive = true;
  bool _isLoading = false;

  // For image upload
  Uint8List? _newImageBytes;
  bool _isUploadingImage = false;

  // For audiobook search
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedAudiobook;

  // For shelf selection
  List<Map<String, dynamic>> _shelves = [];

  bool get _isEditing => widget.banner != null;

  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    if (banner != null) {
      _titleController.text = (banner['title_fa'] as String?) ?? '';
      _subtitleController.text = (banner['subtitle_fa'] as String?) ?? '';
      _imageUrlController.text = (banner['image_url'] as String?) ?? '';
      _targetType = (banner['target_type'] as String?) ?? 'audiobook';
      _targetIdController.text = (banner['target_id'] ?? '').toString();
      _sortOrderController.text = (banner['sort_order'] ?? 0).toString();
      _isActive = banner['is_active'] == true;
    } else {
      _sortOrderController.text = '0';
    }
    _loadShelves();
  }

  Future<void> _loadShelves() async {
    try {
      final response = await Supabase.instance.client
          .from('promo_shelves')
          .select('id, title_fa')
          .order('sort_order');
      setState(() {
        _shelves = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() => _newImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در انتخاب تصویر'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<String?> _uploadBannerImage() async {
    if (_newImageBytes == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final fileName = 'banners/banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from(Env.coversBucket)
          .uploadBinary(fileName, _newImageBytes!, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));

      return Supabase.instance.client.storage.from(Env.coversBucket).getPublicUrl(fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آپلود تصویر: $e'), backgroundColor: AppColors.error),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _searchAudiobooks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Search for audiobooks to link to banner - show more results
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('id, title_fa, cover_url')
          .or('title_fa.ilike.%$query%,title_en.ilike.%$query%')
          .limit(30);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageUrlController.dispose();
    _targetIdController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate image: either URL or uploaded image required
    if (_imageUrlController.text.trim().isEmpty && _newImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('آدرس تصویر یا آپلود تصویر الزامی است'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload image if selected
      String? imageUrl = _imageUrlController.text.trim();
      String? newImagePath; // Track new image for cleanup if DB fails

      if (_newImageBytes != null) {
        final uploadedUrl = await _uploadBannerImage();
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
          // Extract path for potential cleanup
          newImagePath = 'banners/banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else {
          // Upload failed
          setState(() => _isLoading = false);
          return;
        }
      }

      final data = {
        'title_fa': _titleController.text.trim(),
        'subtitle_fa': _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
        'image_url': imageUrl,
        'target_type': _targetType,
        'target_id': int.tryParse(_targetIdController.text) ?? 0,
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'is_active': _isActive,
      };

      // Save to DB - with orphan image cleanup on failure
      try {
        final banner = widget.banner;
        if (banner != null) {
          await Supabase.instance.client
              .from('promo_banners')
              .update(data)
              .eq('id', banner['id'] as Object);
        } else {
          await Supabase.instance.client.from('promo_banners').insert(data);
        }
      } catch (dbError) {
        // DB operation failed - clean up newly uploaded image if any
        if (newImagePath != null) {
          try {
            await Supabase.instance.client.storage.from(Env.coversBucket).remove([newImagePath]);
          } catch (_) {}
        }
        rethrow;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'بنر بروزرسانی شد' : 'بنر ایجاد شد'),
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
          title: Text(_isEditing ? 'ویرایش بنر' : 'افزودن بنر'),
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
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان بنر *',
                          hintText: 'مثال: تخفیف ویژه زمستان',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'عنوان الزامی است' : null,
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      TextFormField(
                        controller: _subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'زیرعنوان (اختیاری)',
                          hintText: 'مثال: تا ۵۰٪ تخفیف',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Image Section
                      const Text('تصویر بنر *', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),

                      // Image preview/upload area
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickImage,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                          ),
                          child: _isUploadingImage
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: AppColors.primary),
                                      SizedBox(height: 12),
                                      Text('در حال آپلود...', style: TextStyle(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : _newImageBytes != null
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.memory(_newImageBytes!, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white),
                                            style: IconButton.styleFrom(backgroundColor: AppColors.error),
                                            onPressed: () => setState(() => _newImageBytes = null),
                                          ),
                                        ),
                                        const Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Chip(
                                            label: Text('تصویر جدید', style: TextStyle(fontSize: 11)),
                                            backgroundColor: AppColors.success,
                                            labelStyle: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    )
                                  : _imageUrlController.text.isNotEmpty
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                _imageUrlController.text,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: Icon(Icons.broken_image, color: AppColors.textTertiary, size: 48),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 8,
                                              left: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'برای انتخاب تصویر جدید ضربه بزنید',
                                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.textTertiary),
                                            SizedBox(height: 12),
                                            Text('برای آپلود تصویر ضربه بزنید', style: TextStyle(color: AppColors.textSecondary)),
                                            SizedBox(height: 4),
                                            Text('پیشنهاد: 1920×1080 پیکسل', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                          ],
                                        ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Manual URL input (alternative)
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'یا آدرس تصویر را وارد کنید',
                          hintText: 'https://example.com/banner.jpg',
                          prefixIcon: Icon(Icons.link),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Target Type
                      const Text('نوع هدف', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _targetTypeChip('audiobook', 'کتاب', Icons.book),
                          const SizedBox(width: 8),
                          _targetTypeChip('shelf', 'قفسه', Icons.shelves),
                          const SizedBox(width: 8),
                          _targetTypeChip('category', 'دسته‌بندی', Icons.category),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Target Selection
                      if (_targetType == 'audiobook') ...[
                        const Text('انتخاب کتاب', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'جستجوی کتاب...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: _searchAudiobooks,
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final book = _searchResults[index];
                                return ListTile(
                                  leading: book['cover_url'] != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.network(book['cover_url'] as String, width: 40, height: 60, fit: BoxFit.cover), // 2:3 ratio
                                        )
                                      : const Icon(Icons.book),
                                  title: Text(
                                    (book['title_fa'] as String?) ?? '',
                                    style: const TextStyle(color: AppColors.textPrimary),
                                  ),
                                  subtitle: Text('ID: ${book['id']}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                  onTap: () {
                                    setState(() {
                                      _selectedAudiobook = book;
                                      _targetIdController.text = book['id'].toString();
                                      _searchResults = [];
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        if (_selectedAudiobook != null || _targetIdController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Card(
                              color: AppColors.surface,
                              child: ListTile(
                                leading: _selectedAudiobook?['cover_url'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(_selectedAudiobook!['cover_url'] as String, width: 40, height: 60, fit: BoxFit.cover), // 2:3 ratio
                                      )
                                    : const Icon(Icons.book, color: AppColors.primary),
                                title: Text(
                                  _selectedAudiobook != null
                                      ? (_selectedAudiobook!['title_fa'] as String?) ?? 'کتاب انتخاب شده'
                                      : 'کتاب با ID: ${_targetIdController.text}',
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.error),
                                  onPressed: () {
                                    setState(() {
                                      _selectedAudiobook = null;
                                      _targetIdController.clear();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                      ] else if (_targetType == 'shelf') ...[
                        const Text('انتخاب قفسه', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: int.tryParse(_targetIdController.text),
                          decoration: const InputDecoration(hintText: 'قفسه را انتخاب کنید'),
                          dropdownColor: AppColors.surface,
                          items: _shelves
                              .map((s) => DropdownMenuItem<int>(
                                    value: s['id'] as int,
                                    child: Text((s['title_fa'] as String?) ?? '', style: const TextStyle(color: AppColors.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _targetIdController.text = v.toString());
                            }
                          },
                          validator: (v) => v == null ? 'قفسه را انتخاب کنید' : null,
                        ),
                      ] else ...[
                        // Category - manual ID input for now
                        TextFormField(
                          controller: _targetIdController,
                          decoration: const InputDecoration(
                            labelText: 'شناسه دسته‌بندی',
                            hintText: 'مثال: 1',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'شناسه الزامی است' : null,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Sort Order
                      TextFormField(
                        controller: _sortOrderController,
                        decoration: const InputDecoration(
                          labelText: 'ترتیب نمایش',
                          hintText: '0',
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
                            _isActive ? 'بنر در صفحه اصلی نمایش داده می‌شود' : 'بنر مخفی است',
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
                          child: Text(_isEditing ? 'بروزرسانی' : 'ایجاد بنر'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _targetTypeChip(String value, String label, IconData icon) {
    final isSelected = _targetType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _targetType = value;
          _targetIdController.clear();
          _selectedAudiobook = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.surfaceLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
