import 'dart:io';
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
import 'package:myna/screens/narrator/audio_guidelines_screen.dart';

/// Model for a chapter pending bulk upload (narrator-only)
/// Uses lazy loading to avoid memory issues with large batches
class _NarratorChapterToUpload {
  String titleFa;
  String? titleEn;
  bool isPreview = false;
  final String fileName;
  final int fileSize;

  // Lazy-loaded bytes - only loaded when needed during upload
  Uint8List? _bytes;
  final PlatformFile? _platformFile;

  bool isUploading = false;
  bool isUploaded = false;
  String? error;
  double uploadProgress = 0;

  _NarratorChapterToUpload({
    required this.titleFa,
    this.titleEn,
    required this.fileName,
    required this.fileSize,
    Uint8List? bytes,
    PlatformFile? platformFile,
  })  : _bytes = bytes,
        _platformFile = platformFile;

  /// Get bytes - loads from platformFile if not already loaded
  Future<Uint8List> getBytes() async {
    if (_bytes != null) return _bytes!;

    // If bytes are already loaded in platformFile
    if (_platformFile?.bytes != null) {
      _bytes = _platformFile!.bytes;
      return _bytes!;
    }

    // If we have a file path, read from disk (for withData: false)
    if (_platformFile?.path != null) {
      final file = File(_platformFile!.path!);
      _bytes = await file.readAsBytes();
      return _bytes!;
    }

    throw Exception('No bytes available for file: $fileName');
  }

  /// Release bytes from memory after upload (critical for memory management)
  void releaseBytes() {
    _bytes = null;
  }
}

class ChapterManagementScreen extends ConsumerStatefulWidget {
  final int audiobookId;
  final String audiobookTitle;

  const ChapterManagementScreen({
    super.key,
    required this.audiobookId,
    required this.audiobookTitle,
  });

  @override
  ConsumerState<ChapterManagementScreen> createState() => _ChapterManagementScreenState();
}

class _ChapterManagementScreenState extends ConsumerState<ChapterManagementScreen> {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSavingOrder = false;
  String? _error;
  double _uploadProgress = 0;
  String _uploadingChapterName = '';

  // Bulk upload state (narrator)
  bool _isBulkUploading = false;
  int _bulkUploadedCount = 0;
  int _bulkTotalCount = 0;

  // Controllers for manual order input
  final Map<int, TextEditingController> _orderControllers = {};

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void dispose() {
    // Clean up all controllers
    for (final controller in _orderControllers.values) {
      controller.dispose();
    }
    _orderControllers.clear();
    super.dispose();
  }

  void _initializeOrderControllers() {
    // Dispose old controllers that are no longer needed
    final currentIds = _chapters.map((c) => c['id'] as int).toSet();
    final controllersToRemove = _orderControllers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in controllersToRemove) {
      _orderControllers[id]?.dispose();
      _orderControllers.remove(id);
    }

