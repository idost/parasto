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
import 'package:myna/screens/admin/admin_feedback_dialog.dart';

/// Model for chapter pending bulk upload with lazy loading
class _AdminChapterToUpload {
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

  _AdminChapterToUpload({
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

  /// Release bytes from memory after upload
  void releaseBytes() {
    _bytes = null;
  }
}

class AdminChapterManagementScreen extends ConsumerStatefulWidget {
  final int audiobookId;
  final String audiobookTitle;
  final String narratorId;

  const AdminChapterManagementScreen({
    super.key,
    required this.audiobookId,
    required this.audiobookTitle,
    required this.narratorId,
  });

  @override
  ConsumerState<AdminChapterManagementScreen> createState() =>
      _AdminChapterManagementScreenState();
}

class _AdminChapterManagementScreenState
    extends ConsumerState<AdminChapterManagementScreen> {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadingChapterName = '';
  String? _error;

  // Bulk upload state
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
    if (widget.audiobookId <= 0) {
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
      final response = await Supabase.instance.client
          .from('chapters')
          .select('*')
          .eq('audiobook_id', widget.audiobookId)
          .order('chapter_index', ascending: true);

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

  void _reorderChapters(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    setState(() {
      final item = _chapters.removeAt(oldIndex);
      _chapters.insert(newIndex, item);
    });

    // Update controller values to reflect new positions
    _initializeOrderControllers();
  }

  /// Save chapter order based on numeric input fields
  Future<void> _saveManualOrder() async {
    if (_chapters.isEmpty) return;

    AppLogger.d('_saveManualOrder called with ${_chapters.length} chapters');

    setState(() {
      _isSaving = true;
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

      // Persist to Supabase using negative indices first to avoid unique constraint conflicts
      AppLogger.d('Persisting to Supabase (step 1: negative indices)...');
      for (final entry in sortEntries) {
        final chapterId = entry.chapter['id'] as int;
        await Supabase.instance.client
            .from('chapters')
            .update({'chapter_index': -chapterId})
            .eq('id', chapterId);
      }

      AppLogger.d('Persisting to Supabase (step 2: final indices)...');
      for (final entry in sortEntries) {
        final chapterId = entry.chapter['id'] as int;
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
        _isSaving = false;
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
        _isSaving = false;
        _error = 'خطا در ذخیره ترتیب: $e';
      });
    }
  }

  Future<void> _editChapter(Map<String, dynamic> chapter) async {
    final titleFaController =
        TextEditingController(text: (chapter['title_fa'] as String?) ?? '');
    final titleEnController =
        TextEditingController(text: (chapter['title_en'] as String?) ?? '');
    bool isPreview = (chapter['is_preview'] as bool?) ?? false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('ویرایش فصل'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.from('chapters').update({
        'title_fa': result['title_fa'],
        'title_en': result['title_en'],
        'is_preview': result['is_preview'],
      }).eq('id', chapter['id'] as int);

      await _loadChapters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فصل ویرایش شد'),
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
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteChapter(Map<String, dynamic> chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 8),
              Text('حذف فصل'),
            ],
          ),
          content: Text(
            'آیا از حذف "${(chapter['title_fa'] as String?) ?? 'این فصل'}" اطمینان دارید?\n\n'
            'این عمل غیرقابل بازگشت است و فایل صوتی نیز حذف خواهد شد.',
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

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      // Delete audio file from storage
      final path = chapter['audio_storage_path'] as String?;
      if (path != null && path.isNotEmpty) {
        await Supabase.instance.client.storage
            .from('audiobook-audio')
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در حذف: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
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

  Future<void> _openChapterFeedback(Map<String, dynamic> chapter) async {
    final chapterId = chapter['id'] as int;
    final chapterTitle = (chapter['title_fa'] as String?) ?? 'بدون عنوان';

    await showAdminFeedbackDialog(
      context,
      audiobookId: widget.audiobookId,
      narratorId: widget.narratorId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
    );
  }

  Future<void> _addChapter() async {
    try {
      // Pick audio file
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

      // Upload audio file using narrator's ID for storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.name.split('.').last.toLowerCase();
      final path = '${widget.narratorId}/${widget.audiobookId}/$timestamp.$extension';

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
          'duration_seconds': 0,
          'file_size_bytes': file.size,
          'audio_format': extension,
          'is_preview': (chapterInfo['is_preview'] as bool?) ?? false,
        });
      } catch (dbError) {
        // DB insert failed - clean up orphan file from storage
        AppLogger.w('Admin chapter DB insert failed, cleaning up uploaded file: $path');
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
      setState(() => _error = 'خطا در آپلود: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadingChapterName = '';
      });
    }
  }

  /// Bulk upload multiple chapters at once (admin feature)
  Future<void> _addChaptersBulk() async {
    try {
      // Pick multiple audio files (lazy loading)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AudioValidator.getAllowedExtensions(),
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      AppLogger.d('Admin bulk upload: selected ${result.files.length} files');

      // Validate and prepare chapters
      final chaptersToUpload = <_AdminChapterToUpload>[];
      final validationErrors = <String>[];

      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];

        final validation = AudioValidator.validate(
          fileName: file.name,
          fileSizeBytes: file.size,
          mimeType: file.extension,
        );

        if (!validation.isValid) {
          validationErrors.add('${file.name}: ${validation.errorMessage?.split('\n').first ?? 'فرمت نامعتبر'}');
          continue;
        }

        final titleFa = _generateTitleFromFileName(
          file.name,
          _chapters.length + chaptersToUpload.length + 1,
        );

        chaptersToUpload.add(_AdminChapterToUpload(
          titleFa: titleFa,
          fileName: file.name,
          fileSize: file.size,
          platformFile: file,
        ));
      }

      if (validationErrors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${FarsiUtils.toFarsiDigits(validationErrors.length)} فایل رد شد'),
            backgroundColor: AppColors.warning,
          ),
        );
      }

