import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/formatters.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/screens/player/player_screen.dart';
import 'package:myna/services/feedback_service.dart';
import 'package:myna/services/feedback_service_presentation.dart';
import 'package:myna/providers/feedback_providers.dart';
import 'package:myna/screens/admin/admin_feedback_dialog.dart';
import 'package:myna/screens/admin/admin_edit_audiobook_screen.dart';

class AdminAudiobookDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> audiobook;
  final VoidCallback onUpdate;

  const AdminAudiobookDetailScreen({super.key, required this.audiobook, required this.onUpdate});

  @override
  ConsumerState<AdminAudiobookDetailScreen> createState() => _AdminAudiobookDetailScreenState();
}

class _AdminAudiobookDetailScreenState extends ConsumerState<AdminAudiobookDetailScreen> {
  late Map<String, dynamic> _audiobook;
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = false;
  bool _isLoadingChapters = true;

  @override
  void initState() {
    super.initState();
    _audiobook = widget.audiobook;
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final chapters = await Supabase.instance.client
          .from('chapters')
          .select('*')
          .eq('audiobook_id', _audiobook['id'] as Object)
          .order('chapter_index', ascending: true);

      if (mounted) {
        setState(() {
          _chapters = List<Map<String, dynamic>>.from(chapters);
          _isLoadingChapters = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingChapters = false);
    }
  }

  void _playChapter(int chapterIndex) {
    // Admins have full access to all chapters for preview
    ref.read(audioProvider.notifier).play(
      audiobook: _audiobook,
      chapters: _chapters,
      chapterIndex: chapterIndex,
      isOwned: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          audiobook: _audiobook,
          chapters: _chapters,
          initialChapterIndex: chapterIndex,
          playbackAlreadyStarted: true, // We already called play() above
        ),
      ),
    );
  }

  Future<void> _toggleFeatured() async {
    setState(() => _isLoading = true);
    try {
      final newValue = !(_audiobook['is_featured'] == true);
      await Supabase.instance.client
          .from('audiobooks')
          .update({'is_featured': newValue})
          .eq('id', _audiobook['id'] as Object);
      
      setState(() => _audiobook['is_featured'] = newValue);
      widget.onUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newValue ? 'به ویژه‌ها اضافه شد' : 'از ویژه‌ها حذف شد'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    // If rejecting, require a rejection reason
    if (newStatus == 'rejected') {
      await _showRejectionDialog();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('audiobooks')
          .update({
            'status': newStatus,
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
          })
          .eq('id', _audiobook['id'] as Object);

      setState(() => _audiobook['status'] = newStatus);
      widget.onUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('وضعیت تغییر کرد'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showRejectionDialog() async {
    final narratorId = _audiobook['narrator_id'] as String?;
    if (narratorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا: گوینده مشخص نیست'), backgroundColor: AppColors.error),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('رد کتاب', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لطفاً دلیل رد کتاب را برای گوینده توضیح دهید:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'دلیل رد را اینجا بنویسید...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لطفاً دلیل رد را وارد کنید'), backgroundColor: AppColors.warning),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('رد کتاب'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        // Add rejection feedback
        final service = ref.read(feedbackServiceProvider);
        await service.addAudiobookFeedback(
          audiobookId: _audiobook['id'] as int,
          narratorId: narratorId,
          message: reasonController.text.trim(),
          feedbackType: FeedbackType.rejectionReason,
        );

        // Update status
        await Supabase.instance.client
            .from('audiobooks')
            .update({
              'status': 'rejected',
              'reviewed_at': DateTime.now().toIso8601String(),
              'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
            })
            .eq('id', _audiobook['id'] as Object);

        setState(() => _audiobook['status'] = 'rejected');
        widget.onUpdate();
        ref.invalidate(audiobookFeedbackProvider(_audiobook['id'] as int));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کتاب رد شد و دلیل برای گوینده ارسال شد'), backgroundColor: AppColors.success),
          );
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

    reasonController.dispose();
  }

  Future<void> _openEditScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AdminEditAudiobookScreen(
          audiobook: _audiobook,
          onUpdate: () {
            widget.onUpdate();
            _reloadAudiobook();
          },
        ),
      ),
    );

    if (result == true) {
      _reloadAudiobook();
    }
  }

  Future<void> _reloadAudiobook() async {
    try {
      // Include book_metadata and music_metadata for narrator/artist info
      // (not profiles which is the uploader account, not the actual narrator/artist)
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('*, categories(name_fa), book_metadata(narrator_name), music_metadata(artist_name, featured_artists)')
          .eq('id', _audiobook['id'] as Object)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _audiobook = response;
        });
      }
    } catch (e) {
      // Ignore reload errors, user can refresh manually
    }
  }

  void _showFeedbackDialog({int? chapterId, String? chapterTitle, FeedbackType? initialType}) {
    final narratorId = _audiobook['narrator_id'] as String?;
    if (narratorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا: گوینده مشخص نیست'), backgroundColor: AppColors.error),
      );
      return;
    }

    showAdminFeedbackDialog(
      context,
      audiobookId: _audiobook['id'] as int,
      narratorId: narratorId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      initialType: initialType,
    );
  }

  Future<void> _deleteAudiobook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف کتاب', style: TextStyle(color: AppColors.error)),
        content: const Text('آیا مطمئن هستید؟ این عمل قابل بازگشت نیست.', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.from('audiobooks').delete().eq('id', _audiobook['id'] as Object);
        widget.onUpdate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کتاب حذف شد'), backgroundColor: AppColors.success));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get narrator/artist from correct metadata table (not profiles which is the uploader account)
    final isMusic = _audiobook['content_type'] == 'music';
    final isParastoBrand = (_audiobook['is_parasto_brand'] as bool?) ?? false;
    String narratorDisplay;
    if (isParastoBrand) {
      narratorDisplay = 'پرستو';
    } else if (isMusic) {
      final musicMeta = _audiobook['music_metadata'] as Map<String, dynamic>?;
      narratorDisplay = (musicMeta?['artist_name'] as String?) ?? 'نامشخص';
    } else {
      final bookMeta = _audiobook['book_metadata'] as Map<String, dynamic>?;
      narratorDisplay = (bookMeta?['narrator_name'] as String?) ?? 'نامشخص';
    }
    final category = _audiobook['categories'] as Map<String, dynamic>?;
    final status = _audiobook['status'] as String? ?? 'draft';
    final isFeatured = _audiobook['is_featured'] == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('جزئیات کتاب'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'ویرایش',
              onPressed: _openEditScreen,
            ),
            IconButton(
              icon: const Icon(Icons.feedback_outlined),
              tooltip: 'افزودن بازخورد',
              onPressed: _showFeedbackDialog,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'delete') _deleteAudiobook();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: AppColors.error, size: 20), SizedBox(width: 8), Text('حذف کتاب', style: TextStyle(color: AppColors.error))])),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover and basic info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _audiobook['cover_url'] != null
                              ? Image.network(_audiobook['cover_url'] as String, width: 120, height: 180, fit: BoxFit.cover) // 2:3 ratio
                              : Container(width: 120, height: 180, color: AppColors.surface, child: const Icon(Icons.book, size: 48, color: AppColors.textTertiary)), // 2:3 ratio
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((_audiobook['title_fa'] as String?) ?? 'بدون عنوان', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 8),
                              // Show author/artist based on content type
                              _buildCreatorInfoRow(),
                              // Show translator only for books (not music)
                              if (_audiobook['content_type'] != 'music' && _audiobook['translator_fa'] != null && (_audiobook['translator_fa'] as String).isNotEmpty)
                                _infoRow(Icons.translate, 'مترجم', _audiobook['translator_fa'] as String),
                              _infoRow(Icons.mic, isMusic ? 'هنرمند' : 'گوینده', narratorDisplay),
                              _infoRow(Icons.category, 'دسته', (category?['name_fa'] as String?) ?? 'نامشخص'),
                              _infoRow(Icons.attach_money, 'قیمت', _audiobook['is_free'] == true ? 'رایگان' : '${_audiobook['price_toman'] ?? 0}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status section
                    const Text('وضعیت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip('draft', 'پیش‌نویس', status),
                        _statusChip('submitted', 'ارسال شده', status),
                        _statusChip('under_review', 'در حال بررسی', status),
                        _statusChip('approved', 'تأیید شده', status),
                        _statusChip('rejected', 'رد شده', status),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Featured toggle
                    Card(
                      color: AppColors.surface,
                      child: SwitchListTile(
                        title: Text(isMusic ? 'موسیقی ویژه' : 'کتاب ویژه', style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text(isFeatured ? 'در صفحه اصلی نمایش داده می‌شود' : 'در صفحه اصلی نمایش داده نمی‌شود', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        value: isFeatured,
                        onChanged: (_) => _toggleFeatured(),
                        activeColor: AppColors.primary,
                        secondary: Icon(isFeatured ? Icons.star : Icons.star_border, color: isFeatured ? Colors.amber : AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    if (_audiobook['description_fa'] != null && _audiobook['description_fa'].toString().isNotEmpty) ...[
                      const Text('توضیحات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Text(_audiobook['description_fa'] as String, style: const TextStyle(color: AppColors.textSecondary, height: 1.6)),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Chapters section
                    const Text('فصل‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    if (_isLoadingChapters)
                      const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    else if (_chapters.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('هنوز فصلی اضافه نشده', style: TextStyle(color: AppColors.textTertiary))),
                      )
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: List.generate(_chapters.length, (i) {
                            final ch = _chapters[i];
                            final isPreview = ch['is_preview'] == true;
                            return ListTile(
                              onTap: () => _playChapter(i),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(child: Icon(Icons.play_arrow, color: AppColors.primary, size: 20)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (ch['title_fa'] as String?) ?? 'فصل ${FarsiUtils.toFarsiDigits(i + 1)}',
                                      style: const TextStyle(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  if (isPreview)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('پیش‌نمایش', style: TextStyle(color: AppColors.success, fontSize: 10)),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                Formatters.formatDuration((ch['duration_seconds'] as int?) ?? 0),
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.feedback_outlined, size: 20),
                                color: AppColors.textTertiary,
                                tooltip: 'بازخورد برای این فصل',
                                onPressed: () => _showFeedbackDialog(
                                  chapterId: ch['id'] as int,
                                  chapterTitle: (ch['title_fa'] as String?) ?? 'فصل ${FarsiUtils.toFarsiDigits(i + 1)}',
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Feedback section
                    _buildFeedbackSection(),
                    const SizedBox(height: 24),

                    // Stats
                    const Text('آمار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _statCard(Icons.star, ((_audiobook['avg_rating'] as num?) ?? 0).toStringAsFixed(1), 'امتیاز')),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(Icons.reviews, '${(_audiobook['review_count'] as int?) ?? 0}', 'نظر')),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(Icons.shopping_cart, '${(_audiobook['purchase_count'] as int?) ?? 0}', 'خرید')),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// Build row showing author (for books) or artist (for music)
  Widget _buildCreatorInfoRow() {
    final isMusic = _audiobook['content_type'] == 'music';
    final authorFa = _audiobook['author_fa'] as String?;

    if (authorFa == null || authorFa.isEmpty) {
      return const SizedBox.shrink();
    }

    final label = isMusic ? 'هنرمند' : 'نویسنده';
    final icon = isMusic ? Icons.person : Icons.edit;
    return _infoRow(icon, label, authorFa);
  }

  Widget _statusChip(String value, String label, String currentStatus) {
    final isSelected = currentStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeStatus(value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 12),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final feedbackAsync = ref.watch(audiobookFeedbackProvider(_audiobook['id'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('بازخوردها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            TextButton.icon(
              onPressed: _showFeedbackDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('افزودن'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        feedbackAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Text('خطا در بارگذاری بازخوردها: $e', style: const TextStyle(color: AppColors.error)),
          ),
          data: (feedbackList) {
            if (feedbackList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('هنوز بازخوردی ثبت نشده', style: TextStyle(color: AppColors.textTertiary))),
              );
            }

            return DecoratedBox(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: feedbackList.map(_buildFeedbackItem).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
    final feedbackType = FeedbackTypeExtension.fromString(feedback['feedback_type'] as String?);
    final message = feedback['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(feedback['created_at'] as String? ?? '');
    final chapterTitle = (feedback['chapters'] as Map<String, dynamic>?)?['title_fa'] as String?;
    final adminName = (feedback['profiles'] as Map<String, dynamic>?)?['display_name'] as String? ?? 'مدیر';
    final isRead = feedback['is_read'] == true;

    return Dismissible(
      key: Key('feedback_${feedback['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsetsDirectional.only(start: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('حذف بازخورد', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text('آیا از حذف این بازخورد مطمئن هستید؟', style: TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final service = ref.read(feedbackServiceProvider);
        await service.deleteFeedback(feedback['id'] as int);
        ref.invalidate(audiobookFeedbackProvider(_audiobook['id'] as int));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('بازخورد حذف شد'), backgroundColor: AppColors.success),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.background, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: feedbackType.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(feedbackType.icon, size: 14, color: feedbackType.color),
                      const SizedBox(width: 4),
                      Text(feedbackType.label, style: TextStyle(fontSize: 11, color: feedbackType.color, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (chapterTitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(chapterTitle, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                  ),
                const Spacer(),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: AppColors.textPrimary, height: 1.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(adminName, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inHours < 1) return '${FarsiUtils.toFarsiDigits(diff.inMinutes)} دقیقه پیش';
    if (diff.inDays < 1) return '${FarsiUtils.toFarsiDigits(diff.inHours)} ساعت پیش';
    if (diff.inDays < 7) return '${FarsiUtils.toFarsiDigits(diff.inDays)} روز پیش';

    return '${FarsiUtils.toFarsiDigits(date.year)}/${FarsiUtils.toFarsiDigits(date.month)}/${FarsiUtils.toFarsiDigits(date.day)}';
  }
}