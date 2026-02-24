import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  String? _avatarUrl;
  Uint8List? _newAvatarBytes;
  bool _showPasswordSection = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
          .eq('id', user.id)
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
          toolbarWidgetColor: Colors.white,
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
          setState(() => _newAvatarBytes = croppedBytes);
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
        .uploadBinary(fileName, _newAvatarBytes!, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));

    return Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      String? finalAvatarUrl = _avatarUrl;
      String? newAvatarPath; // Track new avatar for cleanup if DB fails

      if (_newAvatarBytes != null) {
        finalAvatarUrl = await _uploadAvatar();
        // Extract path from URL for potential cleanup
        if (finalAvatarUrl != null) {
          newAvatarPath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }

      // Update profile - with orphan avatar cleanup on failure
      try {
        await Supabase.instance.client.from('profiles').update({
          'display_name': _displayNameController.text.trim(),
          'bio': _bioController.text.trim(),
          if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
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
        _showSuccess('پروفایل ذخیره شد');
        setState(() => _avatarUrl = finalAvatarUrl);
      }
    } catch (e) {
      _showError('خطا در ذخیره پروفایل');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('رمز عبور جدید و تکرار آن یکسان نیست');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showError('رمز عبور باید حداقل ۶ کاراکتر باشد');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        _showSuccess('رمز عبور تغییر کرد');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordSection = false);
      }
    } catch (e) {
      _showError('خطا در تغییر رمز عبور: $e');
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
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
          title: const Text('پروفایل مدیر'),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: AppColors.surface,
                                backgroundImage: avatarImage,
                                child: avatarImage == null ? const Icon(Icons.person, size: 60, color: AppColors.textTertiary) : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(child: Text('برای تغییر تصویر ضربه بزنید', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))),
                      const SizedBox(height: 32),

                      // Display Name
                      TextFormField(
                        controller: _displayNameController,
                        decoration: InputDecoration(
                          labelText: 'نام نمایشی',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'نام الزامی است' : null,
                      ),
                      const SizedBox(height: 16),

                      // Bio
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: 'درباره من',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email (read-only)
                      TextFormField(
                        initialValue: user?.email ?? '',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'ایمیل',
                          filled: true,
                          fillColor: AppColors.surface.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.email_outlined),
                          suffixIcon: const Icon(Icons.lock_outline, size: 18),
                        ),
                        style: const TextStyle(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 32),

                      // Password Section
                      Card(
                        color: AppColors.surface,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lock, color: AppColors.primary),
                              title: const Text('تغییر رمز عبور', style: TextStyle(color: AppColors.textPrimary)),
                              trailing: Icon(_showPasswordSection ? Icons.expand_less : Icons.expand_more, color: AppColors.textTertiary),
                              onTap: () => setState(() => _showPasswordSection = !_showPasswordSection),
                            ),
                            if (_showPasswordSection) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _newPasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'رمز عبور جدید',
                                        filled: true,
                                        fillColor: AppColors.background,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        prefixIcon: const Icon(Icons.lock_outline),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'تکرار رمز عبور جدید',
                                        filled: true,
                                        fillColor: AppColors.background,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        prefixIcon: const Icon(Icons.lock_outline),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isChangingPassword ? null : _changePassword,
                                        child: _isChangingPassword
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('تغییر رمز عبور'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}