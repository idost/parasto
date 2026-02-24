import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/screens/admin/admin_chapter_management_screen.dart';
import 'package:myna/widgets/admin/audiobook_creators_sheet.dart';
import 'package:myna/services/creator_service.dart';
import 'package:myna/widgets/common/multi_field_input.dart';

class AdminEditAudiobookScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> audiobook;
  final VoidCallback onUpdate;

  const AdminEditAudiobookScreen({
    super.key,
    required this.audiobook,
    required this.onUpdate,
  });

  @override
  ConsumerState<AdminEditAudiobookScreen> createState() => _AdminEditAudiobookScreenState();
}

class _AdminEditAudiobookScreenState extends ConsumerState<AdminEditAudiobookScreen> {
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
  final _priceController = TextEditingController();

  // Music metadata controllers
  final _artistController = TextEditingController();
  final _featuredArtistsController = TextEditingController();
  final _composerController = TextEditingController();
  final _lyricistController = TextEditingController();
  final _producerController = TextEditingController();
  final _archiveSourceController = TextEditingController();
  final _collectionSourceController = TextEditingController();
  final _albumController = TextEditingController();
  final _labelController = TextEditingController();
  final _genreController = TextEditingController();
  final _releaseYearController = TextEditingController();

  // Book metadata controllers (for additional fields beyond legacy columns)
  final _bookPublisherController = TextEditingController();       // ناشر
  final _bookArchiveController = TextEditingController();         // آرشیف
  final _bookCollectionController = TextEditingController();      // بایگانی
  final _coAuthorsController = TextEditingController();           // نویسندگان همکار
  final _publicationYearController = TextEditingController();     // سال نشر
  final _isbnController = TextEditingController();                // شابک
  List<String> _narratorNames = [];  // گوینده - for MultiFieldInput

  // State
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _musicCategories = []; // Available music categories
  int? _selectedMusicCategoryId; // Selected music category ID (single select)
  bool _isFree = true;
  bool _isFeatured = false;
  bool _isParastoBrand = false; // Show as "پرستو" brand instead of narrator name
  bool _isMusic = false; // Content type: false = audiobook, true = music
  bool _isPodcast = false; // Content type: true = podcast
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSyncingCreators = false; // For manual creator sync button
  String? _error;

