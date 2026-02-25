import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/admin/admin_categories_screen.dart';
import 'package:myna/screens/admin/admin_reviews_screen.dart';
import 'package:myna/screens/admin/admin_profile_screen.dart';
import 'package:myna/screens/admin/admin_app_settings_screen.dart';
import 'package:myna/screens/admin/admin_promotions_screen.dart';
import 'package:myna/screens/admin/admin_import_export_screen.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          AdminScreenHeader(
            title: 'تنظیمات',
            icon: Icons.settings_rounded,
          ),
          // Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          // Admin Profile Card
          Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 24),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminProfileScreen())),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('پروفایل مدیر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),

          _buildSectionHeader('مدیریت محتوا'),
          _buildSettingTile(
            icon: Icons.campaign,
            title: 'تبلیغات و پیشنهادات',
            subtitle: 'بنرها و قفسه‌های ویژه',
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminPromotionsScreen())),
          ),
          _buildSettingTile(
            icon: Icons.category,
            title: 'دسته‌بندی‌ها',
            subtitle: 'افزودن، ویرایش و حذف دسته‌ها',
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminCategoriesScreen())),
          ),
          _buildSettingTile(
            icon: Icons.reviews,
            title: 'نظرات',
            subtitle: 'مشاهده و مدیریت نظرات',
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminReviewsScreen())),
          ),
          _buildSettingTile(
            icon: Icons.import_export,
            title: 'ورود/خروج داده',
            subtitle: 'وارد و خارج کردن اطلاعات',
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminImportExportScreen())),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('تنظیمات اپلیکیشن'),
          _buildSettingTile(
            icon: Icons.settings_applications,
            title: 'تنظیمات عمومی',
            subtitle: 'کمیسیون، قیمت‌ها و اطلاعات اپ',
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminAppSettingsScreen())),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('سیستم'),
          _buildSettingTile(
            icon: Icons.verified_outlined,
            title: 'درباره اپلیکیشن',
            subtitle: 'نسخه ۱.۰.۰',
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 32),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async => await Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('خروج از حساب', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textTertiary),
    ),
  );

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.headphones, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Text('پرستو', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _aboutRow('نسخه', '۱.۰.۰'),
            _aboutRow('پلتفرم', 'iOS, Android, Web'),
            _aboutRow('توسعه‌دهنده', 'تیم پرستو'),
            const SizedBox(height: 12),
            const Text('اپلیکیشن کتاب صوتی فارسی', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
      ),
    );
  }

  Widget _aboutRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(color: AppColors.textTertiary)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary)),
      ],
    ),
  );
}