import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;
  Uint8List? _newAvatarBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', user.id as Object)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _displayNameController.text = (response?['display_name'] as String?) ?? (response?['full_name'] as String?) ?? '';
          _bioController.text = (response?['bio'] as String?) ?? '';
          _avatarUrl = response?['avatar_url'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('خطا در بارگذاری پروفایل');
      }
    }
  }

  Future<Uint8List?> _cropImage(String imagePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'برش تصویر',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: AppColors.textOnPrimary,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'برش تصویر',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (croppedFile != null) {
      return await File(croppedFile.path).readAsBytes();
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        final croppedBytes = await _cropImage(image.path);
        if (croppedBytes != null && mounted) {
          setState(() {
            _newAvatarBytes = croppedBytes;
          });
        }
      }
    } catch (e) {
      _showError('خطا در انتخاب تصویر');
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_newAvatarBytes == null) return _avatarUrl;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final fileName = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    await Supabase.instance.client.storage
        .from('avatars')
        .uploadBinary(
          fileName,
          _newAvatarBytes!,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final publicUrl = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(fileName);

    return publicUrl;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('کاربر وارد نشده است');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalAvatarUrl = _avatarUrl;
      String? newAvatarPath; // Track new avatar for cleanup if DB fails

      if (_newAvatarBytes != null) {
        finalAvatarUrl = await _uploadAvatar();
        // Track the path for potential cleanup
        if (finalAvatarUrl != null) {
          newAvatarPath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }

      final updateData = <String, dynamic>{
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (finalAvatarUrl != null) {
        updateData['avatar_url'] = finalAvatarUrl;
      }

      // Update profile - with orphan avatar cleanup on failure
      try {
        await Supabase.instance.client
            .from('profiles')
            .update(updateData)
            .eq('id', user.id as Object);
      } catch (dbError) {
        // DB update failed - clean up newly uploaded avatar if any
        if (newAvatarPath != null) {
          try {
            await Supabase.instance.client.storage.from('avatars').remove([newAvatarPath]);
          } catch (_) {}
        }
        rethrow;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پروفایل با موفقیت ذخیره شد'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showError('خطا در ذخیره پروفایل');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    ImageProvider? avatarImage;
    if (_newAvatarBytes != null) {
      avatarImage = MemoryImage(_newAvatarBytes!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_avatarUrl!);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('ویرایش پروفایل'),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text('ذخیره'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.surface,
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? const Icon(Icons.person, size: 60, color: AppColors.textTertiary)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 20, color: AppColors.textOnPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'برای تغییر تصویر ضربه بزنید',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _displayNameController,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'نام نمایشی',
                          hintText: 'نام خود را وارد کنید',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'نام نمایشی الزامی است';
                          }
                          if (value.trim().length < 2) {
                            return 'نام باید حداقل ۲ حرف باشد';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bioController,
                        textDirection: TextDirection.rtl,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: 'درباره من',
                          hintText: 'چند کلمه درباره خودتان بنویسید...',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 50),
                            child: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: user?.email ?? '',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'ایمیل',
                          filled: true,
                          fillColor: AppColors.surface.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                          suffixIcon: const Icon(Icons.lock_outline, size: 18),
                        ),
                        style: const TextStyle(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ایمیل قابل تغییر نیست',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}