  // Cover image
  Uint8List? _newCoverBytes;
  String? _newCoverFileName;
  String? _existingCoverUrl;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadCategories();
    if (_isMusic) {
      _loadMusicMetadata();
    } else {
      _loadBookMetadata();
    }
  }

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
    // Music metadata controllers
    _artistController.dispose();
    _featuredArtistsController.dispose();
    _composerController.dispose();
    _lyricistController.dispose();
    _producerController.dispose();
    _archiveSourceController.dispose();
    _collectionSourceController.dispose();
    _albumController.dispose();
    _labelController.dispose();
    _genreController.dispose();
    _releaseYearController.dispose();
    // Book metadata controllers
    _bookPublisherController.dispose();
    _bookArchiveController.dispose();
    _bookCollectionController.dispose();
    _coAuthorsController.dispose();
    _publicationYearController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    final audiobook = widget.audiobook;
    _titleFaController.text = (audiobook['title_fa'] as String?) ?? '';
    _titleEnController.text = (audiobook['title_en'] as String?) ?? '';
    _authorFaController.text = (audiobook['author_fa'] as String?) ?? '';
    _authorEnController.text = (audiobook['author_en'] as String?) ?? '';
    _translatorFaController.text = (audiobook['translator_fa'] as String?) ?? '';
    _translatorEnController.text = (audiobook['translator_en'] as String?) ?? '';
    _descriptionFaController.text = (audiobook['description_fa'] as String?) ?? '';
    _descriptionEnController.text = (audiobook['description_en'] as String?) ?? '';
    _selectedCategoryId = audiobook['category_id'] as int?;
    _isFree = (audiobook['is_free'] as bool?) ?? true;
    _isFeatured = (audiobook['is_featured'] as bool?) ?? false;
    _isParastoBrand = (audiobook['is_parasto_brand'] as bool?) ?? false;
    _isMusic = (audiobook['is_music'] as bool?) ?? false;
    _isPodcast = (audiobook['is_podcast'] as bool?) ?? false;
    _priceController.text = ((audiobook['price_toman'] as int?) ?? 0).toString();
    _existingCoverUrl = audiobook['cover_url'] as String?;
  }

  Future<void> _loadCategories() async {
    try {
      if (_isMusic) {
        // Load music categories (all, including inactive, for admin management)
        final musicCats = await Supabase.instance.client
            .from('music_categories')
            .select('id, name_fa, name_en, icon, is_active')
            .order('sort_order');

        // Load currently selected music categories for this audiobook
        final selectedCats = await Supabase.instance.client
            .from('audiobook_music_categories')
            .select('music_category_id')
            .eq('audiobook_id', widget.audiobook['id'] as int);

        setState(() {
          _musicCategories = List<Map<String, dynamic>>.from(musicCats);
          // Get the single selected category (if any)
          if ((selectedCats as List).isNotEmpty) {
            _selectedMusicCategoryId = selectedCats.first['music_category_id'] as int;
          }
          _isLoading = false;
        });
      } else {
        // Load book categories (existing logic)
        final categories = await Supabase.instance.client
            .from('categories')
            .select('id, name_fa, name_en')
            .eq('is_active', true)
            .order('sort_order');

        setState(() {
          _categories = List<Map<String, dynamic>>.from(categories);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _isMusic
            ? 'خطا در بارگذاری سبک‌های موسیقی: $e'
            : 'خطا در بارگذاری دسته‌بندی‌ها: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMusicMetadata() async {
    if (!_isMusic) return;

    try {
      final metadata = await Supabase.instance.client
          .from('music_metadata')
          .select('*')
          .eq('audiobook_id', widget.audiobook['id'] as int)
          .maybeSingle();

      if (metadata != null) {
        setState(() {
          _artistController.text = (metadata['artist_name'] as String?) ?? '';
          _featuredArtistsController.text = (metadata['featured_artists'] as String?) ?? '';
          _composerController.text = (metadata['composer'] as String?) ?? '';
          _lyricistController.text = (metadata['lyricist'] as String?) ?? '';
          _producerController.text = (metadata['producer'] as String?) ?? '';
          _archiveSourceController.text = (metadata['archive_source'] as String?) ?? '';
          _collectionSourceController.text = (metadata['collection_source'] as String?) ?? '';
          _albumController.text = (metadata['album_title'] as String?) ?? '';
          _labelController.text = (metadata['label'] as String?) ?? '';
          _genreController.text = (metadata['genre'] as String?) ?? '';
          _releaseYearController.text = metadata['release_year']?.toString() ?? '';
        });
      }
    } catch (e) {
      AppLogger.e('Error loading music metadata', error: e);
      // Don't show error to user, just log it - music_metadata might not exist yet
    }
  }

  /// Load book_metadata for audiobooks (is_music = false)
  Future<void> _loadBookMetadata() async {
    if (_isMusic) return;

    try {
      final metadata = await Supabase.instance.client
          .from('book_metadata')
          .select('*')
          .eq('audiobook_id', widget.audiobook['id'] as int)
          .maybeSingle();

      if (metadata != null) {
        setState(() {
          // Parse narrator names (comma-separated) into list for MultiFieldInput
          final narratorName = metadata['narrator_name'] as String?;
          if (narratorName != null && narratorName.isNotEmpty) {
            _narratorNames = narratorName.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          }

          _bookPublisherController.text = (metadata['publisher'] as String?) ?? '';
          _bookArchiveController.text = (metadata['archive_source'] as String?) ?? '';
          _bookCollectionController.text = (metadata['collection_source'] as String?) ?? '';
          _coAuthorsController.text = (metadata['co_authors'] as String?) ?? '';
          final pubYear = metadata['publication_year'] as int?;
          _publicationYearController.text = pubYear != null ? pubYear.toString() : '';
          _isbnController.text = (metadata['isbn'] as String?) ?? '';
        });
      }
    } catch (e) {
      AppLogger.e('Error loading book metadata', error: e);
      // Don't show error to user, just log it - book_metadata might not exist yet
    }
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
          _newCoverBytes = bytes;
          _newCoverFileName = image.name;
        });
      }
    } catch (e) {
      setState(() => _error = 'خطا در انتخاب تصویر: $e');
    }
  }

  Future<String?> _uploadNewCover() async {
    if (_newCoverBytes == null || _newCoverFileName == null) return null;

    final narratorId = widget.audiobook['narrator_id'] as String?;
    if (narratorId == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _newCoverFileName!.split('.').last;
    final path = '$narratorId/$timestamp.$extension';

    try {
      await Supabase.instance.client.storage
          .from('audiobook-covers')
          .uploadBinary(path, _newCoverBytes!);

      return Supabase.instance.client.storage
          .from('audiobook-covers')
          .getPublicUrl(path);
    } catch (e) {
      AppLogger.e('Cover upload error', error: e);
      throw Exception('خطا در آپلود تصویر جدید');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate music category (single select)
    if (_isMusic && _selectedMusicCategoryId == null) {
      setState(() => _error = 'لطفاً یک سبک موسیقی انتخاب کنید');
      return;
    }

    // Validate book category
    if (!_isMusic && _selectedCategoryId == null) {
      setState(() => _error = 'لطفاً دسته‌بندی را انتخاب کنید');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      String? coverUrl = _existingCoverUrl;
      String? newCoverPath; // Track new cover for cleanup if DB fails

      // Upload new cover if selected
      if (_newCoverBytes != null) {
        coverUrl = await _uploadNewCover();
        // Extract path from URL for potential cleanup
        if (coverUrl != null) {
          try {
            final uri = Uri.parse(coverUrl);
            final pathSegments = uri.pathSegments;
            final bucketIndex = pathSegments.indexOf('audiobook-covers');
            if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
              newCoverPath = pathSegments.sublist(bucketIndex + 1).join('/');
            }
          } catch (_) {}
        }
      }

      final price = _isFree ? 0 : int.tryParse(_priceController.text) ?? 0;

      final audiobookId = widget.audiobook['id'] as int;

      // Update audiobook - with orphan cover cleanup on failure
      try {
        // Build update data (common fields)
        final updateData = <String, dynamic>{
          'title_fa': _titleFaController.text.trim(),
          'title_en': _titleEnController.text.trim().isEmpty
              ? null
              : _titleEnController.text.trim(),
          'author_fa': _authorFaController.text.trim().isEmpty
              ? null
              : _authorFaController.text.trim(),
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
          'cover_url': coverUrl,
          'price_toman': price,
          'is_free': _isFree,
          'is_featured': _isFeatured,
          'is_parasto_brand': _isParastoBrand, // Display as "پرستو" brand
          'is_podcast': _isPodcast, // Podcast content type flag
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Add category_id only for books (music uses junction table)
        if (!_isMusic && !_isPodcast) {
          updateData['category_id'] = _selectedCategoryId;
        }

        await Supabase.instance.client
            .from('audiobooks')
            .update(updateData)
            .eq('id', audiobookId);
      } catch (dbError) {
        // DB update failed - clean up newly uploaded cover if any
        if (newCoverPath != null) {
          AppLogger.w('Admin audiobook DB update failed, cleaning up new cover: $newCoverPath');
          try {
            await Supabase.instance.client.storage.from('audiobook-covers').remove([newCoverPath]);
          } catch (cleanupError) {
            AppLogger.e('Failed to cleanup orphan cover: $newCoverPath', error: cleanupError);
          }
        }
        rethrow;
      }

      // Update music category via junction table (if music)
      if (_isMusic && _selectedMusicCategoryId != null) {
        // Delete existing music category associations
        await Supabase.instance.client
            .from('audiobook_music_categories')
            .delete()
            .eq('audiobook_id', audiobookId);

        // Insert new music category association (single)
        await Supabase.instance.client
            .from('audiobook_music_categories')
            .insert({
          'audiobook_id': audiobookId,
          'music_category_id': _selectedMusicCategoryId,
        });
      }

      // Upsert music_metadata (if music)
      if (_isMusic) {
        final musicMetadata = {
          'audiobook_id': audiobookId,
          'artist_name': _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
          'featured_artists': _featuredArtistsController.text.trim().isEmpty ? null : _featuredArtistsController.text.trim(),
          'composer': _composerController.text.trim().isEmpty ? null : _composerController.text.trim(),
          'lyricist': _lyricistController.text.trim().isEmpty ? null : _lyricistController.text.trim(),
          'producer': _producerController.text.trim().isEmpty ? null : _producerController.text.trim(),
          'archive_source': _archiveSourceController.text.trim().isEmpty ? null : _archiveSourceController.text.trim(),
          'collection_source': _collectionSourceController.text.trim().isEmpty ? null : _collectionSourceController.text.trim(),
          'album_title': _albumController.text.trim().isEmpty ? null : _albumController.text.trim(),
          'label': _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
          'genre': _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
          'release_year': _releaseYearController.text.trim().isEmpty
              ? null
              : int.tryParse(_releaseYearController.text.trim()),
        };

        await Supabase.instance.client
            .from('music_metadata')
            .upsert(musicMetadata, onConflict: 'audiobook_id');
      } else {
        // Upsert book_metadata (if book)
        final narratorNamesCombined = _narratorNames.where((n) => n.isNotEmpty).join(', ');
        final bookMetadata = {
          'audiobook_id': audiobookId,
          'author_name': _authorFaController.text.trim().isEmpty ? null : _authorFaController.text.trim(),
          'author_name_en': _authorEnController.text.trim().isEmpty ? null : _authorEnController.text.trim(),
          'translator': _translatorFaController.text.trim().isEmpty ? null : _translatorFaController.text.trim(),
          'translator_en': _translatorEnController.text.trim().isEmpty ? null : _translatorEnController.text.trim(),
          'narrator_name': narratorNamesCombined.isEmpty ? null : narratorNamesCombined,
          'publisher': _bookPublisherController.text.trim().isEmpty ? null : _bookPublisherController.text.trim(),
          'archive_source': _bookArchiveController.text.trim().isEmpty ? null : _bookArchiveController.text.trim(),
          'collection_source': _bookCollectionController.text.trim().isEmpty ? null : _bookCollectionController.text.trim(),
          'co_authors': _coAuthorsController.text.trim().isEmpty ? null : _coAuthorsController.text.trim(),
          'publication_year': _publicationYearController.text.trim().isEmpty ? null : int.tryParse(_publicationYearController.text.trim()),
          'isbn': _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
        };

        await Supabase.instance.client
            .from('book_metadata')
            .upsert(bookMetadata, onConflict: 'audiobook_id');
        AppLogger.d('Book metadata saved for audiobook $audiobookId');
      }

      // Auto-sync creators from the author/translator fields
      // For music: author_fa is the artist/singer
      // For books: author_fa is the author, translator_fa is the translator
      final creatorService = CreatorService();
      await creatorService.syncCreatorsForAudiobook(
        audiobookId: audiobookId,
        isMusic: _isMusic,
        // Book fields - author_fa/translator_fa are the legacy fields shown on this form
        authorName: _isMusic ? null : _authorFaController.text,
        authorNameEn: _isMusic ? null : _authorEnController.text,
        translatorName: _isMusic ? null : _translatorFaController.text,
        translatorNameEn: _isMusic ? null : _translatorEnController.text,
        // Music fields - for music, author_fa is the artist/singer
        artistName: _isMusic ? _authorFaController.text : null,
        artistNameEn: _isMusic ? _authorEnController.text : null,
      );
      AppLogger.d('Creator sync completed for audiobook $audiobookId');

      widget.onUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تغییرات ذخیره شد'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = 'خطا در ذخیره: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Manually sync creators from the current form fields.
  /// Useful for backfilling older content that was created before auto-sync.
  Future<void> _manualSyncCreators() async {
    final audiobookId = widget.audiobook['id'] as int;

    setState(() {
      _isSyncingCreators = true;
      _error = null;
    });

    try {
      final creatorService = CreatorService();
      final success = await creatorService.syncCreatorsForAudiobook(
        audiobookId: audiobookId,
        isMusic: _isMusic,
        // Book fields
        authorName: _isMusic ? null : _authorFaController.text,
        authorNameEn: _isMusic ? null : _authorEnController.text,
        translatorName: _isMusic ? null : _translatorFaController.text,
        translatorNameEn: _isMusic ? null : _translatorEnController.text,
        // Music fields - for music, author_fa is the artist
        artistName: _isMusic ? _authorFaController.text : null,
        artistNameEn: _isMusic ? _authorEnController.text : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('سازندگان با موفقیت همگام‌سازی شدند'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() => _error = 'خطا در همگام‌سازی سازندگان');
        }
      }
    } catch (e) {
      setState(() => _error = 'خطا در همگام‌سازی: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingCreators = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get narrator/artist from correct metadata table (not profiles which is the uploader account)
    final isMusic = widget.audiobook['is_music'] == true;
    final isParastoBrand = (widget.audiobook['is_parasto_brand'] as bool?) ?? false;
    String narratorName;
    if (isParastoBrand) {
      narratorName = 'پرستو';
    } else if (isMusic) {
      final musicMeta = widget.audiobook['music_metadata'] as Map<String, dynamic>?;
      narratorName = (musicMeta?['artist_name'] as String?) ?? 'نامشخص';
    } else {
      final bookMeta = widget.audiobook['book_metadata'] as Map<String, dynamic>?;
      narratorName = (bookMeta?['narrator_name'] as String?) ?? 'نامشخص';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('ویرایش کتاب'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Narrator info (read-only)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${isMusic ? 'هنرمند' : 'گوینده'}: $narratorName',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cover Image
                      _buildCoverPicker(),
                      const SizedBox(height: 24),

                      // Persian Title
                      TextFormField(
                        controller: _titleFaController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان فارسی *',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'عنوان فارسی الزامی است';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Author/Translator Section (dynamic for music vs books)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isMusic ? Icons.person : (_isPodcast ? Icons.podcasts : Icons.edit),
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isMusic ? 'اطلاعات هنرمند' : (_isPodcast ? 'اطلاعات میزبان' : 'اطلاعات نویسنده و مترجم'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Conditional: Music Metadata OR Book Metadata
                            if (_isMusic) ...[
                              // MUSIC METADATA FIELDS

                              // Primary Artist
                              TextFormField(
                                controller: _artistController,
                                decoration: const InputDecoration(
                                  labelText: 'هنرمند اصلی',
                                  hintText: 'مثال: محسن چاوشی',
                                  prefixIcon: Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Featured Artists
                              TextFormField(
                                controller: _featuredArtistsController,
                                decoration: const InputDecoration(
                                  labelText: 'هنرمندان مهمان (اختیاری)',
                                  hintText: 'با کاما جدا کنید: هنرمند ۱, هنرمند ۲',
                                  prefixIcon: Icon(Icons.people),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Composer
                              TextFormField(
                                controller: _composerController,
                                decoration: const InputDecoration(
                                  labelText: 'آهنگساز (اختیاری)',
                                  hintText: 'مثال: احمد پژمان',
                                  prefixIcon: Icon(Icons.music_note),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Lyricist
                              TextFormField(
                                controller: _lyricistController,
                                decoration: const InputDecoration(
                                  labelText: 'شاعر (اختیاری)',
                                  hintText: 'مثال: شهریار',
                                  prefixIcon: Icon(Icons.edit),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Producer
                              TextFormField(
                                controller: _producerController,
                                decoration: const InputDecoration(
                                  labelText: 'تهیه‌کننده (اختیاری)',
                                  hintText: 'مثال: حمید متبسم',
                                  prefixIcon: Icon(Icons.settings_voice),
                                ),
                              ),
                              const SizedBox(height: 12),

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
                              const SizedBox(height: 12),

                              // Album Name
                              TextFormField(
                                controller: _albumController,
                                decoration: const InputDecoration(
                                  labelText: 'نام آلبوم (اختیاری)',
                                  hintText: 'مثال: چارتار',
                                  prefixIcon: Icon(Icons.album),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Record Label
                              TextFormField(
                                controller: _labelController,
                                decoration: const InputDecoration(
                                  labelText: 'انتشارات/لیبل (اختیاری)',
                                  hintText: 'مثال: ماهور',
                                  prefixIcon: Icon(Icons.business),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Genre (free text)
                              TextFormField(
                                controller: _genreController,
                                decoration: const InputDecoration(
                                  labelText: 'سبک (اختیاری)',
                                  hintText: 'مثال: موسیقی سنتی',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Release Year
                              TextFormField(
                                controller: _releaseYearController,
                                decoration: const InputDecoration(
                                  labelText: 'سال انتشار (اختیاری)',
                                  hintText: 'مثال: 1399',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ] else if (_isPodcast) ...[
                              // PODCAST METADATA FIELDS
                              // Podcasts have hosts/presenters (میزبان), not authors

                              // Host (میزبان) - stored in author_fa
                              TextFormField(
                                controller: _authorFaController,
                                decoration: const InputDecoration(
                                  labelText: 'میزبان پادکست',
                                  hintText: 'نام میزبان یا مجری پادکست',
                                  prefixIcon: Icon(Icons.mic),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Co-hosts (میزبانان همکار)
                              TextFormField(
                                controller: _coAuthorsController,
                                decoration: const InputDecoration(
                                  labelText: 'میزبانان همکار (اختیاری)',
                                  hintText: 'نام‌ها را با کاما جدا کنید',
                                  prefixIcon: Icon(Icons.group),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Archive source (منبع)
                              TextFormField(
                                controller: _bookArchiveController,
                                decoration: const InputDecoration(
                                  labelText: 'منبع (اختیاری)',
                                  hintText: 'مثال: رادیو فردا',
                                  prefixIcon: Icon(Icons.source),
                                ),
                              ),
                            ] else ...[
                              // BOOK METADATA FIELDS

                              // Author
                              TextFormField(
                                controller: _authorFaController,
                                decoration: const InputDecoration(
                                  labelText: 'نام نویسنده',
                                  hintText: 'مثال: آنتوان دو سنت‌اگزوپری',
                                  prefixIcon: Icon(Icons.edit),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Translator
                              TextFormField(
                                controller: _translatorFaController,
                                decoration: const InputDecoration(
                                  labelText: 'نام مترجم (اختیاری)',
                                  hintText: 'مثال: احمد شاملو',
                                  prefixIcon: Icon(Icons.translate),
                                ),
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
                                controller: _bookPublisherController,
                                decoration: const InputDecoration(
                                  labelText: 'ناشر (اختیاری)',
                                  hintText: 'مثال: نشر چشمه',
                                  prefixIcon: Icon(Icons.business),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Archive (آرشیف)
                              TextFormField(
                                controller: _bookArchiveController,
                                decoration: const InputDecoration(
                                  labelText: 'آرشیف (اختیاری)',
                                  hintText: 'منبع آرشیو',
                                  prefixIcon: Icon(Icons.archive_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Collection (بایگانی)
                              TextFormField(
                                controller: _bookCollectionController,
                                decoration: const InputDecoration(
                                  labelText: 'بایگانی (اختیاری)',
                                  hintText: 'نام مجموعه',
                                  prefixIcon: Icon(Icons.library_books_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Co-authors (نویسندگان همکار)
                              TextFormField(
                                controller: _coAuthorsController,
                                decoration: const InputDecoration(
                                  labelText: 'نویسندگان همکار (اختیاری)',
                                  hintText: 'نام‌ها را با کاما جدا کنید',
                                  prefixIcon: Icon(Icons.people_outline),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Publication year and ISBN in a row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _publicationYearController,
                                      decoration: const InputDecoration(
                                        labelText: 'سال نشر (اختیاری)',
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
                                        labelText: 'شابک (اختیاری)',
                                        hintText: '978-...',
                                        prefixIcon: Icon(Icons.qr_code),
                                      ),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category/Genre Selection (dynamic based on content type)
                      if (_isMusic) ...[
                        // Music Categories (multi-select with chips)
                        DropdownButtonFormField<int>(
                          value: _selectedMusicCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'سبک موسیقی *',
                            prefixIcon: Icon(Icons.music_note),
                          ),
                          items: _musicCategories.map((cat) {
                            final icon = (cat['icon'] as String?) ?? '';
                            final name = (cat['name_fa'] as String?) ?? '';
                            return DropdownMenuItem<int>(
                              value: cat['id'] as int,
                              child: Text(icon.isNotEmpty ? '$icon $name' : name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedMusicCategoryId = value);
                          },
                          validator: (value) {
                            if (value == null) return 'لطفاً سبک موسیقی را انتخاب کنید';
                            return null;
                          },
                        ),
                      ] else ...[
                        // Book Category Dropdown (single select)
                        DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'دسته‌بندی *',
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem<int>(
                              value: cat['id'] as int,
                              child: Text((cat['name_fa'] as String?) ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCategoryId = value);
                          },
                          validator: (value) {
                            if (value == null) return 'لطفاً دسته‌بندی را انتخاب کنید';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Persian Description
                      TextFormField(
                        controller: _descriptionFaController,
                        decoration: const InputDecoration(
                          labelText: 'توضیحات فارسی *',
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
                      const SizedBox(height: 24),

                      // Featured Toggle
                      _buildFeaturedToggle(),
                      const SizedBox(height: 16),

                      // Parasto Brand Toggle
                      _buildParastoBrandToggle(),
                      const SizedBox(height: 16),

                      // Price Section
                      _buildPriceSection(),
                      const SizedBox(height: 24),

                      // Chapter Management Button
                      OutlinedButton.icon(
                        onPressed: () {
                          final audiobookId = widget.audiobook['id'] as int;
                          final audiobookTitle = (widget.audiobook['title_fa'] as String?) ?? '';
                          final narratorId = widget.audiobook['narrator_id'] as String? ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => AdminChapterManagementScreen(
                                audiobookId: audiobookId,
                                audiobookTitle: audiobookTitle,
                                narratorId: narratorId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.library_music),
                        label: Text(
                          'مدیریت فصل‌ها (${FarsiUtils.toFarsiDigits((widget.audiobook['chapter_count'] as int?) ?? 0)} فصل)',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Creators Management Button
                      OutlinedButton.icon(
                        onPressed: () {
                          AudiobookCreatorsSheet.show(
                            context,
                            audiobookId: widget.audiobook['id'] as int,
                            isMusic: _isMusic,
                          );
                        },
                        icon: const Icon(Icons.people),
                        label: const Text('مدیریت سازندگان (نویسنده، گوینده، ...)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Manual Creator Sync Button (for backfilling old content)
                      OutlinedButton.icon(
                        onPressed: _isSyncingCreators ? null : _manualSyncCreators,
                        icon: _isSyncingCreators
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 20),
                        label: const Text('همگام‌سازی سازندگان از روی نام‌ها'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
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

                      // Save Button
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'ذخیره تغییرات',
                                style: TextStyle(fontSize: 16),
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

  Widget _buildCoverPicker() {
    final hasNewCover = _newCoverBytes != null;
    final hasExistingCover = _existingCoverUrl != null && _existingCoverUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasNewCover
                  ? Image.memory(_newCoverBytes!, fit: BoxFit.cover)
                  : hasExistingCover
                      ? Image.network(
                          _existingCoverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 8),
                              Text(_isMusic ? 'انتخاب کاور' : 'انتخاب تصویر جلد', style: const TextStyle(color: AppColors.textTertiary)),
                            ],
                          ),
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
            if (hasNewCover)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'تصویر جدید',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
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

  Widget _buildFeaturedToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: _isFeatured
            ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            _isFeatured ? Icons.star : Icons.star_border,
            color: _isFeatured ? Colors.amber : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMusic ? 'موسیقی ویژه' : 'کتاب ویژه',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _isFeatured
                      ? 'در صفحه اصلی نمایش داده می‌شود'
                      : 'در صفحه اصلی نمایش داده نمی‌شود',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isFeatured,
            onChanged: (value) {
              setState(() => _isFeatured = value);
            },
            activeColor: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
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
}