    // Initialize or update controllers for current chapters
    for (int i = 0; i < _chapters.length; i++) {
      final chapter = _chapters[i];
      final chapterId = chapter['id'] as int;
      final orderValue = (chapter['chapter_index'] as int?) ?? (i + 1);

      if (_orderControllers.containsKey(chapterId)) {
        // Update existing controller's text
        _orderControllers[chapterId]!.text = orderValue.toString();
      } else {
        // Create new controller
        _orderControllers[chapterId] = TextEditingController(
          text: orderValue.toString(),
        );
      }
    }
  }

  Future<void> _loadChapters() async {
    // Guard against invalid audiobook ID
    if (widget.audiobookId <= 0) {
      AppLogger.e('Invalid audiobook ID: ${widget.audiobookId}');
      setState(() {
        _error = 'شناسه کتاب نامعتبر است';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      AppLogger.d('Loading chapters for audiobook ${widget.audiobookId}');
      final response = await Supabase.instance.client
          .from('chapters')
          .select('*')
          .eq('audiobook_id', widget.audiobookId)
          .order('chapter_index', ascending: true);

      AppLogger.d('Loaded ${response.length} chapters');
      if (!mounted) return;

      final chapters = List<Map<String, dynamic>>.from(response);

      // Auto-assign chapter_index for any NULL values
      await _normalizeChapterIndices(chapters);

      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
      _initializeOrderControllers();
    } catch (e) {
      AppLogger.e('Error loading chapters', error: e);
      if (!mounted) return;
      setState(() {
        _error = 'خطا در بارگذاری فصل‌ها: $e';
        _isLoading = false;
      });
    }
  }

  /// Normalize chapter indices: assign 1..N for any NULL values
  Future<void> _normalizeChapterIndices(List<Map<String, dynamic>> chapters) async {
    if (chapters.isEmpty) return;

    // Check if any chapter has NULL chapter_index
    final hasNullIndex = chapters.any((c) => c['chapter_index'] == null);
    if (!hasNullIndex) return;

    AppLogger.d('Found NULL chapter_index values, normalizing...');

    // Assign sequential indices based on current position
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      if (chapter['chapter_index'] == null) {
        final newIndex = i + 1;
        chapter['chapter_index'] = newIndex;

        // Persist to database
        await Supabase.instance.client
            .from('chapters')
            .update({'chapter_index': newIndex})
            .eq('id', chapter['id'] as int);
      }
    }

    AppLogger.d('Chapter indices normalized');
  }

  Future<void> _saveManualOrder() async {
    if (_chapters.isEmpty) return;

    AppLogger.d('_saveManualOrder called with ${_chapters.length} chapters');

    setState(() {
      _isSavingOrder = true;
      _error = null;
    });

    try {
      // Build list of (chapter, sortKey) pairs
      final List<_ChapterSortEntry> sortEntries = [];
      int invalidCounter = 0;

      for (int i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];
        final chapterId = chapter['id'] as int;
        final controller = _orderControllers[chapterId];
        final textValue = controller?.text.trim() ?? '';

        AppLogger.d('Chapter $chapterId: textValue="$textValue"');

        int sortKey;
        final parsed = int.tryParse(textValue);
        if (parsed != null && parsed > 0) {
          sortKey = parsed;
        } else {
          // Invalid: assign large sentinel + relative position to keep order among invalids
          sortKey = 9999 + invalidCounter;
          invalidCounter++;
        }

        sortEntries.add(_ChapterSortEntry(
          chapter: chapter,
          sortKey: sortKey,
          originalIndex: i,
        ));
      }

      // Sort by sortKey (stable sort preserves original order for equal keys)
      sortEntries.sort((a, b) {
        final cmp = a.sortKey.compareTo(b.sortKey);
        if (cmp != 0) return cmp;
        // For equal sortKeys, preserve original order
        return a.originalIndex.compareTo(b.originalIndex);
      });

      // Assign clean contiguous order: 1, 2, 3, ...
      for (int i = 0; i < sortEntries.length; i++) {
        sortEntries[i].newOrder = i + 1;
        AppLogger.d('After sort: chapter ${sortEntries[i].chapter['id']} -> newOrder ${sortEntries[i].newOrder}');
      }

      // Persist to Supabase
      AppLogger.d('Persisting to Supabase...');
      for (final entry in sortEntries) {
        final chapterId = entry.chapter['id'] as int;
        AppLogger.d('Updating chapter $chapterId to chapter_index=${entry.newOrder}');
        await Supabase.instance.client
            .from('chapters')
            .update({'chapter_index': entry.newOrder})
            .eq('id', chapterId);
      }
      AppLogger.d('Supabase updates complete');

      if (!mounted) return;

      // Update in-memory list and sort by new order inside setState
      setState(() {
        for (final entry in sortEntries) {
          entry.chapter['chapter_index'] = entry.newOrder;
        }
        _chapters = sortEntries.map((e) => e.chapter).toList();
        _isSavingOrder = false;
      });

      // Reinitialize controllers with new order values AFTER setState
      _initializeOrderControllers();

      AppLogger.d('Manual order saved successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ترتیب فصل‌ها ذخیره شد'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      AppLogger.e('Error saving manual order', error: e);
      if (!mounted) return;
      setState(() {
        _isSavingOrder = false;
        _error = 'خطا در ذخیره ترتیب: $e';
      });
    }
  }

  Future<void> _addChapter() async {
    try {
      // Pick audio file - only allow MP3 and M4A
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AudioValidator.getAllowedExtensions(),
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() => _error = 'خطا در خواندن فایل');
        return;
      }

      // Validate audio file
      final validation = AudioValidator.validate(
        fileName: file.name,
        fileSizeBytes: file.size,
        mimeType: file.extension,
      );

      if (!validation.isValid) {
        await _showValidationErrorDialog(validation.errorMessage!);
        return;
      }

      // Show warning if any
      if (validation.warningMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.warningMessage!),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Show dialog to get chapter title
      final chapterInfo = await _showChapterInfoDialog(file.name, file.size);
      if (chapterInfo == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
        _uploadingChapterName = (chapterInfo['title_fa'] as String?) ?? '';
        _error = null;
      });

      // Upload audio file
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('کاربر وارد نشده');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.name.split('.').last.toLowerCase();
      final path = '${user.id}/${widget.audiobookId}/$timestamp.$extension';

      // Simulate progress (Supabase doesn't provide real progress for web)
      setState(() => _uploadProgress = 0.3);

      await Supabase.instance.client.storage
          .from(Env.audioBucket)
          .uploadBinary(path, file.bytes!);

      setState(() => _uploadProgress = 0.7);

      // Get next chapter index
      final nextIndex = _chapters.isEmpty
          ? 1
          : (_chapters.map((c) => (c['chapter_index'] as int?) ?? 0).reduce((a, b) => a > b ? a : b) + 1);

      // Create chapter record - with orphan file cleanup on failure
      try {
        await Supabase.instance.client.from('chapters').insert({
          'audiobook_id': widget.audiobookId,
          'title_fa': chapterInfo['title_fa'],
          'title_en': chapterInfo['title_en'],
          'chapter_index': nextIndex,
          'audio_storage_path': path,
          'duration_seconds': 0, // Will be updated when audio is processed
          'file_size_bytes': file.size,
          'audio_format': extension,
          'is_preview': (chapterInfo['is_preview'] as bool?) ?? false,
        });
      } catch (dbError) {
        // DB insert failed - clean up orphan file from storage
        AppLogger.w('Chapter DB insert failed, cleaning up uploaded file: $path');
        try {
          await Supabase.instance.client.storage.from(Env.audioBucket).remove([path]);
        } catch (cleanupError) {
          AppLogger.e('Failed to cleanup orphan audio file: $path', error: cleanupError);
        }
        rethrow;
      }

      setState(() => _uploadProgress = 0.9);

      // Update audiobook chapter count
      await Supabase.instance.client
          .from('audiobooks')
          .update({'chapter_count': nextIndex})
          .eq('id', widget.audiobookId);

      setState(() => _uploadProgress = 1.0);

      // Reload chapters
      await _loadChapters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فصل با موفقیت اضافه شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Upload error', error: e);
      setState(() => _error = AudioValidator.getUploadErrorMessage(e));
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadingChapterName = '';
      });
    }
  }

  /// Bulk upload multiple chapters at once (narrator feature)
  Future<void> _addChaptersBulk() async {
    try {
      // Pick multiple audio files
      // withData: false for lazy loading - saves memory for large batches
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AudioValidator.getAllowedExtensions(),
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        AppLogger.d('Narrator bulk upload: No files selected');
        return;
      }

      AppLogger.d('Narrator bulk upload: selected ${result.files.length} files for audiobook ${widget.audiobookId}');

      // Validate and prepare chapters
      final chaptersToUpload = <_NarratorChapterToUpload>[];
      final validationErrors = <String>[];

      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        AppLogger.d('Narrator bulk upload: file[$i] = ${file.name}, size=${file.size}');

        // Validate audio file
        final validation = AudioValidator.validate(
          fileName: file.name,
          fileSizeBytes: file.size,
          mimeType: file.extension,
        );

        if (!validation.isValid) {
          validationErrors.add('${file.name}: ${validation.errorMessage?.split('\n').first ?? 'فرمت نامعتبر'}');
          continue;
        }

        // Generate title from file name
        final titleFa = _generateTitleFromFileName(file.name, _chapters.length + chaptersToUpload.length + 1);

        // Store platformFile reference for lazy loading (not the bytes!)
        chaptersToUpload.add(_NarratorChapterToUpload(
          titleFa: titleFa,
          fileName: file.name,
          fileSize: file.size,
          platformFile: file,
        ));
      }

      // Show validation errors if any
      if (validationErrors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${FarsiUtils.toFarsiDigits(validationErrors.length)} فایل رد شد: ${validationErrors.first}'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (chaptersToUpload.isEmpty) {
        if (mounted) {
          setState(() => _error = 'هیچ فایل معتبری انتخاب نشد');
        }
        return;
      }

      // Show bulk upload confirmation/editing dialog
      final confirmed = await _showBulkUploadDialog(chaptersToUpload);
      if (confirmed != true) return;

      // Start bulk upload
      setState(() {
        _isBulkUploading = true;
        _bulkUploadedCount = 0;
        _bulkTotalCount = chaptersToUpload.length;
        _error = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isBulkUploading = false;
          _error = 'کاربر وارد نشده است';
        });
        return;
      }

      int successCount = 0;
      int failCount = 0;

      // Get current max chapter index
      int nextIndex = _chapters.isEmpty
          ? 1
          : (_chapters.map((c) => (c['chapter_index'] as int?) ?? 0).reduce((a, b) => a > b ? a : b) + 1);

      // Upload chapters sequentially (to avoid overloading)
      for (int i = 0; i < chaptersToUpload.length; i++) {
        final chapter = chaptersToUpload[i];
        AppLogger.d('Narrator bulk upload: uploading ${i + 1}/${chaptersToUpload.length}: ${chapter.fileName}');

        try {
          // Lazy load bytes only when uploading (memory optimization for large batches)
          final bytes = await chapter.getBytes();
          AppLogger.d('Narrator bulk upload: loaded ${bytes.length} bytes for ${chapter.fileName}');

          // Upload audio file
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = chapter.fileName.split('.').last.toLowerCase();
          final path = '${user.id}/${widget.audiobookId}/$timestamp.$extension';

          await Supabase.instance.client.storage
              .from(Env.audioBucket)
              .uploadBinary(path, bytes);

          // Release bytes from memory after upload (critical for large batches like 93 chapters)
          chapter.releaseBytes();
          AppLogger.d('Narrator bulk upload: released bytes for ${chapter.fileName}');

          // Create chapter record - with orphan file cleanup on failure
          try {
            await Supabase.instance.client.from('chapters').insert({
              'audiobook_id': widget.audiobookId,
              'title_fa': chapter.titleFa.trim(),
              'title_en': chapter.titleEn?.trim().isEmpty == true ? null : chapter.titleEn?.trim(),
              'chapter_index': nextIndex,
              'audio_storage_path': path,
              'duration_seconds': 0,
              'file_size_bytes': chapter.fileSize,
              'audio_format': extension,
              'is_preview': chapter.isPreview,
            });
          } catch (dbError) {
            // DB insert failed - clean up orphan file from storage
            AppLogger.w('Bulk upload: DB insert failed, cleaning up file: $path');
            try {
              await Supabase.instance.client.storage.from(Env.audioBucket).remove([path]);
            } catch (cleanupError) {
              AppLogger.e('Failed to cleanup orphan audio file: $path', error: cleanupError);
            }
            rethrow;
          }

          nextIndex++;
          successCount++;

          if (mounted) {
            setState(() => _bulkUploadedCount = successCount);
          }

          AppLogger.d('Narrator bulk upload: chapter ${chapter.fileName} uploaded successfully');
        } catch (e) {
          AppLogger.e('Narrator bulk upload: failed to upload ${chapter.fileName}', error: e);
          // Release bytes on error too (prevent memory leak)
          chapter.releaseBytes();
          failCount++;
          // Continue with next file (best-effort)
        }
      }

      // Update audiobook chapter count
      if (successCount > 0) {
        final newTotalCount = _chapters.length + successCount;
        await Supabase.instance.client
            .from('audiobooks')
            .update({'chapter_count': newTotalCount})
            .eq('id', widget.audiobookId);
      }

      // Reload chapters
      await _loadChapters();

      if (mounted) {
        setState(() => _isBulkUploading = false);

        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('همه ${FarsiUtils.toFarsiDigits(successCount)} فصل با موفقیت آپلود شدند'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${FarsiUtils.toFarsiDigits(successCount)} فصل آپلود شد، ${FarsiUtils.toFarsiDigits(failCount)} فایل خطا داشت'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('Narrator bulk upload error', error: e);
      if (mounted) {
        setState(() {
          _isBulkUploading = false;
          _error = AudioValidator.getUploadErrorMessage(e);
        });
      }
    }
  }

  /// Generate a default title from file name
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

  /// Show dialog for bulk upload confirmation and editing
  Future<bool?> _showBulkUploadDialog(List<_NarratorChapterToUpload> chapters) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _BulkUploadDialog(
        chapters: chapters,
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
  }

  Future<void> _showValidationErrorDialog(String errorMessage) async {
    return showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 8),
              Text('خطای فایل صوتی'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // FIX: Close dialog first, then push new route after frame completes
                    // This avoids _debugLocked error from navigating while navigator is locked
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.push(
                          this.context, // Use widget context, not dialog context
                          MaterialPageRoute<void>(
                            builder: (_) => const AudioGuidelinesScreen(),
                          ),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('مشاهده راهنمای کامل'),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showChapterInfoDialog(String fileName, int fileSize) async {
    final titleFaController = TextEditingController();
    final titleEnController = TextEditingController();
    bool isPreview = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('اطلاعات فصل'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File name display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppRadius.small,
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
                                fileName,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatFileSize(fileSize),
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
                onPressed: () => Navigator.pop(context, null),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleFaController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('عنوان فارسی الزامی است'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'title_fa': titleFaController.text.trim(),
                    'title_en': titleEnController.text.trim().isEmpty
                        ? null
                        : titleEnController.text.trim(),
                    'is_preview': isPreview,
                  });
                },
                child: const Text('افزودن'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteChapter(Map<String, dynamic> chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('حذف فصل'),
          content: Text('آیا از حذف "${(chapter['title_fa'] as String?) ?? 'این فصل'}" اطمینان دارید؟'),
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

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);

      // Delete audio file from storage
      final path = chapter['audio_storage_path'] as String?;
      if (path != null && path.isNotEmpty) {
        await Supabase.instance.client.storage
            .from(Env.audioBucket)
            .remove([path]);
      }

      // Delete chapter record
      await Supabase.instance.client
          .from('chapters')
          .delete()
          .eq('id', chapter['id'] as int);

      // Update chapter count
      await Supabase.instance.client
          .from('audiobooks')
          .update({'chapter_count': _chapters.length - 1})
          .eq('id', widget.audiobookId);

      // Reload
      await _loadChapters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فصل حذف شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'خطا در حذف: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editChapterTitle(Map<String, dynamic> chapter) async {
    final titleFaController = TextEditingController(
      text: (chapter['title_fa'] as String?) ?? '',
    );
    final titleEnController = TextEditingController(
      text: (chapter['title_en'] as String?) ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('ویرایش عنوان فصل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleFaController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان فصل (فارسی) *',
                    hintText: 'مثال: فصل اول - آغاز داستان',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleEnController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان انگلیسی (اختیاری)',
                    hintText: 'Chapter 1 - The Beginning',
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleFaController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('عنوان فارسی الزامی است'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'title_fa': titleFaController.text.trim(),
                  'title_en': titleEnController.text.trim().isEmpty
                      ? null
                      : titleEnController.text.trim(),
                });
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      setState(() => _isLoading = true);

      await Supabase.instance.client.from('chapters').update({
        'title_fa': result['title_fa'],
        'title_en': result['title_en'],
      }).eq('id', chapter['id'] as int);

      await _loadChapters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عنوان فصل ویرایش شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ویرایش: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForReview() async {
    if (_chapters.isEmpty) {
      setState(() => _error = 'حداقل یک فصل اضافه کنید');
      return;
    }

    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('ارسال برای بررسی'),
          content: const Text(
            'پس از ارسال، کتاب شما توسط تیم ما بررسی خواهد شد.\n'
            'آیا ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ارسال'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);

      await Supabase.instance.client
          .from('audiobooks')
          .update({'status': 'submitted'})
          .eq('id', widget.audiobookId);

      if (!mounted) return;

      // Show success dialog with clear message
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            icon: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 48,
            ),
            title: const Text('ارسال موفق'),
            content: const Text(
              'کتاب شما با موفقیت ارسال شد و در صف بازبینی قرار گرفت.\n'
              'پس از تأیید، کتاب شما در اپلیکیشن منتشر خواهد شد.',
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;

      // Navigate back to narrator audiobooks list (tab index 1)
      // Pop this screen and pass 'submitted' to signal success to the upload screen
      Navigator.pop(context, 'submitted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'خطا: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '--:--';
    return Formatters.formatDuration(seconds);
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    return Formatters.formatFileSize(bytes);
  }

  @override
  Widget build(BuildContext context) {
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
                'مدیریت فصل‌ها',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                widget.audiobookTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            // Guidelines button
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AudioGuidelinesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.help_outline),
              tooltip: 'راهنمای صدا',
            ),
          ],
        ),
        // LAYOUT FIX: All actions consolidated into a single bottom bar.
        // Previously had overlapping FAB + bottom bar which caused UI issues on small screens.
        // Now using Column + Expanded + fixed bottom bar pattern for robust layout.
        body: Column(
          children: [
            // Upload progress (single file)
            if (_isUploading) _buildUploadProgress(),

            // Bulk upload progress
            if (_isBulkUploading) _buildBulkUploadProgress(),

            // Error message
            if (_error != null) _buildError(),

            // Chapters list (scrollable, takes remaining space)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _chapters.isEmpty
                      ? _buildEmptyState()
                      : _buildChaptersList(),
            ),

            // Unified bottom action bar (no overlapping FAB)
            _buildBottomActionBar(),
          ],
        ),
        // No floatingActionButton - all actions are in the bottom bar
      ),
    );
  }

  /// Unified bottom action bar with all actions:
  /// - Add chapter buttons (single + bulk)
  /// - Save order button (when >1 chapter)
  /// - Submit for review button (when chapters exist)
  ///
  /// FIX: Prevents overlapping buttons on small screens by:
  /// 1. Using SafeArea with proper padding
  /// 2. All buttons in a single Column (no floating/positioned elements)
  /// 3. Keyboard dismissal before actions
  /// 4. Responsive layout with LayoutBuilder for very small screens
  Widget _buildBottomActionBar() {
    final bool isUploadDisabled = _isUploading || _isBulkUploading;
    final bool hasChapters = _chapters.isNotEmpty;
    final bool hasMultipleChapters = _chapters.length > 1;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use compact layout on very small screens (< 300px width)
          final bool isCompact = constraints.maxWidth < 300;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Add chapter buttons (always visible)
              // On very small screens, stack vertically
              if (isCompact) ...[
                // Compact: Stack buttons vertically
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUploadDisabled ? null : () {
                      FocusScope.of(context).unfocus();
                      _addChapter();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUploadDisabled ? AppColors.surfaceLight : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(44, 44), // Minimum touch target
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('افزودن فصل', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isUploadDisabled ? null : () {
                      FocusScope.of(context).unfocus();
                      _addChaptersBulk();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isUploadDisabled ? AppColors.textTertiary : AppColors.primary,
                      side: BorderSide(
                        color: isUploadDisabled ? AppColors.border : AppColors.primary,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.library_add, size: 18),
                    label: const Text('آپلود چند فصل', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ] else ...[
                // Normal: Side by side
                Row(
                  children: [
                    // Single chapter upload (primary action)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploadDisabled ? null : () {
                          FocusScope.of(context).unfocus();
                          _addChapter();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isUploadDisabled ? AppColors.surfaceLight : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('افزودن فصل', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bulk upload (secondary action)
                    OutlinedButton.icon(
                      onPressed: isUploadDisabled ? null : () {
                        FocusScope.of(context).unfocus();
                        _addChaptersBulk();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isUploadDisabled ? AppColors.textTertiary : AppColors.primary,
                        side: BorderSide(
                          color: isUploadDisabled ? AppColors.border : AppColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.library_add, size: 18),
                      label: const Text('چند فصل', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],

              // Row 2: Save order (only when >1 chapter)
              if (hasMultipleChapters) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'شماره ترتیب هر فصل را وارد کنید',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: isCompact ? 11 : 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isSavingOrder ? null : () {
                        FocusScope.of(context).unfocus();
                        _saveManualOrder();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8 : 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: _isSavingOrder
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(
                        'ذخیره ترتیب',
                        style: TextStyle(fontSize: isCompact ? 11 : 12),
                      ),
                    ),
                  ],
                ),
              ],

              // Row 3: Submit for review (only when chapters exist)
              if (hasChapters) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () {
                      FocusScope.of(context).unfocus();
                      _submitForReview();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(44, 48),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      'ارسال برای بررسی',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'در حال آپلود: $_uploadingChapterName',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: AppColors.surfaceLight,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBulkUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'آپلود دسته‌ای: $_bulkUploadedCount از $_bulkTotalCount فصل',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              Text(
                '$_bulkUploadedCount/$_bulkTotalCount',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _bulkTotalCount > 0 ? _bulkUploadedCount / _bulkTotalCount : 0,
            backgroundColor: AppColors.surfaceLight,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.small,
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
              'هنوز فصلی اضافه نشده',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'از دکمه‌های پایین صفحه برای افزودن فصل استفاده کنید',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Audio format info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.medium,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'فرمت‌های مجاز',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'MP3 یا M4A • حداکثر ${AudioValidator.kServerMaxFileSizeMB} مگابایت • حداکثر ۲۴۰ دقیقه',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AudioGuidelinesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('راهنمای کامل کیفیت صدا'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16), // Bottom margin
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    return ReorderableListView.builder(
      // Bottom padding reduced since bottom bar is now part of Column layout
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _chapters.length,
      onReorder: _reorderChapters,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        return _buildChapterItem(chapter, index);
      },
    );
  }

  Widget _buildChapterItem(Map<String, dynamic> chapter, int index) {
    final isPreview = (chapter['is_preview'] as bool?) == true;
    final chapterId = chapter['id'] as int;
    final controller = _orderControllers[chapterId];

    return Card(
      key: ValueKey(chapterId),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Order number input
            SizedBox(
              width: 50,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.small,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.small,
                    borderSide: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.small,
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Chapter info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (chapter['title_fa'] as String?) ?? 'بدون عنوان',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(chapter['duration_seconds'] as int?),
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storage, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            _formatFileSize(chapter['file_size_bytes'] as int?),
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                      if (isPreview)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
              onPressed: () => _editChapterTitle(chapter),
              tooltip: 'ویرایش عنوان',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              onPressed: () => _deleteChapter(chapter),
              tooltip: 'حذف',
              visualDensity: VisualDensity.compact,
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle, color: AppColors.textTertiary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorderChapters(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    setState(() {
      final item = _chapters.removeAt(oldIndex);
      _chapters.insert(newIndex, item);
    });

    // Update chapter indices in database
    try {
      for (int i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];
        chapter['chapter_index'] = i + 1;
        await Supabase.instance.client
            .from('chapters')
            .update({'chapter_index': i + 1})
            .eq('id', chapter['id'] as int);
      }
      // Reinitialize controllers after reorder
      _initializeOrderControllers();
    } catch (e) {
      AppLogger.e('Reorder error', error: e);
      await _loadChapters(); // Reload on error
    }
  }
}

/// Helper class for sorting chapters by manual order input
class _ChapterSortEntry {
  final Map<String, dynamic> chapter;
  final int sortKey;
  final int originalIndex;
  int newOrder = 0;

  _ChapterSortEntry({
    required this.chapter,
    required this.sortKey,
    required this.originalIndex,
  });
}

/// Dialog for bulk upload confirmation and editing chapter titles
class _BulkUploadDialog extends StatefulWidget {
  final List<_NarratorChapterToUpload> chapters;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _BulkUploadDialog({
    required this.chapters,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<_BulkUploadDialog> {
  late List<TextEditingController> _titleControllers;

  @override
  void initState() {
    super.initState();
    _titleControllers = widget.chapters
        .map((c) => TextEditingController(text: c.titleFa))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final chapter = widget.chapters.removeAt(oldIndex);
      widget.chapters.insert(newIndex, chapter);
      final controller = _titleControllers.removeAt(oldIndex);
      _titleControllers.insert(newIndex, controller);
    });
  }

  void _removeItem(int index) {
    setState(() {
      widget.chapters.removeAt(index);
      _titleControllers[index].dispose();
      _titleControllers.removeAt(index);
    });
  }

  void _confirmUpload() {
    // Check for empty titles
    for (int i = 0; i < widget.chapters.length; i++) {
      final title = _titleControllers[i].text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('عنوان فصل ${FarsiUtils.toFarsiDigits(i + 1)} خالی است'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      widget.chapters[i].titleFa = title;
    }
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.library_add, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('آپلود ${widget.chapters.length} فصل'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: widget.chapters.isEmpty
              ? const Center(
                  child: Text(
                    'همه فایل‌ها حذف شدند',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'می‌توانید عنوان‌ها را ویرایش کنید یا ترتیب را تغییر دهید:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: widget.chapters.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) {
                          final chapter = widget.chapters[index];
                          return Card(
                            key: ValueKey('bulk_chapter_$index'),
                            color: AppColors.background,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  // Order number
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppRadius.xs),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Title field and file info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _titleControllers[index],
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            hintText: 'عنوان فصل',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.xs),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: AppColors.surface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${chapter.fileName} • ${Formatters.formatFileSize(chapter.fileSize)}',
                                          style: const TextStyle(
                                            color: AppColors.textTertiary,
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppColors.error,
                                      size: 18,
                                    ),
                                    onPressed: () => _removeItem(index),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  // Drag handle
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(
                                      Icons.drag_handle,
                                      color: AppColors.textTertiary,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('انصراف'),
          ),
          ElevatedButton.icon(
            onPressed: widget.chapters.isEmpty ? null : _confirmUpload,
            icon: const Icon(Icons.upload, size: 18),
            label: Text('آپلود ${widget.chapters.length} فصل'),
          ),
        ],
      ),
    );
  }
}
