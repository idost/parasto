import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/config/app_config.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/creator_service.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/widgets/admin/content_card.dart';
import 'package:myna/widgets/admin/status_badge.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';

/// Admin screen for managing creator profiles.
///
/// Features:
/// - List all creators with search
/// - Create new creators
/// - Edit existing creators
class AdminCreatorsScreen extends StatefulWidget {
  final bool embedded;

  const AdminCreatorsScreen({super.key, this.embedded = false});

  @override
  State<AdminCreatorsScreen> createState() => _AdminCreatorsScreenState();
}

class _AdminCreatorsScreenState extends State<AdminCreatorsScreen> {
  final CreatorService _creatorService = CreatorService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _creators = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _creators = await _creatorService.searchCreators(query);
      } else {
        // Load all creators (search with empty returns all up to 50)
        _creators = await _creatorService.searchCreators('');
      }
      setState(() => _isLoading = false);
    } catch (e, st) {
      AppLogger.e('AdminCreatorsScreen: Error loading creators', error: e, stackTrace: st);
      setState(() {
        _error = 'خطا در بارگذاری لیست سازندگان';
        _isLoading = false;
      });
    }
  }

  void _showCreateCreatorDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _CreatorFormDialog(
        onSave: (creator) async {
          final result = await _creatorService.createCreator(
            displayName: creator['display_name'] as String,
            displayNameLatin: creator['display_name_latin'] as String?,
            creatorType: creator['creator_type'] as String,
            bio: creator['bio'] as String?,
            avatarUrl: creator['avatar_url'] as String?,
            collectionLabel: creator['collection_label'] as String?,
          );
          if (result != null) {
            _loadCreators();
            return true;
          }
          return false;
        },
      ),
    );
  }

  void _showEditCreatorDialog(Map<String, dynamic> creator) {
    final creatorId = creator['id'] as String?;
    if (creatorId == null) {
      AppLogger.e('AdminCreatorsScreen: Cannot edit creator with null ID');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => _CreatorFormDialog(
        initialData: creator,
        onSave: (updatedData) async {
          final result = await _creatorService.updateCreator(
            creatorId: creatorId,
            displayName: updatedData['display_name'] as String,
            displayNameLatin: updatedData['display_name_latin'] as String?,
            creatorType: updatedData['creator_type'] as String,
            bio: updatedData['bio'] as String?,
            avatarUrl: updatedData['avatar_url'] as String?,
            collectionLabel: updatedData['collection_label'] as String?,
          );
          if (result != null) {
            _loadCreators();
            return true;
          }
          return false;
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> creator) {
    final creatorId = creator['id'] as String?;
    final displayName = (creator['display_name'] as String?) ?? 'سازنده';

    if (creatorId == null) {
      AppLogger.e('AdminCreatorsScreen: Cannot delete creator with null ID');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'حذف سازنده',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'آیا از حذف "$displayName" مطمئن هستید؟',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCreator(creatorId, displayName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCreator(String creatorId, String displayName) async {
    final result = await _creatorService.deleteCreator(creatorId);

    if (!mounted) return;

    switch (result) {
      case DeleteResult.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$displayName" با موفقیت حذف شد'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadCreators();
        break;
      case DeleteResult.hasWorks:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('امکان حذف این سازنده وجود ندارد، چون به کتاب‌ها یا آثار موسیقی لینک شده است.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 5),
          ),
        );
        break;
      case DeleteResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در حذف سازنده'),
            backgroundColor: AppColors.error,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.embedded ? null : AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            'مدیریت سازندگان',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateCreatorDialog,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('سازنده جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'جستجوی سازنده...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadCreators();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _loadCreators(),
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingState(message: 'در حال بارگذاری سازندگان...');
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadCreators,
      );
    }

    if (_creators.isEmpty) {
      return EmptyState(
        icon: Icons.person_off_rounded,
        message: 'سازنده‌ای یافت نشد',
        subtitle: 'برای افزودن سازنده جدید دکمه زیر را بزنید',
        action: ElevatedButton.icon(
          onPressed: _showCreateCreatorDialog,
          icon: const Icon(Icons.add),
          label: const Text('افزودن سازنده جدید'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCreators,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _creators.length,
        itemBuilder: (context, index) {
          final creator = _creators[index];
          return _CreatorListItem(
            creator: creator,
            onTap: () => _showEditCreatorDialog(creator),
            onDelete: () => _showDeleteConfirmDialog(creator),
          );
        },
      ),
    );
  }
}

/// List item widget for a creator using modern ContentCard component
class _CreatorListItem extends StatelessWidget {
  final Map<String, dynamic> creator;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CreatorListItem({
    required this.creator,
    required this.onTap,
    required this.onDelete,
  });

  /// Get color for creator type badge
  Color _getTypeColor(String? type) {
    return switch (type) {
      'narrator' => AppColors.primary,
      'author' => AppColors.success,
      'translator' => AppColors.info,
      'artist' => AppColors.secondary,
      'singer' => AppColors.warning,
      'composer' => Colors.purple,
      'lyricist' => Colors.teal,
      'publisher' => Colors.indigo,
      'label' => Colors.brown,
      _ => AppColors.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (creator['display_name'] as String?) ?? '';
    final displayNameLatin = creator['display_name_latin'] as String?;
    final creatorType = creator['creator_type'] as String?;
    final typeLabel = CreatorService.getCreatorTypeLabel(creatorType);
    final avatarUrl = creator['avatar_url'] as String?;
    final typeColor = _getTypeColor(creatorType);

    return ContentCard(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: typeColor.withValues(alpha: 0.1),
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0] : '?',
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
      ),
      subtitle: displayNameLatin != null && displayNameLatin.isNotEmpty
          ? Text(
              displayNameLatin,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              textDirection: TextDirection.ltr,
            )
          : null,
      badges: [
        StatusBadge(
          label: typeLabel,
          color: typeColor,
        ),
      ],
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: AppColors.error,
          onPressed: onDelete,
          tooltip: 'حذف',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

/// Dialog for creating/editing a creator
class _CreatorFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  const _CreatorFormDialog({this.initialData, required this.onSave});

  @override
  State<_CreatorFormDialog> createState() => _CreatorFormDialogState();
}

class _CreatorFormDialogState extends State<_CreatorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _displayNameLatinController = TextEditingController();
  final _bioController = TextEditingController();
  final _collectionLabelController = TextEditingController();

  String _selectedType = 'narrator';
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _avatarUrl;
  Uint8List? _newAvatarBytes;

  // Allowed extensions and max size
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const _maxSizeBytes = 5 * 1024 * 1024; // 5 MB

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _displayNameController.text = (widget.initialData!['display_name'] as String?) ?? '';
      _displayNameLatinController.text = (widget.initialData!['display_name_latin'] as String?) ?? '';
      _bioController.text = (widget.initialData!['bio'] as String?) ?? '';
      _collectionLabelController.text = (widget.initialData!['collection_label'] as String?) ?? '';
      _selectedType = (widget.initialData!['creator_type'] as String?) ?? 'narrator';
      _avatarUrl = widget.initialData!['avatar_url'] as String?;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _displayNameLatinController.dispose();
    _bioController.dispose();
    _collectionLabelController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      // Validate extension
      final ext = image.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فرمت فایل مجاز نیست. فقط jpg, png, webp'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final bytes = await image.readAsBytes();

      // Validate size
      if (bytes.length > _maxSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حجم فایل بیش از ۵ مگابایت است'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploadingImage = true;
        _newAvatarBytes = bytes;
      });

      // Upload to Supabase storage
      final creatorId = widget.initialData?['id'] as String? ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'creators/$creatorId/$timestamp.$ext';

      // Map extension to proper MIME type (jpg -> jpeg)
      final mimeType = switch (ext) {
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg', // fallback
      };

      final bucket = AppConfig.profileImagesBucket;
      await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);

      setState(() {
        _avatarUrl = publicUrl;
        _isUploadingImage = false;
      });

      AppLogger.d('AdminCreatorsScreen: Avatar uploaded to $publicUrl');
    } catch (e, st) {
      AppLogger.e('AdminCreatorsScreen: Error uploading avatar', error: e, stackTrace: st);
      setState(() => _isUploadingImage = false);
      if (mounted) {
        // Show detailed error in debug mode, generic message in release
        final errorText = e.toString();
        final shortError = errorText.length > 80 ? '${errorText.substring(0, 80)}...' : errorText;
        final message = kDebugMode
            ? 'خطا در آپلود: $shortError'
            : 'خطا در آپلود تصویر';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            duration: kDebugMode ? const Duration(seconds: 8) : const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Track avatar path for potential cleanup if DB save fails
    String? uploadedAvatarPath;
    if (_newAvatarBytes != null && _avatarUrl != null) {
      // Extract path from URL for potential cleanup
      try {
        final uri = Uri.parse(_avatarUrl!);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf('profile-images');
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          uploadedAvatarPath = pathSegments.sublist(bucketIndex + 1).join('/');
        }
      } catch (_) {}
    }

    final result = await widget.onSave({
      'display_name': _displayNameController.text.trim(),
      'display_name_latin': _displayNameLatinController.text.trim().isNotEmpty
          ? _displayNameLatinController.text.trim()
          : null,
      'creator_type': _selectedType,
      'bio': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      'collection_label': _collectionLabelController.text.trim().isNotEmpty
          ? _collectionLabelController.text.trim()
          : null,
      'avatar_url': _avatarUrl,
    });

    setState(() => _isSaving = false);

    if (result && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سازنده با موفقیت ذخیره شد'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      // DB save failed - clean up newly uploaded avatar if any
      if (uploadedAvatarPath != null) {
        AppLogger.w('Creator DB save failed, cleaning up uploaded avatar: $uploadedAvatarPath');
        try {
          await Supabase.instance.client.storage.from(AppConfig.profileImagesBucket).remove([uploadedAvatarPath]);
        } catch (cleanupError) {
          AppLogger.e('Failed to cleanup orphan avatar: $uploadedAvatarPath', error: cleanupError);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در ذخیره سازنده'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine avatar image to display
    ImageProvider? avatarImage;
    if (_newAvatarBytes != null) {
      avatarImage = MemoryImage(_newAvatarBytes!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_avatarUrl!);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.initialData != null ? 'ویرایش سازنده' : 'سازنده جدید',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar picker
                GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndUploadImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(Icons.person, size: 50, color: AppColors.textTertiary)
                            : null,
                      ),
                      if (_isUploadingImage)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  avatarImage == null ? 'انتخاب عکس' : 'تغییر عکس',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Display name (Persian)
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام (فارسی) *',
                    hintText: 'مثال: محمدرضا شجریان',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'نام سازنده الزامی است';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Display name (Latin)
                TextFormField(
                  controller: _displayNameLatinController,
                  decoration: const InputDecoration(
                    labelText: 'نام (انگلیسی)',
                    hintText: 'مثال: Mohammadreza Shajarian',
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 16),

                // Creator type dropdown
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'نوع سازنده'),
                  items: CreatorService.creatorTypeLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'بیوگرافی',
                    hintText: 'توضیحات کوتاه درباره سازنده...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Collection Label
                TextFormField(
                  controller: _collectionLabelController,
                  decoration: const InputDecoration(
                    labelText: 'برچسب مجموعه (اختیاری)',
                    hintText: 'مثال: از گنجهء استاد شجریان',
                    helperText: 'متن زیر نام هنرمند نمایش داده می‌شود',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Save button at bottom of form (more accessible than dialog actions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('انصراف'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('ذخیره'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