      if (chaptersToUpload.isEmpty) {
        setState(() => _error = 'هیچ فایل معتبری انتخاب نشد');
        return;
      }

      // Show dialog
      final confirmed = await _showBulkUploadDialog(chaptersToUpload);
      if (confirmed != true) return;

      // Upload chapters
      setState(() {
        _isBulkUploading = true;
        _bulkUploadedCount = 0;
        _bulkTotalCount = chaptersToUpload.length;
      });

      int successCount = 0;
      int nextIndex = _chapters.isEmpty
          ? 1
          : (_chapters.map((c) => c['chapter_index'] as int? ?? 0).reduce((a, b) => a > b ? a : b) + 1);

      // Upload sequentially with lazy loading
      for (int i = 0; i < chaptersToUpload.length; i++) {
        final chapter = chaptersToUpload[i];

        try {
          // Lazy load bytes only when uploading
          final bytes = await chapter.getBytes();

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = chapter.fileName.split('.').last.toLowerCase();
          final path = '${widget.narratorId}/${widget.audiobookId}/$timestamp.$extension';

          await Supabase.instance.client.storage
              .from(Env.audioBucket)
              .uploadBinary(path, bytes);

          // Release bytes from memory
          chapter.releaseBytes();

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

          nextIndex++;
          successCount++;
          setState(() => _bulkUploadedCount = successCount);
        } catch (e) {
          AppLogger.e('Bulk upload failed for ${chapter.fileName}', error: e);
          chapter.releaseBytes();
          // Continue with next file
        }
      }

      // Update audiobook chapter count
      if (successCount > 0) {
        await Supabase.instance.client
            .from('audiobooks')
            .update({'chapter_count': _chapters.length + successCount})
            .eq('id', widget.audiobookId);
      }

