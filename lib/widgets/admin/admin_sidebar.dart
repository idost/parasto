import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/sidebar_nav_item.dart';
import 'package:myna/widgets/admin/global_search_dialog.dart';
import 'package:myna/widgets/admin/approval_queue_widget.dart' show pendingContentProvider;
import 'package:myna/services/auth_service.dart';
import 'package:myna/providers/narrator_request_providers.dart';
import 'package:myna/providers/notification_providers.dart';
import 'package:myna/providers/support_providers.dart' show adminOpenTicketsCountProvider;

/// Breakpoints for responsive sidebar behavior
class AdminBreakpoints {
  static const double mobile = 768;
  static const double desktop = 1024;

  static const double sidebarExpanded = 240;
  static const double sidebarCollapsed = 64;
  static const double sidebarMobile = 280;
}

/// Provider for sidebar collapsed state
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Provider for current admin route
final adminActiveRouteProvider = StateProvider<String>((ref) => '/admin/dashboard');

/// Admin sidebar navigation component
/// Responsive: Desktop (persistent), Tablet (collapsible), Mobile (drawer)
class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final activeRoute = ref.watch(adminActiveRouteProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < AdminBreakpoints.mobile;

    // On mobile, sidebar is shown as drawer (handled by Scaffold)
    // This widget is only rendered on tablet/desktop
    if (isMobile) {
      return const SizedBox.shrink();
    }

    final sidebarWidth = isCollapsed
        ? AdminBreakpoints.sidebarCollapsed
        : AdminBreakpoints.sidebarExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header with logo and collapse button
          _buildHeader(context, ref, isCollapsed),

          // Navigation items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // Dashboard
                  SidebarNavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'داشبورد',
                    route: '/admin/dashboard',
                    isActive: activeRoute == '/admin/dashboard',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/dashboard'),
                  ),

                  // Global Search
                  SidebarNavItem(
                    icon: Icons.search_rounded,
                    label: 'جستجو',
                    route: '/admin/search',
                    isActive: false,
                    isCollapsed: isCollapsed,
                    onTap: () => showGlobalSearch(context),
                  ),

                  const SizedBox(height: 16),

                  // Content Section
                  if (!isCollapsed) _buildSectionHeader('محتوا'),
                  SidebarNavItem(
                    icon: Icons.menu_book_rounded,
                    label: 'کتاب‌های صوتی',
                    route: '/admin/books',
                    isActive: activeRoute == '/admin/books',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/books'),
                  ),
                  SidebarNavItem(
                    icon: Icons.library_music_rounded,
                    label: 'موسیقی',
                    route: '/admin/music',
                    isActive: activeRoute == '/admin/music',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/music'),
                  ),
                  SidebarNavItem(
                    icon: Icons.podcasts_rounded,
                    label: 'پادکست‌ها',
                    route: '/admin/podcasts',
                    isActive: activeRoute == '/admin/podcasts',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/podcasts'),
                  ),
                  SidebarNavItem(
                    icon: Icons.pending_actions_rounded,
                    label: 'صف تأیید',
                    route: '/admin/approval-queue',
                    isActive: activeRoute == '/admin/approval-queue',
                    isCollapsed: isCollapsed,
                    badge: _getPendingCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/approval-queue'),
                  ),
                  SidebarNavItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'ویژه و تبلیغات',
                    route: '/admin/promotions',
                    isActive: activeRoute == '/admin/promotions',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/promotions'),
                  ),
                  SidebarNavItem(
                    icon: Icons.schedule_rounded,
                    label: 'زمان‌بندی',
                    route: '/admin/scheduling',
                    isActive: activeRoute == '/admin/scheduling',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/scheduling'),
                  ),

                  const SizedBox(height: 16),

                  // Users Section
                  if (!isCollapsed) _buildSectionHeader('کاربران'),
                  SidebarNavItem(
                    icon: Icons.people_rounded,
                    label: 'شنوندگان',
                    route: '/admin/users/listeners',
                    isActive: activeRoute == '/admin/users/listeners',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/users/listeners'),
                  ),
                  SidebarNavItem(
                    icon: Icons.mic_rounded,
                    label: 'گویندگان',
                    route: '/admin/users/narrators',
                    isActive: activeRoute == '/admin/users/narrators',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/users/narrators'),
                  ),
                  SidebarNavItem(
                    icon: Icons.edit_rounded,
                    label: 'سازندگان',
                    route: '/admin/users/creators',
                    isActive: activeRoute == '/admin/users/creators',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/users/creators'),
                  ),
                  SidebarNavItem(
                    icon: Icons.person_add_rounded,
                    label: 'درخواست‌های گوینده',
                    route: '/admin/users/narrator-requests',
                    isActive: activeRoute == '/admin/users/narrator-requests',
                    isCollapsed: isCollapsed,
                    badge: _getNarratorRequestsCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/users/narrator-requests'),
                  ),

                  const SizedBox(height: 16),

                  // Admins Section
                  if (!isCollapsed) _buildSectionHeader('مدیران'),
                  SidebarNavItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'فهرست مدیران',
                    route: '/admin/users/admins',
                    isActive: activeRoute == '/admin/users/admins',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/users/admins'),
                  ),

                  const SizedBox(height: 16),

                  // Support
                  SidebarNavItem(
                    icon: Icons.support_agent_rounded,
                    label: 'پشتیبانی',
                    route: '/admin/support',
                    isActive: activeRoute == '/admin/support',
                    isCollapsed: isCollapsed,
                    badge: _getOpenTicketsCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/support'),
                  ),

                  const SizedBox(height: 16),

                  // Analytics
                  SidebarNavItem(
                    icon: Icons.analytics_rounded,
                    label: 'آنالیتیکس',
                    route: '/admin/analytics',
                    isActive: activeRoute == '/admin/analytics',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/analytics'),
                  ),

                  // Audit Trail
                  SidebarNavItem(
                    icon: Icons.history_rounded,
                    label: 'گزارش فعالیت',
                    route: '/admin/audit',
                    isActive: activeRoute == '/admin/audit',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/audit'),
                  ),

                  // Quality Tools
                  SidebarNavItem(
                    icon: Icons.verified_rounded,
                    label: 'کنترل کیفیت',
                    route: '/admin/quality',
                    isActive: activeRoute == '/admin/quality',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/quality'),
                  ),

                  // Import/Export
                  SidebarNavItem(
                    icon: Icons.import_export_rounded,
                    label: 'ورود/خروج',
                    route: '/admin/import-export',
                    isActive: activeRoute == '/admin/import-export',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/import-export'),
                  ),

                  // Notifications
                  SidebarNavItem(
                    icon: Icons.notifications_rounded,
                    label: 'اعلان‌ها',
                    route: '/admin/notifications',
                    isActive: activeRoute == '/admin/notifications',
                    isCollapsed: isCollapsed,
                    badge: _getUnreadNotificationsCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/notifications'),
                  ),

                  // Messaging
                  SidebarNavItem(
                    icon: Icons.message_rounded,
                    label: 'پیام‌ها',
                    route: '/admin/messaging',
                    isActive: activeRoute == '/admin/messaging',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/messaging'),
                  ),

                  const SizedBox(height: 16),

                  // Settings Section
                  if (!isCollapsed) _buildSectionHeader('تنظیمات'),
                  SidebarNavItem(
                    icon: Icons.category_rounded,
                    label: 'دسته‌بندی‌ها',
                    route: '/admin/settings/categories',
                    isActive: activeRoute == '/admin/settings/categories',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/settings/categories'),
                  ),
                  SidebarNavItem(
                    icon: Icons.settings_applications_rounded,
                    label: 'تنظیمات اپ',
                    route: '/admin/settings/app',
                    isActive: activeRoute == '/admin/settings/app',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/settings/app'),
                  ),
                  SidebarNavItem(
                    icon: Icons.account_circle_rounded,
                    label: 'پروفایل',
                    route: '/admin/settings/profile',
                    isActive: activeRoute == '/admin/settings/profile',
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/settings/profile'),
                  ),

                  const SizedBox(height: 16),

                  // Logout button at the end
                  SidebarNavItem(
                    icon: Icons.logout_rounded,
                    label: 'خروج',
                    route: '/logout',
                    isActive: false,
                    isCollapsed: isCollapsed,
                    onTap: () => _handleLogout(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isCollapsed) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        children: [
          if (!isCollapsed) ...[
            const Text(
              'PARASTO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.menu : Icons.menu_open,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
            },
            tooltip: isCollapsed ? 'باز کردن منو' : 'بستن منو',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    ref.read(adminActiveRouteProvider.notifier).state = route;

    // Close drawer on mobile after navigation
    if (MediaQuery.of(context).size.width < AdminBreakpoints.mobile) {
      Navigator.of(context).pop();
    }

    // TODO: Implement actual navigation logic
    // For now, this updates the active route state
    // Real navigation will be implemented when screens are created
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('خروج از حساب', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('آیا مطمئن هستید که می‌خواهید خارج شوید؟', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await authService.signOut();
        // Navigation will be handled by auth state listener
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در خروج: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  int? _getPendingCount(WidgetRef ref) {
    final pendingAsync = ref.watch(pendingContentProvider);
    return pendingAsync.whenOrNull(
      data: (items) => items.isNotEmpty ? items.length : null,
    );
  }

  int? _getOpenTicketsCount(WidgetRef ref) {
    final ticketsAsync = ref.watch(adminOpenTicketsCountProvider);
    return ticketsAsync.whenOrNull(
      data: (count) => count > 0 ? count : null,
    );
  }

  int? _getNarratorRequestsCount(WidgetRef ref) {
    final countAsync = ref.watch(pendingNarratorRequestsCountProvider);
    return countAsync.whenOrNull(data: (count) => count > 0 ? count : null);
  }

  int? _getUnreadNotificationsCount(WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    return countAsync.whenOrNull(data: (count) => count > 0 ? count : null);
  }
}

/// Mobile drawer version of sidebar
class AdminSidebarDrawer extends ConsumerWidget {
  const AdminSidebarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoute = ref.watch(adminActiveRouteProvider);

    return Drawer(
      width: AdminBreakpoints.sidebarMobile,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'PARASTO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Navigation items
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // Dashboard
                    SidebarNavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'داشبورد',
                      route: '/admin/dashboard',
                      isActive: activeRoute == '/admin/dashboard',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/dashboard'),
                    ),

                    // Global Search
                    SidebarNavItem(
                      icon: Icons.search_rounded,
                      label: 'جستجو',
                      route: '/admin/search',
                      isActive: false,
                      isCollapsed: false,
                      onTap: () {
                        Navigator.of(context).pop(); // Close drawer first
                        showGlobalSearch(context);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Content Section
                    _buildSectionHeader('محتوا'),
                    SidebarNavItem(
                      icon: Icons.menu_book_rounded,
                      label: 'کتاب‌های صوتی',
                      route: '/admin/books',
                      isActive: activeRoute == '/admin/books',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/books'),
                    ),
                    SidebarNavItem(
                      icon: Icons.library_music_rounded,
                      label: 'موسیقی',
                      route: '/admin/music',
                      isActive: activeRoute == '/admin/music',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/music'),
                    ),
                    SidebarNavItem(
                      icon: Icons.podcasts_rounded,
                      label: 'پادکست‌ها',
                      route: '/admin/podcasts',
                      isActive: activeRoute == '/admin/podcasts',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/podcasts'),
                    ),
                    SidebarNavItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'صف تأیید',
                      route: '/admin/approval-queue',
                      isActive: activeRoute == '/admin/approval-queue',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/approval-queue'),
                    ),
                    SidebarNavItem(
                      icon: Icons.workspace_premium_rounded,
                      label: 'ویژه و تبلیغات',
                      route: '/admin/promotions',
                      isActive: activeRoute == '/admin/promotions',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/promotions'),
                    ),
                    SidebarNavItem(
                      icon: Icons.schedule_rounded,
                      label: 'زمان‌بندی',
                      route: '/admin/scheduling',
                      isActive: activeRoute == '/admin/scheduling',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/scheduling'),
                    ),

                    const SizedBox(height: 16),

                    // Users Section
                    _buildSectionHeader('کاربران'),
                    SidebarNavItem(
                      icon: Icons.people_rounded,
                      label: 'شنوندگان',
                      route: '/admin/users/listeners',
                      isActive: activeRoute == '/admin/users/listeners',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/users/listeners'),
                    ),
                    SidebarNavItem(
                      icon: Icons.mic_rounded,
                      label: 'گویندگان',
                      route: '/admin/users/narrators',
                      isActive: activeRoute == '/admin/users/narrators',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/users/narrators'),
                    ),
                    SidebarNavItem(
                      icon: Icons.edit_rounded,
                      label: 'سازندگان',
                      route: '/admin/users/creators',
                      isActive: activeRoute == '/admin/users/creators',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/users/creators'),
                    ),
                    SidebarNavItem(
                      icon: Icons.person_add_rounded,
                      label: 'درخواست‌های گوینده',
                      route: '/admin/users/narrator-requests',
                      isActive: activeRoute == '/admin/users/narrator-requests',
                      isCollapsed: false,
                      badge: _getNarratorRequestsCount(ref),
                      onTap: () => _navigate(context, ref, '/admin/users/narrator-requests'),
                    ),

                    const SizedBox(height: 16),

                    // Admins Section
                    _buildSectionHeader('مدیران'),
                    SidebarNavItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'فهرست مدیران',
                      route: '/admin/users/admins',
                      isActive: activeRoute == '/admin/users/admins',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/users/admins'),
                    ),

                    const SizedBox(height: 16),

                    // Support
                    SidebarNavItem(
                      icon: Icons.support_agent_rounded,
                      label: 'پشتیبانی',
                      route: '/admin/support',
                      isActive: activeRoute == '/admin/support',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/support'),
                    ),

                    const SizedBox(height: 16),

                    // Analytics
                    SidebarNavItem(
                      icon: Icons.analytics_rounded,
                      label: 'آنالیتیکس',
                      route: '/admin/analytics',
                      isActive: activeRoute == '/admin/analytics',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/analytics'),
                    ),

                    // Audit Trail
                    SidebarNavItem(
                      icon: Icons.history_rounded,
                      label: 'گزارش فعالیت',
                      route: '/admin/audit',
                      isActive: activeRoute == '/admin/audit',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/audit'),
                    ),

                    // Quality Tools
                    SidebarNavItem(
                      icon: Icons.verified_rounded,
                      label: 'کنترل کیفیت',
                      route: '/admin/quality',
                      isActive: activeRoute == '/admin/quality',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/quality'),
                    ),

                    // Import/Export
                    SidebarNavItem(
                      icon: Icons.import_export_rounded,
                      label: 'ورود/خروج',
                      route: '/admin/import-export',
                      isActive: activeRoute == '/admin/import-export',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/import-export'),
                    ),

                    // Notifications
                    SidebarNavItem(
                      icon: Icons.notifications_rounded,
                      label: 'اعلان‌ها',
                      route: '/admin/notifications',
                      isActive: activeRoute == '/admin/notifications',
                      isCollapsed: false,
                      badge: _getUnreadNotificationsCount(ref),
                      onTap: () => _navigate(context, ref, '/admin/notifications'),
                    ),

                    // Messaging
                    SidebarNavItem(
                      icon: Icons.message_rounded,
                      label: 'پیام‌ها',
                      route: '/admin/messaging',
                      isActive: activeRoute == '/admin/messaging',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/messaging'),
                    ),

                    const SizedBox(height: 16),

                    // Settings Section
                    _buildSectionHeader('تنظیمات'),
                    SidebarNavItem(
                      icon: Icons.category_rounded,
                      label: 'دسته‌بندی‌ها',
                      route: '/admin/settings/categories',
                      isActive: activeRoute == '/admin/settings/categories',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/settings/categories'),
                    ),
                    SidebarNavItem(
                      icon: Icons.settings_applications_rounded,
                      label: 'تنظیمات اپ',
                      route: '/admin/settings/app',
                      isActive: activeRoute == '/admin/settings/app',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/settings/app'),
                    ),
                    SidebarNavItem(
                      icon: Icons.account_circle_rounded,
                      label: 'پروفایل',
                      route: '/admin/settings/profile',
                      isActive: activeRoute == '/admin/settings/profile',
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/settings/profile'),
                    ),

                    const SizedBox(height: 16),

                    // Logout button at the end
                    SidebarNavItem(
                      icon: Icons.logout_rounded,
                      label: 'خروج',
                      route: '/logout',
                      isActive: false,
                      isCollapsed: false,
                      onTap: () => _handleLogout(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('خروج از حساب', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('آیا مطمئن هستید که می‌خواهید خارج شوید؟', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await authService.signOut();
        // Navigation will be handled by auth state listener
        if (context.mounted) {
          Navigator.of(context).pop(); // Close drawer
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در خروج: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    ),
  );

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    ref.read(adminActiveRouteProvider.notifier).state = route;
    Navigator.of(context).pop(); // Close drawer after navigation
  }

  int? _getNarratorRequestsCount(WidgetRef ref) {
    final countAsync = ref.watch(pendingNarratorRequestsCountProvider);
    return countAsync.whenOrNull(data: (count) => count > 0 ? count : null);
  }

  int? _getUnreadNotificationsCount(WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    return countAsync.whenOrNull(data: (count) => count > 0 ? count : null);
  }
}
