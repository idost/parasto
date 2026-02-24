import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/config/env.dart';
import 'package:myna/utils/formatters.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/audio_validator.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Model for a chapter to be uploaded
/// Uses lazy loading to avoid memory issues with large batch uploads
class ChapterToUpload {
  String titleFa;
  String? titleEn;
  bool isPreview;
  final String fileName;
  final int fileSize;

  // Lazy-loaded bytes - only loaded when actually uploading
  Uint8List? _bytes;
  final PlatformFile? _platformFile; // Store reference to load bytes later

  bool isUploading;
  bool isUploaded;
  String? error;
  double uploadProgress;

  ChapterToUpload({
    required this.titleFa,
    this.titleEn,
    this.isPreview = false,
    required this.fileName,
    required this.fileSize,
    Uint8List? bytes,
    PlatformFile? platformFile,
    this.isUploading = false,
    this.isUploaded = false,
    this.error,
    this.uploadProgress = 0,
  }) : _bytes = bytes,
       _platformFile = platformFile;

  /// Get bytes - loads from platformFile if not already loaded
  Future<Uint8List> getBytes() async {
    if (_bytes != null) return _bytes!;

    // For web: FilePicker provides bytes directly
    if (_platformFile?.bytes != null) {
      _bytes = _platformFile!.bytes;
      return _bytes!;
    }

    throw Exception('No bytes available for file: $fileName');
  }

  /// Release bytes from memory after upload to free RAM
  void releaseBytes() {
    _bytes = null;
  }
}

class AdminBulkChapterUploadScreen extends ConsumerStatefulWidget {
  final int audiobookId;
  final String audiobookTitle;
  final String narratorId;

  const AdminBulkChapterUploadScreen({
    super.key,
    required this.audiobookId,
    required this.audiobookTitle,
    required this.narratorId,
  });

  @override
  ConsumerState<AdminBulkChapterUploadScreen> createState() => _AdminBulkChapterUploadScreenState();
}

