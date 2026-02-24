import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/admin_notification.dart';
import 'package:myna/providers/notification_providers.dart';

/// Dialog for managing notification preferences
class NotificationPreferencesDialog extends ConsumerStatefulWidget {
  const NotificationPreferencesDialog({super.key});

  @override
  ConsumerState<NotificationPreferencesDialog> createState() =>
      _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState
    extends ConsumerState<NotificationPreferencesDialog> {
  NotificationPreferences? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await ref.read(notificationPreferencesProvider.future);
    if (mounted) {
      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;

    setState(() => _isSaving = true);

    await ref
        .read(notificationPreferencesNotifierProvider.notifier)
        .updatePreferences(_preferences!);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تنظیمات ذخیره شد'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'تنظیمات اعلان‌ها',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Content
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_preferences == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'خطا در بارگذاری تنظیمات',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // In-app notifications section
                        _buildSectionHeader('اعلان‌های درون‌برنامه'),
                        const SizedBox(height: 12),
                        _buildToggle(
                          'محتوای جدید',
                          'دریافت اعلان برای محتوای جدید ارسال شده',
                          _preferences!.inAppNewContent,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              inAppNewContent: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'درخواست گویندگی',
                          'دریافت اعلان برای درخواست‌های جدید گویندگی',
                          _preferences!.inAppNarratorRequests,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              inAppNarratorRequests: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'تیکت پشتیبانی',
                          'دریافت اعلان برای تیکت‌های جدید',
                          _preferences!.inAppSupportTickets,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              inAppSupportTickets: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'کاربران جدید',
                          'دریافت اعلان برای ثبت‌نام کاربران جدید',
                          _preferences!.inAppNewUsers,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              inAppNewUsers: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'خریدها',
                          'دریافت اعلان برای خریدهای جدید',
                          _preferences!.inAppPurchases,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              inAppPurchases: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'نظرات',
                          'دریافت اعلان برای نظرات جدید',
                          _preferences!.inAppReviews,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              inAppReviews: value,
                            );
                          }),
                        ),

                        const SizedBox(height: 24),

                        // Email notifications section
                        _buildSectionHeader('اعلان‌های ایمیل'),
                        const SizedBox(height: 12),
                        _buildToggle(
                          'خلاصه روزانه',
                          'دریافت ایمیل خلاصه روزانه فعالیت‌ها',
                          _preferences!.emailDailySummary,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              emailDailySummary: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'هشدارهای مهم',
                          'دریافت ایمیل برای هشدارهای بحرانی',
                          _preferences!.emailCriticalAlerts,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              emailCriticalAlerts: value,
                            );
                          }),
                        ),
                        _buildToggle(
                          'گزارش هفتگی',
                          'دریافت گزارش آماری هفتگی',
                          _preferences!.emailWeeklyReport,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              emailWeeklyReport: value,
                            );
                          }),
                        ),

                        const SizedBox(height: 24),

                        // Push notifications section
                        _buildSectionHeader('اعلان‌های پوش'),
                        const SizedBox(height: 12),
                        _buildToggle(
                          'فعال‌سازی پوش',
                          'دریافت اعلان پوش در دستگاه',
                          _preferences!.pushEnabled,
                          (value) => setState(() {
                            _preferences = _preferences!.copyWith(
                              pushEnabled: value,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('ذخیره'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
