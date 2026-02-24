import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Pending content item for approval queue
class PendingContentItem {
  final String id;
  final String title;
  final String creatorName;
  final String contentType; // 'book' or 'music'
  final DateTime submittedAt;

  PendingContentItem({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.contentType,
    required this.submittedAt,
  });
}

/// Provider to fetch pending content (books + music)
final pendingContentProvider = FutureProvider<List<PendingContentItem>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // Fetch ALL pending audiobooks with narrator info
    // Dashboard widget shows preview, but we need accurate count
    final audiobooks = await supabase
        .from('audiobooks')
        .select('id, title_fa, narrator_id, is_music, created_at')
        .eq('status', 'submitted')
        .order('created_at', ascending: true);

    // Get narrator IDs (toString() handles both int and String PKs)
    final narratorIds = audiobooks
        .map((a) => a['narrator_id']?.toString())
        .where((id) => id != null)
        .toSet()
        .toList();

    // Fetch narrator profiles
    final profiles = narratorIds.isNotEmpty
        ? await supabase
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', narratorIds)
        : <Map<String, dynamic>>[];

    // Create lookup map
    final profileMap = <String, String>{};
    for (final profile in profiles) {
      profileMap[profile['id'].toString()] = profile['display_name'] as String? ?? 'بدون نام';
    }

    // Map to PendingContentItem
    return audiobooks.map((book) {
      final narratorId = book['narrator_id']?.toString();
      final creatorName = narratorId != null ? (profileMap[narratorId] ?? 'بدون نام') : 'بدون نام';
      final isMusic = book['is_music'] as bool? ?? false;

      return PendingContentItem(
        id: book['id'].toString(),
        title: book['title_fa'] as String,
        creatorName: creatorName,
        contentType: isMusic ? 'music' : 'book',
        submittedAt: DateTime.parse(book['created_at'] as String),
      );
    }).toList();
  } catch (e) {
    AppLogger.e('Error fetching pending content', error: e);
    rethrow;
  }
});

/// Hero section widget showing pending content approval queue
class ApprovalQueueWidget extends ConsumerWidget {
  const ApprovalQueueWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingContentProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with warm gradient background
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.08),
                  AppColors.warning.withValues(alpha: 0.03),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.pending_actions,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'صف تأیید محتوا',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin/approval-queue');
                  },
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('مشاهده همه'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Content list
          pendingAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.warning),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'خطا در بارگذاری: $error',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 48,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'صف خالی است!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'هیچ محتوایی در انتظار تأیید نیست',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ...items.take(5).map((item) => _buildQueueItem(context, ref, item)),
                  if (items.length > 5)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8, top: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'و ${items.length - 5} مورد دیگر در انتظار تأیید...',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(BuildContext context, WidgetRef ref, PendingContentItem item) {
    // Format time ago in Persian
    final timeAgo = _formatTimeAgo(item.submittedAt);

    final isBook = item.contentType == 'book';
    final icon = isBook ? Icons.menu_book_rounded : Icons.music_note_rounded;
    final typeLabel = isBook ? 'کتاب' : 'موسیقی';
    final typeColor = isBook ? AppColors.primary : AppColors.secondary;

    return Container(
      margin: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Content type icon with glow
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(icon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Content info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.creatorName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time, size: 11, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildActionButton(
                context,
                icon: Icons.check_rounded,
                label: 'تأیید',
                color: AppColors.success,
                onPressed: () => _approveContent(context, ref, item),
              ),
              _buildActionButton(
                context,
                icon: Icons.visibility_rounded,
                label: 'بررسی',
                color: AppColors.primary,
                onPressed: () => _reviewContent(context, item),
              ),
              _buildActionButton(
                context,
                icon: Icons.close_rounded,
                label: 'رد',
                color: AppColors.error,
                onPressed: () => _rejectContent(context, ref, item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveContent(BuildContext context, WidgetRef ref, PendingContentItem item) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('audiobooks')
          .update({'status': 'approved'})
          .eq('id', item.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "${item.title}" تأیید شد'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh the list
      ref.invalidate(pendingContentProvider);
    } catch (e) {
      AppLogger.e('Error approving content', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تأیید: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectContent(BuildContext context, WidgetRef ref, PendingContentItem item) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('رد محتوا', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید "${item.title}" را رد کنید؟',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('رد کن'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('audiobooks')
          .update({'status': 'rejected'})
          .eq('id', item.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ "${item.title}" رد شد'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh the list
      ref.invalidate(pendingContentProvider);
    } catch (e) {
      AppLogger.e('Error rejecting content', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در رد: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _reviewContent(BuildContext context, PendingContentItem item) {
    // Navigate to detail screen for full review
    Navigator.pushNamed(
      context,
      '/admin/audiobook/${item.id}',
    );
  }

  /// Format time ago in Persian
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'لحظاتی پیش';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه پیش';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت پیش';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return '${FarsiUtils.toFarsiDigits(days)} روز پیش';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${FarsiUtils.toFarsiDigits(months)} ماه پیش';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${FarsiUtils.toFarsiDigits(years)} سال پیش';
    }
  }
}