class _AdminBulkChapterUploadScreenState extends ConsumerState<AdminBulkChapterUploadScreen> {
  final List<ChapterToUpload> _chapters = [];
  bool _isSelectingFiles = false;
  bool _isUploading = false;
  String? _error;
  int _uploadedCount = 0;
  int _existingChapterCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExistingChapterCount();
  }

  Future<void> _loadExistingChapterCount() async {
    try {
      final response = await Supabase.instance.client
          .from('chapters')
          .select('id')
          .eq('audiobook_id', widget.audiobookId);
      setState(() {
        _existingChapterCount = (response as List).length;
      });
    } catch (e) {
      AppLogger.e('Error loading chapter count', error: e);
    }
  }

  Future<void> _selectFiles() async {
    setState(() {
      _isSelectingFiles = true;
      _error = null;
    });

    try {
      // withData: true loads files into memory, but we use lazy loading in ChapterToUpload
      // to release memory after each upload (prevents crashes with large batches)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AudioValidator.getAllowedExtensions(),
        allowMultiple: true,
        withData: true, // Needed for web, but we release memory after each upload
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isSelectingFiles = false);
        return;
      }

      final newChapters = <ChapterToUpload>[];
      final errors = <String>[];

      for (final file in result.files) {
        if (file.bytes == null) {
          errors.add('${file.name}: خطا در خواندن فایل');
          continue;
        }

        // Validate audio file
        final validation = AudioValidator.validate(
          fileName: file.name,
          fileSizeBytes: file.size,
          mimeType: file.extension,
        );

        if (!validation.isValid) {
          errors.add('${file.name}: ${validation.errorMessage}');
          continue;
        }

        // Generate title from file name
        final titleFa = _generateTitleFromFileName(file.name, _chapters.length + newChapters.length + 1);

        newChapters.add(ChapterToUpload(
          titleFa: titleFa,
          fileName: file.name,
          fileSize: file.size,
          platformFile: file, // Store file reference for lazy loading
        ));
      }

      if (errors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${FarsiUtils.toFarsiDigits(errors.length)} فایل رد شد. بررسی کنید.'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _chapters.addAll(newChapters);
        _isSelectingFiles = false;
      });
    } catch (e) {
      setState(() {
        _error = 'خطا در انتخاب فایل‌ها: $e';
        _isSelectingFiles = false;
      });
    }
  }

  String _generateTitleFromFileName(String fileName, int index) {
    // Remove extension
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    // Clean up common patterns
    final cleaned = nameWithoutExt
        .replaceAll(RegExp(r'[-_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return 'فصل ${FarsiUtils.toFarsiDigits(index)}';
    }
    return cleaned;
  }

  void _removeChapter(int index) {
    setState(() {
      _chapters.removeAt(index);
    });
  }

  void _reorderChapters(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _chapters.removeAt(oldIndex);
      _chapters.insert(newIndex, item);
    });
  }

  Future<void> _uploadAllChapters() async {
    if (_chapters.isEmpty) {
      setState(() => _error = 'حداقل یک فایل انتخاب کنید');
      return;
    }

    // Check for empty titles
    for (int i = 0; i < _chapters.length; i++) {
      if (_chapters[i].titleFa.trim().isEmpty) {
        setState(() => _error = 'عنوان فصل ${FarsiUtils.toFarsiDigits(i + 1)} خالی است');
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _error = null;
      _uploadedCount = 0;
    });

    try {
      for (int i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];

        if (chapter.isUploaded) continue;

        // Update UI - mark as uploading (reduced setState calls for performance)
        if (mounted) {
          setState(() {
            chapter.isUploading = true;
            chapter.uploadProgress = 0.0;
          });
        }

        try {
          // Upload audio file
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = chapter.fileName.split('.').last.toLowerCase();
          final path = '${widget.narratorId}/${widget.audiobookId}/$timestamp.$extension';

          // Lazy load bytes only when uploading (memory optimization for large batches)
          final bytes = await chapter.getBytes();

          await Supabase.instance.client.storage
              .from(Env.audioBucket)
              .uploadBinary(path, bytes);

          // Release bytes from memory after upload (critical for large batches like 93 chapters)
          chapter.releaseBytes();

          // Create chapter record - with orphan file cleanup on failure
          final chapterIndex = _existingChapterCount + _uploadedCount + 1;

          try {
            await Supabase.instance.client.from('chapters').insert({
              'audiobook_id': widget.audiobookId,
              'title_fa': chapter.titleFa.trim(),
              'title_en': chapter.titleEn?.trim().isEmpty == true ? null : chapter.titleEn?.trim(),
              'chapter_index': chapterIndex,
              'audio_storage_path': path,
              'duration_seconds': 0,
              'file_size_bytes': chapter.fileSize,
              'audio_format': extension,
              'is_preview': chapter.isPreview,
            });
          } catch (dbError) {
            // DB insert failed - clean up orphan file from storage
            AppLogger.w('Admin bulk chapter DB insert failed, cleaning up uploaded file: $path');
            try {
              await Supabase.instance.client.storage.from(Env.audioBucket).remove([path]);
            } catch (cleanupError) {
              AppLogger.e('Failed to cleanup orphan audio file: $path', error: cleanupError);
            }
            rethrow;
          }

          // Update UI - mark as completed
          if (mounted) {
            setState(() {
              chapter.uploadProgress = 1.0;
              chapter.isUploading = false;
              chapter.isUploaded = true;
              _uploadedCount++;
            });
          }
        } catch (e) {
          AppLogger.e('Chapter upload error', error: e);
          if (mounted) {
            setState(() {
              chapter.isUploading = false;
              chapter.error = AudioValidator.getUploadErrorMessage(e);
            });
          }
        }
      }

      // Update audiobook chapter count
      if (_uploadedCount > 0) {
        await Supabase.instance.client
            .from('audiobooks')
            .update({'chapter_count': _existingChapterCount + _uploadedCount})
            .eq('id', widget.audiobookId);
      }

      if (mounted) {
        final allUploaded = _chapters.every((c) => c.isUploaded);
        if (allUploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${FarsiUtils.toFarsiDigits(_uploadedCount)} فصل با موفقیت آپلود شد'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final failedCount = _chapters.where((c) => c.error != null).length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${FarsiUtils.toFarsiDigits(_uploadedCount)} فصل آپلود شد، ${FarsiUtils.toFarsiDigits(failedCount)} خطا داشت'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('Bulk upload error', error: e);
      setState(() => _error = AudioValidator.getUploadErrorMessage(e));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showEditChapterDialog(int index) {
    final chapter = _chapters[index];
    final titleFaController = TextEditingController(text: chapter.titleFa);
    final titleEnController = TextEditingController(text: chapter.titleEn ?? '');
    bool isPreview = chapter.isPreview;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('ویرایش فصل ${FarsiUtils.toFarsiDigits(index + 1)}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.audio_file, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chapter.fileName,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatFileSize(chapter.fileSize),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Persian title
                  TextField(
                    controller: titleFaController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان فصل (فارسی) *',
                      hintText: 'مثال: فصل اول - آغاز داستان',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // English title
                  TextField(
                    controller: titleEnController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان انگلیسی (اختیاری)',
                      hintText: 'Chapter 1 - The Beginning',
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 16),

                  // Is preview toggle
                  Row(
                    children: [
                      Checkbox(
                        value: isPreview,
                        onChanged: (value) {
                          setDialogState(() => isPreview = value ?? false);
                        },
                        activeColor: AppColors.primary,
                      ),
                      const Text('نمونه رایگان'),
                    ],
                  ),
                  const Text(
                    'فصل‌های نمونه برای همه کاربران قابل پخش است',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _chapters[index].titleFa = titleFaController.text;
                    _chapters[index].titleEn = titleEnController.text.isEmpty ? null : titleEnController.text;
                    _chapters[index].isPreview = isPreview;
                  });
                  Navigator.pop(context);
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allUploaded = _chapters.isNotEmpty && _chapters.every((c) => c.isUploaded);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'آپلود دسته‌ای فصل‌ها',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              Text(
                widget.audiobookTitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (allUploaded)
              TextButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('تمام'),
              ),
          ],
        ),
        body: Column(
          children: [
            // Info header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                children: [
                  const Icon(
                    Icons.library_music,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${FarsiUtils.toFarsiDigits(_chapters.length)} فایل انتخاب شده',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_uploadedCount > 0)
                          Text(
                            '${FarsiUtils.toFarsiDigits(_uploadedCount)} فصل آپلود شده',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_isUploading)
                    OutlinedButton.icon(
                      onPressed: _isSelectingFiles ? null : _selectFiles,
                      icon: _isSelectingFiles
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('افزودن'),
                    ),
                ],
              ),
            ),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),

            // Chapters list
            Expanded(
              child: _chapters.isEmpty
                  ? _buildEmptyState()
                  : _buildChaptersList(),
            ),

            // Upload button
            if (_chapters.isNotEmpty && !allUploaded)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadAllChapters,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isUploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('در حال آپلود... (${FarsiUtils.toFarsiDigits(_uploadedCount)}/${FarsiUtils.toFarsiDigits(_chapters.length)})'),
                            ],
                          )
                        : Text(
                            'آپلود ${FarsiUtils.toFarsiDigits(_chapters.length)} فصل',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'فایل‌های صوتی را انتخاب کنید',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'می‌توانید چندین فایل را همزمان انتخاب کنید',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSelectingFiles ? null : _selectFiles,
              icon: _isSelectingFiles
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open),
              label: const Text('انتخاب فایل‌ها'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            // Audio format info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Text(
                    'فرمت‌های مجاز',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MP3 یا M4A • حداکثر ${AudioValidator.kServerMaxFileSizeMB} مگابایت • حداکثر ۲۴۰ دقیقه',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _chapters.length,
      onReorder: _isUploading ? (_, __) {} : _reorderChapters,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        return _buildChapterItem(chapter, index);
      },
    );
  }

  Widget _buildChapterItem(ChapterToUpload chapter, int index) {
    Color statusColor;
    IconData statusIcon;

    if (chapter.isUploaded) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    } else if (chapter.error != null) {
      statusColor = AppColors.error;
      statusIcon = Icons.error;
    } else if (chapter.isUploading) {
      statusColor = AppColors.primary;
      statusIcon = Icons.upload;
    } else {
      statusColor = AppColors.textTertiary;
      statusIcon = Icons.circle_outlined;
    }

    return Card(
      key: ValueKey('chapter_$index'),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: chapter.isPreview
                    ? AppColors.success.withValues(alpha: 0.2)
                    : statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: chapter.isUploading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                    : Icon(statusIcon, color: statusColor, size: 20),
              ),
            ),
            title: Text(
              chapter.titleFa,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  Formatters.formatFileSize(chapter.fileSize),
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                if (chapter.isPreview) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'رایگان',
                      style: TextStyle(color: AppColors.success, fontSize: 10),
                    ),
                  ),
                ],
                if (chapter.error != null) ...[
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'خطا',
                      style: TextStyle(color: AppColors.error, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            trailing: chapter.isUploaded || chapter.isUploading
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                        onPressed: () => _showEditChapterDialog(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => _removeChapter(index),
                      ),
                      if (!_isUploading)
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle, color: AppColors.textTertiary),
                        ),
                    ],
                  ),
          ),
          // Progress bar during upload
          if (chapter.isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(
                value: chapter.uploadProgress,
                backgroundColor: AppColors.surfaceLight,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
