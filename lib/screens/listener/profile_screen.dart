import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/listener/edit_profile_screen.dart';
import 'package:myna/screens/listener/downloads_screen.dart';
import 'package:myna/screens/listener/settings_screen.dart';
import 'package:myna/screens/listener/notifications_screen.dart';
import 'package:myna/screens/support/user_support_screen.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/providers/download_provider.dart';
import 'package:myna/providers/support_providers.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/providers/app_mode_provider.dart';
import 'package:myna/providers/narrator_request_providers.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/widgets/listener/narrator_request_status_card.dart';
import 'package:myna/screens/listener/become_narrator_screen.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/app_strings.dart';

final profileDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('profiles')
      .select('*')
      .eq('id', user.id as Object)
      .maybeSingle();

  return response;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(AppStrings.profile),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(profileDataProvider);
            // Also refresh related providers
            ref.invalidate(listeningStatsProvider);
            ref.invalidate(userPendingRequestProvider);
            await ref.read(profileDataProvider.future);
          },
          child: profileAsync.when(
            loading: () => const ProfileSkeleton(),
            error: (e, _) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Text('خطا: $e', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
            data: (profile) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.surface,
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile!['avatar_url'] as String)
                      : null,
                  child: profile?['avatar_url'] == null
                      ? const Icon(Icons.person, size: 50, color: AppColors.textTertiary)
                      : null,
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  AppStrings.localize((profile?['display_name'] as String?) ?? (profile?['full_name'] as String?)) .isNotEmpty
                    ? AppStrings.localize((profile?['display_name'] as String?) ?? (profile?['full_name'] as String?))
                    : AppStrings.user,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // Bio
                if (profile?['bio'] != null && profile!['bio'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      profile['bio'] as String,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Email
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Listening Stats Card
                _ListeningStatsCard(),
                const SizedBox(height: 24),

                // Narrator Request Section (only for listeners)
                if (profile?['role'] == 'listener')
                  _NarratorRequestSection(profile: profile),

                // Menu items
                _buildMenuItem(
                  icon: Icons.edit_outlined,
                  title: AppStrings.editProfile,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()),
                    );
                    if (result == true) {
                      ref.invalidate(profileDataProvider);
                    }
                  },
                ),
                // Downloads menu item (only on mobile)
                if (!kIsWeb) _buildDownloadsMenuItem(context, ref),
                _buildMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: AppStrings.notifications,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.tune_rounded,
                  title: AppStrings.settings,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _buildSupportMenuItem(context, ref),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: AppStrings.help,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.comingSoon)),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: AppStrings.aboutUs,
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),

                // Narrator mode switch button (only for narrator users)
                if (profile?['role'] == 'narrator' || profile?['role'] == 'admin')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildNarratorModeButton(context, ref),
                  ),

                const SizedBox(height: 16),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // 1. Stop audio playback (clears MediaItem and cancels subscriptions)
                        AppLogger.audio('LOGOUT: Stopping audio');
                        await ref.read(audioProvider.notifier).stop();

                        // 2. Small delay to ensure cleanup completes
                        await Future<void>.delayed(const Duration(milliseconds: 100));

                        // 3. Sign out from Supabase
                        await Supabase.instance.client.auth.signOut();

                        AppLogger.audio('LOGOUT: Complete');
                      } catch (e) {
                        AppLogger.e('LOGOUT: Error', error: e);
                        // Still attempt signout even if audio cleanup fails
                        await Supabase.instance.client.auth.signOut();
                      }
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: Text(
                      AppStrings.logout,
                      style: const TextStyle(color: AppColors.error),
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

  Widget _buildSupportMenuItem(BuildContext context, WidgetRef ref) {
    final openTicketsAsync = ref.watch(userOpenTicketsCountProvider);

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const UserSupportScreen()),
          );
        },
        leading: openTicketsAsync.when(
          data: (count) => count > 0
              ? Badge(
                  label: Text(FarsiUtils.toFarsiDigits(count)),
                  child: const Icon(Icons.support_agent, color: AppColors.primary),
                )
              : const Icon(Icons.support_agent, color: AppColors.primary),
          loading: () => const Icon(Icons.support_agent, color: AppColors.primary),
          error: (_, __) => const Icon(Icons.support_agent, color: AppColors.primary),
        ),
        title: Text(
          AppStrings.support,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing: const Icon(
          Icons.chevron_left,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildDownloadsMenuItem(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);
    final totalSize = downloadNotifier.getFormattedTotalSizeFarsi();
    final hasDownloads = downloadState.totalDownloads > 0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
          );
        },
        leading: const Icon(Icons.download_outlined, color: AppColors.primary),
        title: Text(
          AppStrings.downloads,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: hasDownloads
            ? Text(
                totalSize,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              )
            : null,
        trailing: const Icon(
          Icons.chevron_left,
          color: AppColors.textTertiary,
        ),
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

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // App name
                const Text(
                  'پرستو',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.version} ۱.۰.۰',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppStrings.close,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarratorModeButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(appModeProvider.notifier).state = AppMode.narrator;
        },
        icon: const Icon(Icons.mic, color: AppColors.textOnPrimary),
        label: Text(
          AppStrings.goToNarratorDashboard,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ============================================
// LISTENING STATS CARD
// ============================================

class _ListeningStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(listeningStatsProvider);

    return statsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        // Don't show the card if user has no listening history
        if (stats.totalListenTimeSeconds == 0 && stats.daysListening == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with listener level
              Row(
                children: [
                  const Icon(
                    Icons.headphones,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.listeningStats,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  // Listener level badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stats.listenerLevelIcon,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stats.listenerLevel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats Grid - responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final statItems = [
                    _StatItem(
                      icon: Icons.schedule_rounded,
                      value: stats.formattedTotalTimeShort,
                      label: AppStrings.totalTime,
                    ),
                    _StatItem(
                      icon: Icons.event_available_rounded,
                      value: FarsiUtils.toFarsiDigits(stats.daysListening),
                      label: AppStrings.activeDays,
                    ),
                    _StatItem(
                      icon: Icons.whatshot_rounded,
                      value: FarsiUtils.toFarsiDigits(stats.currentStreak),
                      label: AppStrings.consecutiveDays,
                      isHighlighted: stats.currentStreak > 0,
                    ),
                  ];

                  // Use Wrap on very narrow screens
                  if (constraints.maxWidth < 280) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: statItems,
                    );
                  }

                  return Row(
                    children: statItems.map((item) => Expanded(child: item)).toList(),
                  );
                },
              ),

              // Longest streak (if different from current and > 0)
              if (stats.longestStreak > 0 && stats.longestStreak > stats.currentStreak) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.longestStreak(stats.longestStreak),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              // Completed books if any
              if (stats.booksCompleted > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.booksCompleted(stats.booksCompleted),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Achievements section
              if (stats.achievedCount > 0) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.surfaceLight),
                const SizedBox(height: 16),
                Text(
                  AppStrings.achievements,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stats.achievements
                      .where((a) => a.achieved)
                      .map((achievement) => _AchievementChip(achievement: achievement))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AchievementChip extends StatelessWidget {
  final Achievement achievement;

  const _AchievementChip({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: achievement.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              achievement.title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isHighlighted;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.warning.withValues(alpha: 0.15)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 26,
            color: isHighlighted ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Widget for narrator request section on profile screen
class _NarratorRequestSection extends ConsumerWidget {
  final Map<String, dynamic>? profile;

  const _NarratorRequestSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingRequestAsync = ref.watch(userPendingRequestProvider);

    return pendingRequestAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pendingRequest) {
        if (pendingRequest != null) {
          // User has a pending or reviewed request - show status card
          return Column(
            children: [
              NarratorRequestStatusCard(request: pendingRequest),
              const SizedBox(height: 24),
            ],
          );
        } else {
          // No pending request - show "Become a Narrator" button
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.becomeNarrator,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.becomeNarratorSubtitle,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const BecomeNarratorScreen(),
                            ),
                          );
                          // Refresh pending request status
                          ref.invalidate(userPendingRequestProvider);
                        },
                        icon: const Icon(Icons.arrow_forward, color: AppColors.textOnPrimary),
                        label: Text(AppStrings.narratorRequest),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }
      },
    );
  }
}
