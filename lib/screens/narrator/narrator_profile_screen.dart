import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/listener/edit_profile_screen.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/providers/app_mode_provider.dart';
import 'package:myna/utils/farsi_utils.dart';

final narratorProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

  return response;
});

final narratorStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {};

  final audiobooks = await Supabase.instance.client
      .from('audiobooks')
      .select('id, play_count, purchase_count')
      .eq('narrator_id', user.id);

  final books = List<Map<String, dynamic>>.from(audiobooks);

  int totalPlays = 0;
  int totalPurchases = 0;

  for (final book in books) {
    totalPlays += (book['play_count'] as int?) ?? 0;
    totalPurchases += (book['purchase_count'] as int?) ?? 0;
  }

  return {
    'total_books': books.length,
    'total_plays': totalPlays,
    'total_purchases': totalPurchases,
  };
});

class NarratorProfileScreen extends ConsumerWidget {
  const NarratorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(narratorProfileProvider);
    final statsAsync = ref.watch(narratorStatsProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Text('خطا: $e', style: const TextStyle(color: AppColors.error)),
            ),
            data: (profile) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.surface,
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile!['avatar_url'] as String)
                      : null,
                  child: profile?['avatar_url'] == null
                      ? const Icon(Icons.mic, size: 50, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  (profile?['display_name'] as String?) ?? (profile?['full_name'] as String?) ?? 'گوینده',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // Email
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                
                // Role badge
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.large,
                  ),
                  child: const Text(
                    'گوینده',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                statsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) => LayoutBuilder(
                    builder: (context, constraints) {
                      // Use Wrap for narrow screens, Row for wider
                      if (constraints.maxWidth < 340) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildStatCard('کتاب‌ها', FarsiUtils.toFarsiDigits(stats['total_books'] ?? 0), Icons.book),
                            _buildStatCard('پخش‌ها', FarsiUtils.toFarsiDigits(stats['total_plays'] ?? 0), Icons.play_arrow),
                            _buildStatCard('فروش', FarsiUtils.toFarsiDigits(stats['total_purchases'] ?? 0), Icons.shopping_cart),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(child: _buildStatCard('کتاب‌ها', FarsiUtils.toFarsiDigits(stats['total_books'] ?? 0), Icons.book)),
                          const SizedBox(width: 8),
                          Flexible(child: _buildStatCard('پخش‌ها', FarsiUtils.toFarsiDigits(stats['total_plays'] ?? 0), Icons.play_arrow)),
                          const SizedBox(width: 8),
                          Flexible(child: _buildStatCard('فروش', FarsiUtils.toFarsiDigits(stats['total_purchases'] ?? 0), Icons.shopping_cart)),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Menu items
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'ویرایش پروفایل',
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()),
                    );
                    if (result == true) {
                      ref.invalidate(narratorProfileProvider);
                    }
                  },
                ),
                _buildMenuItem(
                  icon: Icons.account_balance_wallet,
                  title: 'کیف پول',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی...')),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.bar_chart,
                  title: 'آمار و گزارش',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی...')),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.settings,
                  title: 'تنظیمات',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی...')),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'راهنما',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('به زودی...')),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Switch to listener mode button
                _buildListenerModeButton(context, ref),
                const SizedBox(height: 16),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Stop audio playback before logging out
                      await ref.read(audioProvider.notifier).stop();
                      await Supabase.instance.client.auth.signOut();
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text(
                      'خروج از حساب',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing: const Icon(
          Icons.chevron_left,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildListenerModeButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(appModeProvider.notifier).state = AppMode.listener;
        },
        icon: const Icon(Icons.headphones, color: AppColors.primary),
        label: const Text(
          'بازگشت به حالت شنونده',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
        ),
      ),
    );
  }
}