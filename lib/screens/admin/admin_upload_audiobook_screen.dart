import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/config/env.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/screens/admin/admin_bulk_chapter_upload_screen.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/services/creator_service.dart';

/// Provider to fetch narrators (users with role='narrator')
final narratorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select('id, display_name, full_name, email, avatar_url')
      .eq('role', 'narrator')
      .eq('is_disabled', false)
      .order('display_name');
  return List<Map<String, dynamic>>.from(response);
});

/// Provider to fetch music categories (سبک‌های موسیقی)
/// For admin forms, shows ALL categories (including inactive) so admins can manage them
final musicCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('music_categories')
        .select('id, name_fa, name_en, icon, is_active')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching music categories for admin form', error: e);
    rethrow;
  }
});

class AdminUploadAudiobookScreen extends ConsumerStatefulWidget {
  /// Pre-select content type when opening the form (e.g., 'ebook' from ebooks tab)
  final String? initialContentType;

  const AdminUploadAudiobookScreen({super.key, this.initialContentType});

  @override
  ConsumerState<AdminUploadAudiobookScreen> createState() => _AdminUploadAudiobookScreenState();
}

class _AdminUploadAudiobookScreenState extends ConsumerState<AdminUploadAudiobookScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core form controllers
  final _titleFaController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _descriptionFaController = TextEditingController();
  final _descriptionEnController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  // BOOK metadata controllers (کتاب صوتی)
  final _authorNameController = TextEditingController();
  final _authorNameEnController = TextEditingController();
  final _coAuthorsController = TextEditingController();
  final _translatorController = TextEditingController();
  final _translatorEnController = TextEditingController();
  final _narratorNameController = TextEditingController();
  final _narratorNameEnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publisherEnController = TextEditingController();
  final _publicationYearController = TextEditingController();
  final _isbnController = TextEditingController();
  final _bookArchiveSourceController = TextEditingController();
  final _bookCollectionSourceController = TextEditingController();

  // MUSIC metadata controllers (موسیقی)
  final _artistNameController = TextEditingController();
  final _artistNameEnController = TextEditingController();
  final _featuredArtistsController = TextEditingController();
  final _composerController = TextEditingController();
  final _composerEnController = TextEditingController();
  final _lyricistController = TextEditingController();
  final _lyricistEnController = TextEditingController();
  final _producerController = TextEditingController();
  final _archiveSourceController = TextEditingController();
  final _collectionSourceController = TextEditingController();
  final _albumTitleController = TextEditingController();
  final _albumTitleEnController = TextEditingController();
  final _labelController = TextEditingController();
  final _labelEnController = TextEditingController();
  final _genreController = TextEditingController();
  final _genreEnController = TextEditingController();
  final _releaseYearController = TextEditingController();

  // Note: Legacy author/translator columns are now filled from the new metadata controllers
  // For books: _authorNameController -> author_fa, _translatorController -> translator_fa
  // For music: _artistNameController -> author_fa

  // State
  String? _selectedNarratorId;
  int? _selectedCategoryId;
  int? _selectedMusicCategoryId; // For music: single category (changed from List)
  bool _isFree = true;
  bool _isMusic = false; // Content type: false = audiobook, true = music
  bool _isPodcast = false; // Content type: true = podcast
  bool _isArticle = false; // Content type: true = article (narrated article)
  bool _isEbook = false; // Content type: true = ebook
  bool _isParastoBrand = true; // Default to Parasto brand (narrator optional)
  bool _isLoading = false;
  bool _isUploading = false; // For ebook EPUB upload progress
  String? _uploadProgress; // Upload progress message
  String? _error;

  // Cover image
  Uint8List? _coverImageBytes;
  String? _coverFileName;

  // Ebook-specific fields
  Uint8List? _epubBytes;
  String? _epubFileName;
  final _subtitleFaController = TextEditingController();
  final _pageCountController = TextEditingController();
  // Note: _publicationYearController already exists in book metadata section

  // Expansion panel states (for collapsible sections)
  bool _bookMetadataExpanded = false;
  bool _musicMetadataExpanded = false;

  /// Computed content type string from boolean state flags
  String get _contentType {
    if (_isMusic) return 'music';
    if (_isPodcast) return 'podcast';
    if (_isArticle) return 'article';
    if (_isEbook) return 'ebook';
    return 'audiobook';
  }

  /// Whether the selected type is an audio format (has chapters/tracks)
  bool get _isAudioType => !_isEbook;

  @override
  void initState() {
    super.initState();
    // Apply initial content type if provided
    final initial = widget.initialContentType;
    if (initial != null) {
      switch (initial) {
        case 'music':
          _isMusic = true;
        case 'podcast':
          _isPodcast = true;
        case 'article':
          _isArticle = true;
        case 'ebook':
          _isEbook = true;
        default:
          break; // 'audiobook' or anything else = default state
      }
    }
  }

  @override
  void dispose() {
    // Core controllers
    _titleFaController.dispose();
    _titleEnController.dispose();
    _descriptionFaController.dispose();
    _descriptionEnController.dispose();
    _priceController.dispose();

    // Book metadata controllers
    _authorNameController.dispose();
    _authorNameEnController.dispose();
    _coAuthorsController.dispose();
    _translatorController.dispose();
    _translatorEnController.dispose();
    _narratorNameController.dispose();
    _narratorNameEnController.dispose();
    _publisherController.dispose();
    _publisherEnController.dispose();
    _publicationYearController.dispose();
    _isbnController.dispose();
    _bookArchiveSourceController.dispose();
    _bookCollectionSourceController.dispose();

    // Music metadata controllers
    _artistNameController.dispose();
    _artistNameEnController.dispose();
    _featuredArtistsController.dispose();
    _composerController.dispose();
    _composerEnController.dispose();
    _lyricistController.dispose();
    _lyricistEnController.dispose();
    _producerController.dispose();
    _archiveSourceController.dispose();
    _collectionSourceController.dispose();
    _albumTitleController.dispose();
    _albumTitleEnController.dispose();
    _labelController.dispose();
    _labelEnController.dispose();
    _genreController.dispose();
    _genreEnController.dispose();
    _releaseYearController.dispose();

    // Ebook controllers
    _subtitleFaController.dispose();
    _pageCountController.dispose();

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

  Future<void> _pickEpub() async {
    try {
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
    } catch (e) {
      setState(() => _error = 'خطا در انتخاب فایل EPUB: $e');
    }
  }

  Future<String?> _uploadCoverImage() async {
    if (_coverImageBytes == null || _coverFileName == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _coverFileName!.split('.').last;
    // Use narrator ID if selected, otherwise use 'parasto' folder
    final folder = _selectedNarratorId ?? 'parasto';
    final path = '$folder/$timestamp.$extension';

    try {
      await Supabase.instance.client.storage
          .from(Env.coversBucket)
          .uploadBinary(path, _coverImageBytes!);

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
    if (!_formKey.currentState!.validate()) return;

    // Content-type-specific validation
    if (!_isMusic && !_isEbook && _selectedCategoryId == null) {
      setState(() => _error = 'لطفاً دسته‌بندی را انتخاب کنید');
      return;
    }

    if (_isMusic && _selectedMusicCategoryId == null) {
      setState(() => _error = 'لطفاً سبک موسیقی را انتخاب کنید');
      return;
    }

    if (_isEbook && _selectedCategoryId == null) {
      setState(() => _error = 'لطفاً دسته‌بندی را انتخاب کنید');
      return;
    }

    if (_isEbook && _epubBytes == null) {
      setState(() => _error = 'لطفاً فایل EPUB را انتخاب کنید');
      return;
    }

    if (_coverImageBytes == null) {
      setState(() => _error = _isMusic ? 'لطفاً کاور را انتخاب کنید' : 'لطفاً تصویر جلد را انتخاب کنید');
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = _isEbook; // Show upload progress for ebooks (EPUB upload can be slow)
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Upload cover image
      String? coverUrl;

      if (_isEbook) {
        // Ebook covers go to ebook-files bucket (matching existing ebook rows)
        setState(() => _uploadProgress = 'آپلود تصویر جلد...');
        coverUrl = await _uploadEbookCover();
      } else {
        coverUrl = await _uploadCoverImage();
      }

      if (coverUrl == null) {
        throw Exception(_isMusic ? 'خطا در آپلود کاور' : 'خطا در آپلود تصویر جلد');
      }

      // 2. Upload EPUB file (ebooks only)
      String? epubStoragePath;
      if (_isEbook && _epubBytes != null) {
        setState(() => _uploadProgress = 'آپلود فایل EPUB...');
        final userId = supabase.auth.currentUser?.id ?? 'admin';
        final epubUniqueId = '${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}';
        final epubPath = 'epubs/$epubUniqueId.epub';

        await supabase.storage.from('ebook-files').uploadBinary(
          epubPath,
          _epubBytes!,
          fileOptions: const FileOptions(contentType: 'application/epub+zip'),
        );

        epubStoragePath = epubPath;
        AppLogger.i('EPUB uploaded to: $epubPath (${(_epubBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB)');
      }

      setState(() => _uploadProgress = 'ذخیره اطلاعات...');

      // 3. Create audiobook record - with orphan file cleanup on failure
      final price = _isFree ? 0 : int.tryParse(_priceController.text) ?? 0;

      // Get current admin's user ID
      final adminId = supabase.auth.currentUser?.id;

      // For legacy compatibility, map new metadata fields to old author/translator columns
      final legacyAuthorFa = _isMusic
          ? _artistNameController.text.trim()
          : _authorNameController.text.trim();
      final legacyAuthorEn = _isMusic
          ? _artistNameEnController.text.trim()
          : _authorNameEnController.text.trim();
      final legacyTranslatorFa = _isMusic
          ? null
          : _translatorController.text.trim();
      final legacyTranslatorEn = _isMusic
          ? null
          : _translatorEnController.text.trim();

      // Extract cover path from URL for potential cleanup
      String? coverPath;
      if (!_isEbook) {
        try {
          final uri = Uri.parse(coverUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('audiobook-covers');
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            coverPath = pathSegments.sublist(bucketIndex + 1).join('/');
          }
        } catch (_) {}
      }

      Map<String, dynamic>? response;
      try {
        // Build base data for insert
        final insertData = <String, dynamic>{
          'title_fa': _titleFaController.text.trim(),
          'title_en': _titleEnController.text.trim().isEmpty
              ? null
              : _titleEnController.text.trim(),
          // Legacy columns (for backwards compatibility)
          'author_fa': legacyAuthorFa.isEmpty ? null : legacyAuthorFa,
          'author_en': legacyAuthorEn.isEmpty ? null : legacyAuthorEn,
          'translator_fa': legacyTranslatorFa?.isEmpty ?? true ? null : legacyTranslatorFa,
          'translator_en': legacyTranslatorEn?.isEmpty ?? true ? null : legacyTranslatorEn,
          'description_fa': _descriptionFaController.text.trim(),
          'description_en': _descriptionEnController.text.trim().isEmpty
              ? null
              : _descriptionEnController.text.trim(),
          'category_id': _isMusic ? null : _selectedCategoryId,
          'narrator_id': _isEbook ? null : (_selectedNarratorId ?? adminId),
          'cover_url': coverUrl,
          'price_toman': price,
          'is_free': _isFree,
          // content_type is the new source of truth for type detection
          'content_type': _contentType,
          // Keep boolean flags for backward compatibility
          'is_music': _isMusic,
          'is_parasto_brand': _isEbook ? false : _isParastoBrand,
          'status': 'draft',
          'language': 'fa',
          'chapter_count': 0,
          'total_duration_seconds': 0,
          'play_count': 0,
          'purchase_count': 0,
          'review_count': 0,
          'is_featured': false,
        };

        // Ebook-specific columns
        if (_isEbook) {
          insertData['subtitle_fa'] = _subtitleFaController.text.trim().isEmpty
              ? null : _subtitleFaController.text.trim();
          insertData['epub_storage_path'] = epubStoragePath;
          insertData['page_count'] = int.tryParse(_pageCountController.text) ?? 0;
          insertData['publisher_fa'] = _publisherController.text.trim().isEmpty
              ? null : _publisherController.text.trim();
          insertData['isbn'] = _isbnController.text.trim().isEmpty
              ? null : _isbnController.text.trim();
          insertData['publication_year'] = _publicationYearController.text.trim().isEmpty
              ? null : int.tryParse(_publicationYearController.text.trim());
          if (_epubBytes != null) {
            insertData['file_size_bytes'] = _epubBytes!.length;
          }
          insertData['uploader_id'] = adminId;
        }

        // Insert with is_podcast and is_article columns (backward compat)
        try {
          response = await supabase
              .from('audiobooks')
              .insert({...insertData, 'is_podcast': _isPodcast, 'is_article': _isArticle})
              .select()
              .maybeSingle();
        } catch (columnError) {
          // If new columns don't exist yet, retry without them
          final errorStr = columnError.toString().toLowerCase();
          if (errorStr.contains('is_podcast') || errorStr.contains('is-podcast') ||
              errorStr.contains('is_article') || errorStr.contains('is-article') ||
              errorStr.contains('pgrst204') || errorStr.contains('42703')) {
            AppLogger.w('New columns not found, inserting without them');
            response = await supabase
                .from('audiobooks')
                .insert(insertData)
                .select()
                .maybeSingle();
          } else {
            rethrow;
          }
        }
      } catch (dbError) {
        // DB insert failed - clean up orphan cover file from storage
        if (coverPath != null) {
          AppLogger.w('Admin audiobook DB insert failed, cleaning up cover: $coverPath');
          try {
            await supabase.storage.from(Env.coversBucket).remove([coverPath]);
          } catch (cleanupError) {
            AppLogger.e('Failed to cleanup orphan cover: $coverPath', error: cleanupError);
          }
        }
        rethrow;
      }

      if (response == null) {
        throw Exception('Failed to create content');
      }
      final audiobookId = response['id'] as int?;
      final audiobookTitle = (response['title_fa'] as String?) ?? '';

      AppLogger.i('Admin created $_contentType with ID: $audiobookId');

      if (audiobookId == null || audiobookId <= 0) {
        throw Exception('شناسه محتوا برگردانده نشد');
      }

      // 4. Insert into book_metadata or music_metadata table
      if (!_isEbook) {
        // Ebooks store their metadata directly in the audiobooks row (author_fa, publisher_fa, etc.)
        try {
          if (_isMusic) {
            // Insert music metadata
            await supabase
                .from('music_metadata')
                .insert({
                  'audiobook_id': audiobookId,
                  'artist_name': _artistNameController.text.trim().isEmpty
                      ? null : _artistNameController.text.trim(),
                  'artist_name_en': _artistNameEnController.text.trim().isEmpty
                      ? null : _artistNameEnController.text.trim(),
                  'featured_artists': _featuredArtistsController.text.trim().isEmpty
                      ? null : _featuredArtistsController.text.trim(),
                  'composer': _composerController.text.trim().isEmpty
                      ? null : _composerController.text.trim(),
                  'composer_en': _composerEnController.text.trim().isEmpty
                      ? null : _composerEnController.text.trim(),
                  'lyricist': _lyricistController.text.trim().isEmpty
                      ? null : _lyricistController.text.trim(),
                  'lyricist_en': _lyricistEnController.text.trim().isEmpty
                      ? null : _lyricistEnController.text.trim(),
                  'producer': _producerController.text.trim().isEmpty
                      ? null : _producerController.text.trim(),
                  'album_title': _albumTitleController.text.trim().isEmpty
                      ? null : _albumTitleController.text.trim(),
                  'album_title_en': _albumTitleEnController.text.trim().isEmpty
                      ? null : _albumTitleEnController.text.trim(),
                  'label': _labelController.text.trim().isEmpty
                      ? null : _labelController.text.trim(),
                  'label_en': _labelEnController.text.trim().isEmpty
                      ? null : _labelEnController.text.trim(),
                  'genre': _genreController.text.trim().isEmpty
                      ? null : _genreController.text.trim(),
                  'genre_en': _genreEnController.text.trim().isEmpty
                      ? null : _genreEnController.text.trim(),
                  'release_year': _releaseYearController.text.trim().isEmpty
                      ? null : int.tryParse(_releaseYearController.text.trim()),
                  'archive_source': _archiveSourceController.text.trim().isEmpty
                      ? null : _archiveSourceController.text.trim(),
                  'collection_source': _collectionSourceController.text.trim().isEmpty
                      ? null : _collectionSourceController.text.trim(),
                })
                .select()
                .single();
            AppLogger.i('Music metadata inserted for audiobook $audiobookId');
          } else {
            // Insert book metadata
            await supabase
                .from('book_metadata')
                .insert({
                  'audiobook_id': audiobookId,
                  'author_name': _authorNameController.text.trim().isEmpty
                      ? null : _authorNameController.text.trim(),
                  'author_name_en': _authorNameEnController.text.trim().isEmpty
                      ? null : _authorNameEnController.text.trim(),
                  'co_authors': _coAuthorsController.text.trim().isEmpty
                      ? null : _coAuthorsController.text.trim(),
                  'translator': _translatorController.text.trim().isEmpty
                      ? null : _translatorController.text.trim(),
                  'translator_en': _translatorEnController.text.trim().isEmpty
                      ? null : _translatorEnController.text.trim(),
                  'narrator_name': _narratorNameController.text.trim().isEmpty
                      ? null : _narratorNameController.text.trim(),
                  'narrator_name_en': _narratorNameEnController.text.trim().isEmpty
                      ? null : _narratorNameEnController.text.trim(),
                  'publisher': _publisherController.text.trim().isEmpty
                      ? null : _publisherController.text.trim(),
                  'publisher_en': _publisherEnController.text.trim().isEmpty
                      ? null : _publisherEnController.text.trim(),
                  'publication_year': _publicationYearController.text.trim().isEmpty
                      ? null : int.tryParse(_publicationYearController.text.trim()),
                  'isbn': _isbnController.text.trim().isEmpty
                      ? null : _isbnController.text.trim(),
                  'archive_source': _bookArchiveSourceController.text.trim().isEmpty
                      ? null : _bookArchiveSourceController.text.trim(),
                  'collection_source': _bookCollectionSourceController.text.trim().isEmpty
                      ? null : _bookCollectionSourceController.text.trim(),
                })
                .select()
                .single();
            AppLogger.i('Book metadata inserted for audiobook $audiobookId');
          }
        } catch (metadataError) {
          AppLogger.e('Failed to insert metadata for audiobook $audiobookId', error: metadataError);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('هشدار: اطلاعات تکمیلی ذخیره نشد. بعداً از ویرایش استفاده کنید.'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      }

      // 5. If music, insert music category association (single category)
      if (_isMusic && _selectedMusicCategoryId != null) {
        try {
          await supabase
              .from('audiobook_music_categories')
              .insert({
                'audiobook_id': audiobookId,
                'music_category_id': _selectedMusicCategoryId,
              })
              .select()
              .single();
        } catch (categoryError) {
          AppLogger.e('Failed to insert music category for audiobook $audiobookId', error: categoryError);
        }
      }

      // 6. Auto-sync creators from metadata fields (not for ebooks — ebook creators are in author_fa directly)
      if (!_isEbook) {
        final creatorService = CreatorService();
        await creatorService.syncCreatorsForAudiobook(
          audiobookId: audiobookId,
          contentType: _isMusic ? 'music' : 'audiobook',
          authorName: _isMusic ? null : _authorNameController.text,
          authorNameEn: _isMusic ? null : _authorNameEnController.text,
          translatorName: _isMusic ? null : _translatorController.text,
          translatorNameEn: _isMusic ? null : _translatorEnController.text,
          narratorName: _isMusic ? null : _narratorNameController.text,
          narratorNameEn: _isMusic ? null : _narratorNameEnController.text,
          publisherName: _isMusic ? null : _publisherController.text,
          publisherNameEn: _isMusic ? null : _publisherEnController.text,
          artistName: _isMusic ? _artistNameController.text : null,
          artistNameEn: _isMusic ? _artistNameEnController.text : null,
          composerName: _isMusic ? _composerController.text : null,
          composerNameEn: _isMusic ? _composerEnController.text : null,
          lyricistName: _isMusic ? _lyricistController.text : null,
          lyricistNameEn: _isMusic ? _lyricistEnController.text : null,
          labelName: _isMusic ? _labelController.text : null,
          labelNameEn: _isMusic ? _labelEnController.text : null,
        );
        AppLogger.i('Creator sync completed for audiobook $audiobookId');
      }

      // 7. Show success and navigate
      if (mounted) {
        if (_isEbook) {
          // Ebooks: show success and pop back (no chapter management)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('کتاب با موفقیت ایجاد شد'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        } else {
          // Audio content: navigate to bulk chapter upload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(switch (_contentType) {
                'music' => 'موسیقی با موفقیت ایجاد شد. حالا فایل‌ها را اضافه کنید.',
                'podcast' => 'پادکست با موفقیت ایجاد شد. حالا قسمت‌ها را اضافه کنید.',
                'article' => 'مقاله با موفقیت ایجاد شد. حالا فایل را اضافه کنید.',
                _ => 'کتاب صوتی با موفقیت ایجاد شد. حالا فصل‌ها را اضافه کنید.',
              }),
              backgroundColor: AppColors.success,
            ),
          );

          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (context) => AdminBulkChapterUploadScreen(
                audiobookId: audiobookId,
                audiobookTitle: audiobookTitle,
                narratorId: _selectedNarratorId ?? adminId ?? '',
              ),
            ),
          );

          if (result == true && mounted) {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      AppLogger.e('Submit error', error: e);
      setState(() => _error = e.toString());
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

  /// Upload ebook cover to ebook-files bucket (matching existing ebook cover storage)
  Future<String?> _uploadEbookCover() async {
    if (_coverImageBytes == null || _coverFileName == null) return null;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'admin';
    final ext = _coverFileName!.split('.').last.toLowerCase();
    final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}';
    final coverPath = 'covers/$uniqueId.$ext';

    // Map file extension to proper MIME type
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    try {
      await Supabase.instance.client.storage.from('ebook-files').uploadBinary(
        coverPath,
        _coverImageBytes!,
        fileOptions: FileOptions(contentType: mimeType),
      );

      // Try signed URL first (ebook-files bucket may be private), fallback to public URL
      String coverUrl;
      try {
        coverUrl = await Supabase.instance.client.storage
            .from('ebook-files')
            .createSignedUrl(coverPath, 60 * 60 * 24 * 365 * 10); // 10 years
      } catch (e) {
        coverUrl = Supabase.instance.client.storage
            .from('ebook-files')
            .getPublicUrl(coverPath);
      }

      return coverUrl;
    } catch (e) {
      AppLogger.e('Ebook cover upload error', error: e);
      throw Exception('خطا در آپلود تصویر جلد');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(formCategoriesProvider);
    final narratorsAsync = ref.watch(narratorsProvider);
    final musicCategoriesAsync = ref.watch(musicCategoriesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(switch (_contentType) {
            'music' => 'آپلود موسیقی (ادمین)',
            'ebook' => 'آپلود کتاب (ادمین)',
            'podcast' => 'آپلود پادکست (ادمین)',
            'article' => 'آپلود مقاله (ادمین)',
            _ => 'آپلود کتاب صوتی (ادمین)',
          }),
          centerTitle: true,
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
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Content Type Toggle (Book vs Music) - First!
                _buildContentTypeToggle(),
                const SizedBox(height: 20),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(_isEbook ? Icons.auto_stories : (_isMusic ? Icons.music_note : Icons.admin_panel_settings), color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isParastoBrand
                              ? 'این محتوا به نام «پرستو» منتشر می‌شود'
                              : 'آپلود به نمایندگی از گوینده انتخابی',
                          style: const TextStyle(color: AppColors.primary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Parasto Brand Toggle - Important decision first (not for ebooks)
                if (_isAudioType) ...[
                  _buildParastoBrandToggle(),
                  const SizedBox(height: 16),

                  // Narrator selector (optional, only show if not Parasto brand)
                  if (!_isParastoBrand) ...[
                    narratorsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('خطا در بارگذاری گویندگان: $e'),
                      data: _buildNarratorSelector,
                    ),
                    const SizedBox(height: 20),
                  ],
                ],

                // Cover Image Picker
                _buildCoverPicker(),
                const SizedBox(height: 24),

                // Persian Title (Required)
                TextFormField(
                  controller: _titleFaController,
                  decoration: InputDecoration(
                    labelText: 'عنوان فارسی *',
                    hintText: _isMusic ? 'مثال: آهنگ زیبا' : (_isEbook ? 'مثال: شازده کوچولو' : 'مثال: شازده کوچولو'),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'عنوان فارسی الزامی است';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Ebook-specific fields: subtitle, EPUB picker, page count
                if (_isEbook) ...[
                  // Subtitle (Farsi)
                  TextFormField(
                    controller: _subtitleFaController,
                    decoration: const InputDecoration(
                      labelText: 'زیرعنوان (اختیاری)',
                      hintText: 'مثال: داستان بلند',
                      prefixIcon: Icon(Icons.subtitles),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // EPUB file picker
                  _buildEpubPicker(),
                  const SizedBox(height: 16),

                  // Page count
                  TextFormField(
                    controller: _pageCountController,
                    decoration: const InputDecoration(
                      labelText: 'تعداد صفحات',
                      hintText: 'مثال: ۲۴۰',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                ],

                // Author/Artist Section (dynamic based on content type)
                _buildAuthorArtistSection(),
                const SizedBox(height: 16),

                // Category Selection - Different for books vs music
                if (_isMusic) ...[
                  // Music Categories (multi-select)
                  musicCategoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('خطا در بارگذاری سبک‌ها: $e'),
                    data: _buildMusicCategoriesSelector,
                  ),
                ] else ...[
                  // Book Category Dropdown (single select)
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
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Persian Description
                TextFormField(
                  controller: _descriptionFaController,
                  decoration: InputDecoration(
                    labelText: 'توضیحات فارسی *',
                    hintText: _isMusic ? 'درباره این موسیقی بنویسید...' : (_isEbook ? 'درباره کتاب بنویسید...' : 'درباره کتاب بنویسید...'),
                    prefixIcon: const Icon(Icons.description),
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
                const SizedBox(height: 24),

                // Free/Paid Toggle
                _buildPricingSection(),
                const SizedBox(height: 24),

                // Error Message
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
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
                      : Text(
                          _isEbook ? 'ذخیره کتاب' : 'ذخیره و افزودن فصل‌ها',
                          style: const TextStyle(fontSize: 16),
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

  Widget _buildNarratorSelector(List<Map<String, dynamic>> narrators) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'انتخاب گوینده (اختیاری)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedNarratorId != null
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: narrators.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'هیچ گوینده‌ای یافت نشد',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: _selectedNarratorId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('گوینده را انتخاب کنید'),
                  isExpanded: true,
                  items: narrators.map((narrator) {
                    final displayName = (narrator['display_name'] as String?) ??
                        (narrator['full_name'] as String?) ??
                        'بدون نام';
                    final email = narrator['email'] as String? ?? '';
                    return DropdownMenuItem<String>(
                      value: narrator['id'] as String,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundImage: narrator['avatar_url'] != null
                                ? NetworkImage(narrator['avatar_url'] as String)
                                : null,
                            child: narrator['avatar_url'] == null
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedNarratorId = value);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(10),
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
                  Text(
                    _isMusic ? 'کاور را انتخاب کنید' : 'تصویر جلد را انتخاب کنید *',
                    style: const TextStyle(
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

  Widget _buildContentTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'نوع محتوا',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // First row: Audiobook, Music, Podcast
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  icon: Icons.headphones,
                  label: 'کتاب صوتی',
                  isSelected: _contentType == 'audiobook',
                  onTap: () => setState(() {
                    _isMusic = false;
                    _isPodcast = false;
                    _isArticle = false;
                    _isEbook = false;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  icon: Icons.music_note,
                  label: 'موسیقی',
                  isSelected: _isMusic,
                  onTap: () => setState(() {
                    _isMusic = true;
                    _isPodcast = false;
                    _isArticle = false;
                    _isEbook = false;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  icon: Icons.podcasts,
                  label: 'پادکست',
                  isSelected: _isPodcast,
                  onTap: () => setState(() {
                    _isMusic = false;
                    _isPodcast = true;
                    _isArticle = false;
                    _isEbook = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row: Article + Ebook
          Row(
            children: [
              // Article option
              Expanded(
                child: _buildTypeOption(
                  icon: Icons.article_rounded,
                  label: 'مقاله',
                  isSelected: _isArticle,
                  onTap: () => setState(() {
                    _isMusic = false;
                    _isPodcast = false;
                    _isArticle = true;
                    _isEbook = false;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              // Ebook option
              Expanded(
                child: _buildTypeOption(
                  icon: Icons.auto_stories_rounded,
                  label: 'کتاب',
                  isSelected: _isEbook,
                  onTap: () => setState(() {
                    _isMusic = false;
                    _isPodcast = false;
                    _isArticle = false;
                    _isEbook = true;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // Spacer to keep layout balanced
            ],
          ),
        ],
      ),
    );
  }

  /// EPUB file picker for ebooks
  Widget _buildEpubPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _epubBytes != null
              ? AppColors.success
              : AppColors.border,
          width: _epubBytes != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _epubBytes != null ? Icons.check_circle : Icons.book,
                color: _epubBytes != null ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'فایل EPUB *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_epubBytes != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _epubFileName ?? 'فایل انتخاب شده',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(_epubBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(_epubBytes != null ? Icons.refresh : Icons.upload_file),
                  label: Text(_epubBytes != null ? 'تغییر فایل' : 'انتخاب فایل EPUB'),
                  onPressed: _pickEpub,
                ),
              ),
              if (_epubBytes != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  onPressed: () => setState(() {
                    _epubBytes = null;
                    _epubFileName = null;
                  }),
                  tooltip: 'حذف',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Reusable content type option button
  Widget _buildTypeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? AppColors.primary : AppColors.textTertiary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParastoBrandToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: _isParastoBrand
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            _isParastoBrand ? Icons.verified : Icons.verified_outlined,
            color: _isParastoBrand ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نمایش به نام پرستو',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _isParastoBrand
                      ? 'این کتاب به نام «پرستو» نمایش داده می‌شود'
                      : 'نام گوینده نمایش داده می‌شود',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isParastoBrand,
            onChanged: (value) {
              setState(() => _isParastoBrand = value);
            },
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
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

  /// Metadata section - different for books vs music vs podcasts vs articles vs ebooks
  Widget _buildAuthorArtistSection() {
    if (_isMusic) {
      return _buildMusicMetadataSection();
    } else if (_isPodcast) {
      return _buildPodcastMetadataSection();
    } else {
      // Books, articles, and ebooks all use book metadata (author, translator, etc.)
      return _buildBookMetadataSection();
    }
  }

  /// Book metadata section (نویسنده، مترجم، گوینده، ناشر، سال نشر)
  Widget _buildBookMetadataSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: _bookMetadataExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _bookMetadataExpanded = expanded;
          });
        },
        leading: const Icon(Icons.menu_book, color: AppColors.primary, size: 20),
        title: const Text(
          'اطلاعات کتاب',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

          // نویسنده - Author
          TextFormField(
            controller: _authorNameController,
            decoration: const InputDecoration(
              labelText: 'نویسنده',
              hintText: 'مثال: آنتوان دو سنت‌اگزوپری',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _coAuthorsController,
            decoration: const InputDecoration(
              labelText: 'نویسندگان همکار (اختیاری)',
              hintText: 'نام‌ها را با کاما جدا کنید',
              prefixIcon: Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 16),

          // مترجم - Translator
          TextFormField(
            controller: _translatorController,
            decoration: const InputDecoration(
              labelText: 'مترجم (اختیاری)',
              hintText: 'مثال: احمد شاملو',
              prefixIcon: Icon(Icons.translate),
            ),
          ),
          const SizedBox(height: 16),

          // گوینده - Narrator (only for audiobooks/articles, not music or ebooks)
          if (!_isMusic && !_isEbook) ...[
            TextFormField(
              controller: _narratorNameController,
              decoration: const InputDecoration(
                labelText: 'گوینده (اختیاری)',
                hintText: 'نام گوینده کتاب صوتی',
                prefixIcon: Icon(Icons.mic),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ناشر - Publisher
          TextFormField(
            controller: _publisherController,
            decoration: const InputDecoration(
              labelText: 'ناشر (اختیاری)',
              hintText: 'مثال: نشر چشمه',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),

          // سال نشر و ISBN
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _publicationYearController,
                  decoration: const InputDecoration(
                    labelText: 'سال نشر',
                    hintText: '۱۴۰۲',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _isbnController,
                  decoration: const InputDecoration(
                    labelText: 'ISBN (اختیاری)',
                    hintText: '978-...',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // از بایگانی - Archive Source (for books)
          TextFormField(
            controller: _bookArchiveSourceController,
            decoration: const InputDecoration(
              labelText: 'از بایگانی (اختیاری)',
              hintText: 'مثال: رادیو ایران',
              prefixIcon: Icon(Icons.archive_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // از آرشیو - Collection Source (for books)
          TextFormField(
            controller: _bookCollectionSourceController,
            decoration: const InputDecoration(
              labelText: 'از آرشیو (اختیاری)',
              hintText: 'مثال: کتابخانه ملی',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Podcast metadata section (میزبان/مجری)
  /// Podcasts have hosts/presenters, not authors or singers
  Widget _buildPodcastMetadataSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: _bookMetadataExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _bookMetadataExpanded = expanded;
          });
        },
        leading: const Icon(Icons.podcasts, color: AppColors.primary, size: 20),
        title: const Text(
          'اطلاعات پادکست',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // میزبان - Host (uses author_fa field in database)
                TextFormField(
                  controller: _authorNameController,
                  decoration: const InputDecoration(
                    labelText: 'میزبان پادکست',
                    hintText: 'نام میزبان یا مجری پادکست',
                    prefixIcon: Icon(Icons.mic),
                  ),
                ),
                const SizedBox(height: 12),
                // همکاران - Co-hosts (uses co_authors field)
                TextFormField(
                  controller: _coAuthorsController,
                  decoration: const InputDecoration(
                    labelText: 'میزبانان همکار (اختیاری)',
                    hintText: 'نام‌ها را با کاما جدا کنید',
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 16),
                // منبع آرشیو - Archive Source
                TextFormField(
                  controller: _bookArchiveSourceController,
                  decoration: const InputDecoration(
                    labelText: 'منبع (اختیاری)',
                    hintText: 'مثال: رادیو فردا',
                    prefixIcon: Icon(Icons.source),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Music metadata section (هنرمند، آهنگساز، شاعر، آلبوم، سبک، سال انتشار)
  Widget _buildMusicMetadataSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: _musicMetadataExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _musicMetadataExpanded = expanded;
          });
        },
        leading: const Icon(Icons.music_note, color: AppColors.primary, size: 20),
        title: const Text(
          'اطلاعات موسیقی',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

          // هنرمند / خواننده - Artist
          TextFormField(
            controller: _artistNameController,
            decoration: const InputDecoration(
              labelText: 'هنرمند / خواننده',
              hintText: 'مثال: محسن چاوشی',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _featuredArtistsController,
            decoration: const InputDecoration(
              labelText: 'هنرمندان مهمان (اختیاری)',
              hintText: 'نام‌ها را با کاما جدا کنید',
              prefixIcon: Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 16),

          // آهنگساز - Composer
          TextFormField(
            controller: _composerController,
            decoration: const InputDecoration(
              labelText: 'آهنگساز (اختیاری)',
              hintText: 'مثال: محمدرضا شجریان',
              prefixIcon: Icon(Icons.piano),
            ),
          ),
          const SizedBox(height: 16),

          // شاعر / ترانه‌سرا - Lyricist
          TextFormField(
            controller: _lyricistController,
            decoration: const InputDecoration(
              labelText: 'شاعر / ترانه‌سرا (اختیاری)',
              hintText: 'مثال: حافظ شیرازی',
              prefixIcon: Icon(Icons.text_fields),
            ),
          ),
          const SizedBox(height: 16),

          // تهیه‌کننده - Producer
          TextFormField(
            controller: _producerController,
            decoration: const InputDecoration(
              labelText: 'تهیه‌کننده (اختیاری)',
              hintText: 'مثال: حمید متبسم',
              prefixIcon: Icon(Icons.settings_voice),
            ),
          ),
          const SizedBox(height: 16),

          // از بایگانی - Archive Source
          TextFormField(
            controller: _archiveSourceController,
            decoration: const InputDecoration(
              labelText: 'از بایگانی (اختیاری)',
              hintText: 'مثال: موسیقی ایرانی',
              prefixIcon: Icon(Icons.archive_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // از آرشیو - Collection Source
          TextFormField(
            controller: _collectionSourceController,
            decoration: const InputDecoration(
              labelText: 'از آرشیو (اختیاری)',
              hintText: 'مثال: استاد شجریان',
              prefixIcon: Icon(Icons.library_books_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // آلبوم / مجموعه - Album
          TextFormField(
            controller: _albumTitleController,
            decoration: const InputDecoration(
              labelText: 'آلبوم / مجموعه (اختیاری)',
              hintText: 'مثال: آلبوم امشب',
              prefixIcon: Icon(Icons.album),
            ),
          ),
          const SizedBox(height: 16),

          // ناشر / استودیو - Label
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'ناشر / استودیو (اختیاری)',
              hintText: 'مثال: استودیو آوا',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),

          // سبک - Genre (text, supplementary to music_categories)
          TextFormField(
            controller: _genreController,
            decoration: const InputDecoration(
              labelText: 'سبک اصلی (اختیاری)',
              hintText: 'مثال: پاپ فارسی',
              prefixIcon: Icon(Icons.style),
            ),
          ),
          const SizedBox(height: 16),

          // سال انتشار - Release Year
          TextFormField(
            controller: _releaseYearController,
            decoration: const InputDecoration(
              labelText: 'سال انتشار (اختیاری)',
              hintText: '۱۴۰۲',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            keyboardType: TextInputType.number,
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Single-select music category dropdown (سبک موسیقی)
  Widget _buildMusicCategoriesSelector(List<Map<String, dynamic>> categories) {
    return DropdownButtonFormField<int>(
      value: _selectedMusicCategoryId,
      decoration: const InputDecoration(
        labelText: 'سبک موسیقی *',
        prefixIcon: Icon(Icons.music_note),
        helperText: 'هر اثر موسیقی فقط می‌تواند یک سبک داشته باشد',
        helperMaxLines: 2,
      ),
      items: categories.map((cat) {
        return DropdownMenuItem<int>(
          value: cat['id'] as int,
          child: Text((cat['name_fa'] as String?) ?? ''),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedMusicCategoryId = value);
      },
      validator: (value) {
        if (value == null) return 'انتخاب سبک موسیقی الزامی است';
        return null;
      },
    );
  }
}
