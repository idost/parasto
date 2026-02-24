import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/formatters.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/providers/feedback_providers.dart';
import 'package:myna/screens/narrator/narrator_feedback_screen.dart';
import 'package:myna/screens/narrator/narrator_main_shell.dart';

// Provider for narrator stats
final narratorDashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {};

  final audiobooks = await Supabase.instance.client
      .from('audiobooks')
      .select('id, status, play_count, purchase_count, price_toman, is_free')
      .eq('narrator_id', user.id);

  final books = List<Map<String, dynamic>>.from(audiobooks);

  final int totalBooks = books.length;
  final int publishedBooks = books.where((b) => b['status'] == 'approved').length;
  final int pendingBooks = books.where((b) => b['status'] == 'submitted' || b['status'] == 'under_review').length;
  final int draftBooks = books.where((b) => b['status'] == 'draft').length;
  int totalPlays = 0;
  int totalPurchases = 0;
  int totalEarnings = 0;

  for (final book in books) {
    totalPlays += (book['play_count'] as int?) ?? 0;
    totalPurchases += (book['purchase_count'] as int?) ?? 0;
    if (book['is_free'] != true) {
      final price = (book['price_toman'] as int?) ?? 0;
      final purchases = (book['purchase_count'] as int?) ?? 0;
      totalEarnings += price * purchases;
    }
  }

  return {
    'total_books': totalBooks,
    'published_books': publishedBooks,
    'pending_books': pendingBooks,
    'draft_books': draftBooks,
    'total_plays': totalPlays,
    'total_purchases': totalPurchases,
    'total_earnings': totalEarnings,
  };
});

class NarratorDashboardScreen extends ConsumerWidget {
  const NarratorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(narratorDashboardStatsProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(narratorDashboardStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome header
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: const Icon(Icons.mic, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'خوش آمدید',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            user?.email ?? 'گوینده',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats section
                const Text(
                  'آمار کلی',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (e, _) => const Center(
                    child: Text(
                      'خطا در بارگذاری آمار',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                  data: (stats) => Column(
                    children: [
                      // Main stats row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'کل کتاب‌ها',
                              value: FarsiUtils.toFarsiDigits(stats['total_books'] ?? 0),
                              icon: Icons.book,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'منتشر شده',
                              value: FarsiUtils.toFarsiDigits(stats['published_books'] ?? 0),
                              icon: Icons.check_circle,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'در انتظار',
                              value: FarsiUtils.toFarsiDigits(stats['pending_books'] ?? 0),
                              icon: Icons.hourglass_empty,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'پیش‌نویس',
                              value: FarsiUtils.toFarsiDigits(stats['draft_books'] ?? 0),
                              icon: Icons.edit_note,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Performance stats
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'عملکرد',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'پخش‌ها',
                              value: FarsiUtils.formatNumberFarsi((stats['total_plays'] as int?) ?? 0),
                              icon: Icons.play_circle,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'فروش',
                              value: FarsiUtils.toFarsiDigits(stats['total_purchases'] ?? 0),
                              icon: Icons.shopping_cart,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Earnings card (full width)
                      _buildEarningsCard((stats['total_earnings'] as int?) ?? 0),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Feedback section
                _buildFeedbackSection(context, ref),
                const SizedBox(height: 24),

                // Quick actions
                const Text(
                  'دسترسی سریع',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick action buttons info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.medium,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildQuickActionInfo(
                        icon: Icons.library_books,
                        title: 'کتاب‌های من',
                        subtitle: 'مدیریت و ویرایش کتاب‌ها',
                        onTap: () => ref.read(narratorShellIndexProvider.notifier).state = 1,
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _buildQuickActionInfo(
                        icon: Icons.add_circle,
                        title: 'آپلود کتاب جدید',
                        subtitle: 'ایجاد کتاب صوتی جدید',
                        onTap: () => ref.read(narratorShellIndexProvider.notifier).state = 2,
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _buildQuickActionInfo(
                        icon: Icons.person,
                        title: 'پروفایل',
                        subtitle: 'ویرایش اطلاعات شخصی',
                        onTap: () => ref.read(narratorShellIndexProvider.notifier).state = 3,
                      ),
                    ],
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(int earnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'درآمد کل',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            Formatters.formatNumber(earnings),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'بر اساس فروش کتاب‌های شما',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionInfo({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.small,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadFeedbackCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'بازخوردها',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            unreadCountAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (count) => count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: AppRadius.medium,
                      ),
                      child: Text(
                        '$count جدید',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NarratorFeedbackScreen(),
              ),
            );
          },
          borderRadius: AppRadius.medium,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.medium,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.feedback_outlined, color: AppColors.warning, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بازخوردهای مدیریت',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      unreadCountAsync.when(
                        loading: () => const Text(
                          'در حال بارگذاری...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        error: (_, __) => const Text(
                          'مشاهده بازخوردها',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        data: (count) => Text(
                          count > 0
                              ? '$count بازخورد خوانده نشده'
                              : 'همه بازخوردها خوانده شده',
                          style: TextStyle(
                            color: count > 0 ? AppColors.warning : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
