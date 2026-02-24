import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/narrator/narrator_edit_screen.dart';
import 'package:myna/screens/narrator/chapter_management_screen.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

class NarratorAudiobooksScreen extends ConsumerStatefulWidget {
  const NarratorAudiobooksScreen({super.key});

  @override
  ConsumerState<NarratorAudiobooksScreen> createState() => _NarratorAudiobooksScreenState();
}

class _NarratorAudiobooksScreenState extends ConsumerState<NarratorAudiobooksScreen> {
  List<Map<String, dynamic>> _audiobooks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'لطفاً وارد شوید';
          _isLoading = false;
        });
        return;
      }

      // Include rejection_reason for displaying feedback to narrator
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('*, categories(name_fa)')
          .eq('narrator_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _audiobooks = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('Error loading narrator audiobooks', error: e);
      setState(() {
        _error = 'خطا در بارگذاری کتاب‌ها';
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'draft':
        return 'پیش‌نویس';
      case 'submitted':
        return 'ارسال شده';
      case 'under_review':
        return 'در حال بررسی';
      case 'approved':
        return 'منتشر شده';
      case 'rejected':
        return 'رد شده';
      default:
        return 'نامشخص';
    }
  }

  String _getStatusDescription(String? status) {
    switch (status) {
      case 'draft':
        return 'فصل‌ها را اضافه کرده و ارسال کنید';
      case 'submitted':
        return 'در صف بررسی توسط تیم ما';
      case 'under_review':
        return 'در حال بررسی توسط تیم ما';
      case 'approved':
        return 'کتاب شما در اپ منتشر شده';
      case 'rejected':
        return 'لطفاً اصلاحات را انجام دهید';
      default:
        return '';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'draft':
        return AppColors.textTertiary;
      case 'submitted':
        return AppColors.warning; // Yellow/amber for "waiting"
      case 'under_review':
        return AppColors.info; // Blue for "actively being reviewed"
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'draft':
        return Icons.edit_note;
      case 'submitted':
        return Icons.schedule; // Clock for "waiting in queue"
      case 'under_review':
        return Icons.visibility; // Eye for "being reviewed"
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  void _openEditScreen(Map<String, dynamic> book) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => NarratorEditScreen(
          audiobookId: book['id'] as int,
        ),
      ),
    );

    // Reload if changes were made
    if (result == true) {
      _loadAudiobooks();
    }
  }

  void _openChapterManagement(Map<String, dynamic> book) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute<String?>(
        builder: (context) => ChapterManagementScreen(
          audiobookId: book['id'] as int,
          audiobookTitle: (book['title_fa'] as String?) ?? '',
        ),
      ),
    );

    // Reload if submitted or changes were made
    if (result == 'submitted') {
      _loadAudiobooks();
    }
  }

  void _showBookOptions(Map<String, dynamic> book) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  (book['title_fa'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Options
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: const Text('ویرایش کتاب'),
                onTap: () {
                  Navigator.pop(context);
                  _openEditScreen(book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_music, color: AppColors.primary),
                title: Text('مدیریت فصل‌ها (${FarsiUtils.toFarsiDigits((book['chapter_count'] as int?) ?? 0)})'),
                onTap: () {
                  Navigator.pop(context);
                  _openChapterManagement(book);
                },
              ),
              // Show submit option for drafts with chapters
              if (book['status'] == 'draft' && ((book['chapter_count'] as int?) ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.send, color: AppColors.warning),
                  title: const Text('ارسال برای بررسی'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _submitForReview(book);
                  },
                ),
              // Show re-submit option for rejected books (after edits)
              if (book['status'] == 'rejected')
                ListTile(
                  leading: const Icon(Icons.replay, color: AppColors.primary),
                  title: const Text('ارسال مجدد برای بررسی'),
                  subtitle: const Text('پس از انجام اصلاحات', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _submitForReview(book);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForReview(Map<String, dynamic> book) async {
    try {
      await Supabase.instance.client
          .from('audiobooks')
          .update({'status': 'submitted'})
          .eq('id', book['id'] as int);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کتاب برای بررسی ارسال شد'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadAudiobooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAudiobooks,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    if (_audiobooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'هنوز کتابی آپلود نکرده‌اید',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'از تب آپلود، اولین کتاب خود را اضافه کنید',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAudiobooks,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _audiobooks.length,
        itemBuilder: (context, index) {
          final book = _audiobooks[index];
          return _buildBookCard(book);
        },
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final status = book['status'] as String?;
    final categoryName = (book['categories']?['name_fa'] as String?) ?? '';
    final chapterCount = (book['chapter_count'] as int?) ?? 0;
    final isFree = (book['is_free'] as bool?) ?? true;
    final price = (book['price_toman'] as int?) ?? 0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBookOptions(book),
        borderRadius: AppRadius.medium,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover Image (2:3 aspect ratio)
              ClipRRect(
                borderRadius: AppRadius.small,
                child: Container(
                  width: 80,
                  height: 120, // 2:3 ratio
                  color: AppColors.surfaceLight,
                  child: book['cover_url'] != null
                      ? Image.network(
                          book['cover_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.book,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : const Icon(
                          Icons.book,
                          color: AppColors.textTertiary,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      (book['title_fa'] as String?) ?? 'بدون عنوان',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category
                    if (categoryName.isNotEmpty)
                      Text(
                        categoryName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Stats row
                    Row(
                      children: [
                        // Chapters
                        const Icon(Icons.list, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${FarsiUtils.toFarsiDigits(chapterCount)} فصل',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Price
                        Icon(
                          isFree ? Icons.card_giftcard : Icons.attach_money,
                          size: 14,
                          color: isFree ? AppColors.success : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFree ? 'رایگان' : '$price',
                          style: TextStyle(
                            color: isFree ? AppColors.success : AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Status badge with description
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            size: 12,
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status description
                    if (_getStatusDescription(status).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getStatusDescription(status),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    // Rejection reason
                    if (status == 'rejected' && book['rejection_reason'] != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          book['rejection_reason'] as String,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow
              const Icon(
                Icons.chevron_left,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}