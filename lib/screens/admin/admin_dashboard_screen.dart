import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/widgets/admin/compact_stat_card.dart';
import 'package:myna/widgets/admin/approval_queue_widget.dart';
import 'package:myna/widgets/admin/recent_activity_feed.dart';
import 'package:myna/widgets/admin/admin_sidebar.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/providers/dashboard_layout_providers.dart';
import 'package:myna/widgets/admin/dashboard_widget_wrapper.dart';

/// Admin stats provider - fetches stats via direct queries
/// PERFORMANCE: Only fetch necessary columns
final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // Fetch all stats in parallel for better performance
    final results = await Future.wait([
      // Pending audiobooks count
      supabase
          .from('audiobooks')
          .select('id')
          .eq('status', 'submitted'),
      // Total books count (is_music = false)
      supabase
          .from('audiobooks')
          .select('id')
          .eq('is_music', false),
      // Total music count (is_music = true)
      supabase
          .from('audiobooks')
          .select('id')
          .eq('is_music', true),
      // Total listeners count
      supabase
          .from('profiles')
          .select('id')
          .eq('role', 'listener'),
      // Total narrators count
      supabase
          .from('profiles')
          .select('id')
          .eq('role', 'narrator'),
      // Fetch ALL purchases for accurate revenue calculation
      // Stats need to be accurate - no arbitrary limits
      supabase
          .from('purchases')
          .select('amount'),
    ]);

    final pendingContent = (results[0] as List).length;
    final totalBooks = (results[1] as List).length;
    final totalMusic = (results[2] as List).length;
    final listeners = (results[3] as List).length;
    final narrators = (results[4] as List).length;
    final purchases = results[5] as List;

    // Fetch podcasts count separately (column may not exist)
    int totalPodcasts = 0;
    try {
      final podcastsResult = await supabase
          .from('audiobooks')
          .select('id')
          .eq('is_podcast', true);
      totalPodcasts = (podcastsResult as List).length;
    } catch (e) {
      // is_podcast column may not exist yet
      AppLogger.d('is_podcast column not found for stats');
    }

    // Calculate total purchases and revenue from ALL purchases
    final totalPurchases = purchases.length;
    final totalRevenue = purchases.fold<int>(
      0,
      (sum, p) => sum + ((p['amount'] as int?) ?? 0),
    );

    // Adjust book count to exclude podcasts (if column exists)
    final adjustedBooks = totalBooks - totalPodcasts;

    return {
      'pending_content': pendingContent,
      'total_books': adjustedBooks > 0 ? adjustedBooks : totalBooks,
      'total_music': totalMusic,
      'total_podcasts': totalPodcasts,
      'total_content': totalBooks + totalMusic,
      'total_users': listeners + narrators,
      'total_narrators': narrators,
      'total_purchases': totalPurchases,
      'total_revenue': totalRevenue,
    };
  } catch (e) {
    AppLogger.e('Error fetching admin stats', error: e);
    rethrow;
  }
});