      await _loadChapters();
      setState(() => _isBulkUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${FarsiUtils.toFarsiDigits(successCount)} فصل آپلود شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isBulkUploading = false;
        _error = 'خطا در آپلود دسته‌ای';
      });
    }
  }

  String _generateTitleFromFileName(String fileName, int chapterNumber) {
    String baseName = fileName.split('.').first;
    baseName = baseName
        .replaceAll(RegExp(r'(chapter|ch|فصل)[\s_-]*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\d+[\s_-]*'), '')
        .trim();

    if (baseName.isEmpty || baseName.length < 3) {
      return 'فصل ${FarsiUtils.toFarsiDigits(chapterNumber)}';
    }
    return baseName;
  }

  Future<bool?> _showBulkUploadDialog(List<_AdminChapterToUpload> chapters) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BulkUploadDialog(
        chapters: chapters,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
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
          content: Text(errorMessage),
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
                              Text(fileName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              Text(Formatters.formatFileSize(fileSize), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isPreview,
                        onChanged: (value) => setDialogState(() => isPreview = value ?? false),
                        activeColor: AppColors.primary,
                      ),
                      const Text('نمونه رایگان'),
                    ],
                  ),
                  const Text('فصل‌های نمونه برای همه کاربران قابل پخش است', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('انصراف')),
              ElevatedButton(
                onPressed: () {
                  if (titleFaController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('عنوان فارسی الزامی است'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'title_fa': titleFaController.text.trim(),
                    'title_en': titleEnController.text.trim().isEmpty ? null : titleEnController.text.trim(),
                    'is_preview': isPreview,
                  });
                },
                child: const Text('تایید'),
              ),
            ],
          ),
        ),
      ),
    );
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
        ),
        // LAYOUT FIX: Removed FAB, using unified bottom bar to prevent overlap
        body: Column(
          children: [
            // Instructions banner (only show when chapters exist)
            if (_chapters.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'شماره ترتیب هر فصل را وارد کنید یا فصل‌ها را بکشید',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.error)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),

            // Upload progress indicator
            if (_isUploading)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_upload, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'در حال آپلود: $_uploadingChapterName',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.surfaceLight,
                        color: AppColors.primary,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Chapters list (takes remaining space)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _chapters.isEmpty
                      ? _buildEmptyState()
                      : _buildChaptersList(),
            ),

            // Unified bottom action bar (no FAB overlap)
            _buildBottomActionBar(),
          ],
        ),
        // No floatingActionButton - all actions are in the bottom bar
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
              'از دکمه زیر برای افزودن فصل استفاده کنید',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // Order number input - compact
            SizedBox(
              width: 44,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Chapter info - use Expanded to take remaining space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (chapter['title_fa'] as String?) ?? 'بدون عنوان',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Metadata row - wrap in Flexible to prevent overflow
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text(
                        _formatDuration(chapter['duration_seconds'] as int?),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.storage, size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          _formatFileSize(chapter['file_size_bytes'] as int?),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPreview) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions - more compact with smaller touch targets
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: const Icon(Icons.comment_outlined, color: AppColors.warning, size: 18),
                onPressed: () => _openChapterFeedback(chapter),
                tooltip: 'بازخورد',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                onPressed: () => _editChapter(chapter),
                tooltip: 'ویرایش',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                onPressed: () => _deleteChapter(chapter),
                tooltip: 'حذف',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsetsDirectional.only(end: 4),
                child: Icon(Icons.drag_handle, color: AppColors.textTertiary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unified bottom action bar with all actions:
  /// - Add chapter button
  /// - Save order button (when >1 chapter)
  ///
  /// FIX: Prevents overlapping buttons on small screens by:
  /// 1. Using SafeArea with proper padding
  /// 2. All buttons in a single Column (no floating/positioned elements)
  Widget _buildBottomActionBar() {
    final bool hasMultipleChapters = _chapters.length > 1;
    final bool isUploadDisabled = _isUploading || _isBulkUploading || _isSaving;

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
          final bool isCompact = constraints.maxWidth < 300;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bulk upload progress
              if (_isBulkUploading) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'آپلود ${FarsiUtils.toFarsiDigits(_bulkUploadedCount)} از ${FarsiUtils.toFarsiDigits(_bulkTotalCount)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _bulkTotalCount > 0
                            ? _bulkUploadedCount / _bulkTotalCount
                            : 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Upload buttons (responsive layout)
              if (isCompact) ...[
                // Vertical layout for narrow screens
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUploadDisabled ? null : _addChapter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('افزودن فصل'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isUploadDisabled ? null : _addChaptersBulk,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.library_add, size: 18),
                    label: const Text('آپلود چند فصل'),
                  ),
                ),
              ] else ...[
                // Horizontal layout for wide screens
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploadDisabled ? null : _addChapter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('افزودن فصل'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: isUploadDisabled ? null : _addChaptersBulk,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      icon: const Icon(Icons.library_add, size: 18),
                      label: const Text('چند فصل'),
                    ),
                  ],
                ),
              ],

              // Row 2: Save order (only when >1 chapter)
              if (hasMultipleChapters) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'شماره ترتیب هر فصل را وارد کنید',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _saveManualOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: const Text('ذخیره ترتیب', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
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

/// Bulk upload dialog for admin chapter management
class _BulkUploadDialog extends StatefulWidget {
  final List<_AdminChapterToUpload> chapters;
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
    for (final c in _titleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _confirmUpload() {
    // Validate all titles
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
            Text(
              'آپلود ${FarsiUtils.toFarsiDigits(widget.chapters.length)} فصل',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.chapters.length,
            itemBuilder: (context, i) {
              final chapter = widget.chapters[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فصل ${FarsiUtils.toFarsiDigits(i + 1)} • ${Formatters.formatFileSize(chapter.fileSize)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _titleControllers[i],
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'عنوان فصل',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onChanged: (value) {
                        chapter.titleFa = value;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: chapter.isPreview,
                          onChanged: (val) {
                            setState(() {
                              chapter.isPreview = val ?? false;
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Text(
                          'پیش‌نمایش رایگان',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: _confirmUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('شروع آپلود ${FarsiUtils.toFarsiDigits(widget.chapters.length)} فصل'),
          ),
        ],
      ),
    );
  }
}
