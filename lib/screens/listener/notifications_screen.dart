import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myna/theme/app_theme.dart';

/// Notification settings keys
class NotificationKeys {
  static const String newReleases = 'notif_new_releases';
  static const String recommendations = 'notif_recommendations';
  static const String promotions = 'notif_promotions';
  static const String updates = 'notif_updates';
  static const String streakReminders = 'notif_streak_reminders';
  static const String downloadComplete = 'notif_download_complete';
}

/// Notification settings provider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettingsState {
  final bool newReleases;
  final bool recommendations;
  final bool promotions;
  final bool updates;
  final bool streakReminders;
  final bool downloadComplete;
  final bool isLoading;

  const NotificationSettingsState({
    this.newReleases = true,
    this.recommendations = true,
    this.promotions = false,
    this.updates = true,
    this.streakReminders = true,
    this.downloadComplete = true,
    this.isLoading = true,
  });

  NotificationSettingsState copyWith({
    bool? newReleases,
    bool? recommendations,
    bool? promotions,
    bool? updates,
    bool? streakReminders,
    bool? downloadComplete,
    bool? isLoading,
  }) {
    return NotificationSettingsState(
      newReleases: newReleases ?? this.newReleases,
      recommendations: recommendations ?? this.recommendations,
      promotions: promotions ?? this.promotions,
      updates: updates ?? this.updates,
      streakReminders: streakReminders ?? this.streakReminders,
      downloadComplete: downloadComplete ?? this.downloadComplete,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Check if all notifications are enabled
  bool get allEnabled =>
      newReleases && recommendations && promotions && updates && streakReminders && downloadComplete;

  /// Check if all notifications are disabled
  bool get allDisabled =>
      !newReleases && !recommendations && !promotions && !updates && !streakReminders && !downloadComplete;
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  NotificationSettingsNotifier() : super(const NotificationSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettingsState(
      newReleases: prefs.getBool(NotificationKeys.newReleases) ?? true,
      recommendations: prefs.getBool(NotificationKeys.recommendations) ?? true,
      promotions: prefs.getBool(NotificationKeys.promotions) ?? false,
      updates: prefs.getBool(NotificationKeys.updates) ?? true,
      streakReminders: prefs.getBool(NotificationKeys.streakReminders) ?? true,
      downloadComplete: prefs.getBool(NotificationKeys.downloadComplete) ?? true,
      isLoading: false,
    );
  }

  Future<void> setNewReleases(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.newReleases, value);
    state = state.copyWith(newReleases: value);
  }

  Future<void> setRecommendations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.recommendations, value);
    state = state.copyWith(recommendations: value);
  }

  Future<void> setPromotions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.promotions, value);
    state = state.copyWith(promotions: value);
  }

  Future<void> setUpdates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.updates, value);
    state = state.copyWith(updates: value);
  }

  Future<void> setStreakReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.streakReminders, value);
    state = state.copyWith(streakReminders: value);
  }

  Future<void> setDownloadComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.downloadComplete, value);
    state = state.copyWith(downloadComplete: value);
  }

  Future<void> enableAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.newReleases, true);
    await prefs.setBool(NotificationKeys.recommendations, true);
    await prefs.setBool(NotificationKeys.promotions, true);
    await prefs.setBool(NotificationKeys.updates, true);
    await prefs.setBool(NotificationKeys.streakReminders, true);
    await prefs.setBool(NotificationKeys.downloadComplete, true);
    state = state.copyWith(
      newReleases: true,
      recommendations: true,
      promotions: true,
      updates: true,
      streakReminders: true,
      downloadComplete: true,
    );
  }

  Future<void> disableAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationKeys.newReleases, false);
    await prefs.setBool(NotificationKeys.recommendations, false);
    await prefs.setBool(NotificationKeys.promotions, false);
    await prefs.setBool(NotificationKeys.updates, false);
    await prefs.setBool(NotificationKeys.streakReminders, false);
    await prefs.setBool(NotificationKeys.downloadComplete, false);
    state = state.copyWith(
      newReleases: false,
      recommendations: false,
      promotions: false,
      updates: false,
      streakReminders: false,
      downloadComplete: false,
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('اعلان‌ها'),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'enable_all') {
                  notifier.enableAll();
                } else if (value == 'disable_all') {
                  notifier.disableAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'enable_all',
                  child: Text('فعال کردن همه', style: TextStyle(color: AppColors.textPrimary)),
                ),
                const PopupMenuItem(
                  value: 'disable_all',
                  child: Text('غیرفعال کردن همه', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ],
            ),
          ],
        ),
        body: settings.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Coming Soon Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اعلان‌های پوش به‌زودی',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'ترجیحات شما ذخیره می‌شود و با فعال شدن اعلان‌های پوش اعمال خواهد شد.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Notifications
                  _buildSectionHeader('محتوا'),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildNotificationTile(
                      icon: Icons.new_releases_rounded,
                      title: 'کتاب‌های جدید',
                      subtitle: 'اطلاع از انتشار کتاب‌های جدید',
                      value: settings.newReleases,
                      onChanged: notifier.setNewReleases,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildNotificationTile(
                      icon: Icons.recommend,
                      title: 'پیشنهادها',
                      subtitle: 'پیشنهاد کتاب بر اساس سلیقه شما',
                      value: settings.recommendations,
                      onChanged: notifier.setRecommendations,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildNotificationTile(
                      icon: Icons.local_offer,
                      title: 'تخفیف‌ها و پیشنهادات ویژه',
                      subtitle: 'اطلاع از تخفیف‌ها و کدهای تخفیف',
                      value: settings.promotions,
                      onChanged: notifier.setPromotions,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Activity Notifications
                  _buildSectionHeader('فعالیت'),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildNotificationTile(
                      icon: Icons.local_fire_department_rounded,
                      title: 'یادآوری رکورد',
                      subtitle: 'یادآوری برای حفظ رکورد گوش دادن',
                      value: settings.streakReminders,
                      onChanged: notifier.setStreakReminders,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildNotificationTile(
                      icon: Icons.download_done,
                      title: 'اتمام دانلود',
                      subtitle: 'اطلاع از تکمیل دانلود کتاب',
                      value: settings.downloadComplete,
                      onChanged: notifier.setDownloadComplete,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // System Notifications
                  _buildSectionHeader('سیستم'),
                  const SizedBox(height: 8),
                  _buildCard([
                    _buildNotificationTile(
                      icon: Icons.system_update,
                      title: 'به‌روزرسانی‌ها',
                      subtitle: 'اطلاع از نسخه‌های جدید برنامه',
                      value: settings.updates,
                      onChanged: notifier.setUpdates,
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: value ? AppColors.primary : AppColors.textTertiary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}