/// Redesigned admin dashboard with Spotify-inspired layout
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final isEditMode = ref.watch(dashboardEditModeProvider);
    // Watch layout to trigger rebuilds when it changes
    ref.watch(dashboardLayoutProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Header
            AdminScreenHeader(
              title: 'داشبورد',
              icon: Icons.dashboard_rounded,
              actions: [
                // Edit mode toggle
                if (isEditMode) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('افزودن ویجت'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => _showWidgetPicker(context, ref),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('بازنشانی'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.warning,
                    ),
                    onPressed: () => _showResetConfirmation(context, ref),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isEditMode
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditMode ? Icons.check_rounded : Icons.edit_rounded,
                      color: isEditMode ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    final newMode = !isEditMode;
                    ref.read(dashboardEditModeProvider.notifier).state = newMode;
                    if (!newMode) {
                      // Save layout when exiting edit mode
                      ref.read(dashboardLayoutProvider.notifier).saveLayout();
                    }
                  },
                  tooltip: isEditMode ? 'ذخیره تغییرات' : 'ویرایش داشبورد',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    ref.read(adminActiveRouteProvider.notifier).state = '/admin/engage/notifications';
                  },
                  tooltip: 'اعلان‌ها',
                ),
              ],
            ),
            // Main content
            Expanded(
              child: statsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'خطا در بارگذاری آمار',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '$e',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(adminStatsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تلاش مجدد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          data: (stats) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(pendingContentProvider);
              ref.invalidate(recentActivityProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Stats Bar (Single Row)
                  _buildCompactStatsBar(context, ref, stats),
                  const SizedBox(height: 20),

                  // Hero Section: Approval Queue
                  const ApprovalQueueWidget(),
                  const SizedBox(height: 20),

                  // Two-column layout for Activity Feed and Quick Actions
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // On narrow screens, stack vertically
                      if (constraints.maxWidth < 768) {
                        return Column(
                          children: [
                            const RecentActivityFeed(),
                            const SizedBox(height: 16),
                            _buildQuickActions(context, ref),
                          ],
                        );
                      }

                      // On wide screens, side by side
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            flex: 3,
                            child: RecentActivityFeed(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildQuickActions(context, ref),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }

  /// Compact stats bar with 6 metrics - responsive grid
  Widget _buildCompactStatsBar(BuildContext context, WidgetRef ref, Map<String, dynamic> stats) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate number of columns based on screen width
    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth >= 1200) {
      // Desktop: 6 columns in single row
      crossAxisCount = 6;
      childAspectRatio = 1.0;
    } else if (screenWidth >= 768) {
      // Tablet: 3 columns
      crossAxisCount = 3;
      childAspectRatio = 1.1;
    } else {
      // Mobile: 2 columns
      crossAxisCount = 2;
      childAspectRatio = 1.2;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: childAspectRatio,
      children: [
        CompactStatCard(
          icon: Icons.pending_actions_rounded,
          value: FarsiUtils.toFarsiDigits((stats['pending_content'] as int?) ?? 0),
          label: 'در انتظار',
          color: AppColors.warning,
          onTap: () => ref.read(adminActiveRouteProvider.notifier).state = '/admin/content',
        ),
        CompactStatCard(
          icon: Icons.people_rounded,
          value: _formatCompactNumber((stats['total_users'] as int?) ?? 0),
          label: 'کاربران',
          color: AppColors.primary,
        ),
        CompactStatCard(
          icon: Icons.menu_book_rounded,
          value: FarsiUtils.toFarsiDigits((stats['total_books'] as int?) ?? 0),
          label: 'کتاب صوتی',
          color: AppColors.info,
        ),
        CompactStatCard(
          icon: Icons.library_music_rounded,
          value: FarsiUtils.toFarsiDigits((stats['total_music'] as int?) ?? 0),
          label: 'موسیقی',
          color: Colors.purple,
        ),
        CompactStatCard(
          icon: Icons.podcasts_rounded,
          value: FarsiUtils.toFarsiDigits((stats['total_podcasts'] as int?) ?? 0),
          label: 'پادکست',
          color: Colors.teal,
        ),
        CompactStatCard(
          icon: Icons.attach_money_rounded,
          value: _formatRevenue((stats['total_revenue'] as int?) ?? 0),
          label: 'درآمد',
          color: Colors.green,
        ),
      ],
    );
  }

  /// Quick actions widget - Parasto styled
  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with warm gold accent
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.06),
                  AppColors.primary.withValues(alpha: 0.02),
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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.small,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'اقدامات سریع',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _buildQuickActionButton(
            context,
            icon: Icons.menu_book_rounded,
            label: 'مدیریت کتاب‌ها',
            color: AppColors.primary,
            onTap: () {
              ref.read(adminActiveRouteProvider.notifier).state = '/admin/content/books';
            },
          ),
          _buildQuickActionButton(
            context,
            icon: Icons.library_music_rounded,
            label: 'مدیریت موسیقی',
            color: AppColors.secondary,
            onTap: () {
              ref.read(adminActiveRouteProvider.notifier).state = '/admin/content/music';
            },
          ),
          _buildQuickActionButton(
            context,
            icon: Icons.podcasts_rounded,
            label: 'مدیریت پادکست‌ها',
            color: Colors.teal,
            onTap: () {
              ref.read(adminActiveRouteProvider.notifier).state = '/admin/content/podcasts';
            },
          ),
          _buildQuickActionButton(
            context,
            icon: Icons.people_rounded,
            label: 'مدیریت کاربران',
            color: AppColors.info,
            onTap: () {
              ref.read(adminActiveRouteProvider.notifier).state = '/admin/people';
            },
          ),
          _buildQuickActionButton(
            context,
            icon: Icons.support_agent_rounded,
            label: 'پشتیبانی',
            color: AppColors.secondary,
            onTap: () {
              ref.read(adminActiveRouteProvider.notifier).state = '/admin/insights/support';
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon with colored background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.small,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              // Chevron with color hint
              Icon(
                Icons.chevron_left_rounded,
                color: color.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCompactNumber(int number) {
    if (number >= 1000000) {
      return '${FarsiUtils.toFarsiDigits((number / 1000000).toStringAsFixed(1))}M';
    }
    if (number >= 1000) {
      return '${FarsiUtils.toFarsiDigits((number / 1000).toStringAsFixed(1))}K';
    }
    return FarsiUtils.toFarsiDigits(number);
  }

  String _formatRevenue(int revenue) {
    if (revenue >= 1000000) {
      final millions = (revenue / 1000000).toStringAsFixed(1);
      return '${FarsiUtils.toFarsiDigits(millions)}M';
    }
    if (revenue >= 1000) {
      final thousands = (revenue / 1000).toStringAsFixed(0);
      return '${FarsiUtils.toFarsiDigits(thousands)}K';
    }
    return FarsiUtils.toFarsiDigits(revenue);
  }

  void _showWidgetPicker(BuildContext context, WidgetRef ref) {
    final availableWidgets = ref.read(availableWidgetsProvider);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => WidgetPickerDialog(
        availableWidgets: availableWidgets,
        onSelect: (type) async {
          // Start the async operation (dialog will close via its own Navigator.pop)
          try {
            await ref.read(dashboardLayoutProvider.notifier).addWidget(type);
            // Show success feedback if still mounted
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ویجت اضافه شد'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            // Error is already logged in addWidget, show user feedback
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('خطا در افزودن ویجت'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadius.small,
                ),
                child: const Icon(
                  Icons.restore_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'بازنشانی داشبورد',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'آیا از بازنشانی داشبورد به حالت پیش‌فرض اطمینان دارید؟ تمام تنظیمات فعلی شما حذف خواهد شد.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(dashboardLayoutProvider.notifier).resetToDefaults();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('بازنشانی'),
            ),
          ],
        ),
      ),
    );
  }
}
