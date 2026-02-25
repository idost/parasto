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

                  const SizedBox(height: 8),

                  // Content Hub
                  SidebarNavItem(
                    icon: Icons.library_books_rounded,
                    label: 'محتوا',
                    route: '/admin/content',
                    isActive: activeRoute.startsWith('/admin/content'),
                    isCollapsed: isCollapsed,
                    badge: _getPendingCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/content'),
                  ),

                  // People Hub
                  SidebarNavItem(
                    icon: Icons.people_rounded,
                    label: 'افراد',
                    route: '/admin/people',
                    isActive: activeRoute.startsWith('/admin/people'),
                    isCollapsed: isCollapsed,
                    badge: _getNarratorRequestsCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/people'),
                  ),

                  // Engage Hub
                  SidebarNavItem(
                    icon: Icons.campaign_rounded,
                    label: 'تعامل',
                    route: '/admin/engage',
                    isActive: activeRoute.startsWith('/admin/engage'),
                    isCollapsed: isCollapsed,
                    badge: _getUnreadNotificationsCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/engage'),
                  ),

                  // Insights Hub
                  SidebarNavItem(
                    icon: Icons.insights_rounded,
                    label: 'بینش‌ها',
                    route: '/admin/insights',
                    isActive: activeRoute.startsWith('/admin/insights'),
                    isCollapsed: isCollapsed,
                    badge: _getOpenTicketsCount(ref),
                    onTap: () => _navigate(context, ref, '/admin/insights'),
                  ),

                  const SizedBox(height: 8),

                  // Settings
                  SidebarNavItem(
                    icon: Icons.settings_rounded,
                    label: 'تنظیمات',
                    route: '/admin/settings',
                    isActive: activeRoute.startsWith('/admin/settings') &&
                        !activeRoute.startsWith('/admin/settings/profile'),
                    isCollapsed: isCollapsed,
                    onTap: () => _navigate(context, ref, '/admin/settings'),
                  ),

                  // Profile
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

                    const SizedBox(height: 8),

                    // Content Hub
                    SidebarNavItem(
                      icon: Icons.library_books_rounded,
                      label: 'محتوا',
                      route: '/admin/content',
                      isActive: activeRoute.startsWith('/admin/content'),
                      isCollapsed: false,
                      badge: _getPendingCount(ref),
                      onTap: () => _navigate(context, ref, '/admin/content'),
                    ),

                    // People Hub
                    SidebarNavItem(
                      icon: Icons.people_rounded,
                      label: 'افراد',
                      route: '/admin/people',
                      isActive: activeRoute.startsWith('/admin/people'),
                      isCollapsed: false,
                      badge: _getNarratorRequestsCount(ref),
                      onTap: () => _navigate(context, ref, '/admin/people'),
                    ),

                    // Engage Hub
                    SidebarNavItem(
                      icon: Icons.campaign_rounded,
                      label: 'تعامل',
                      route: '/admin/engage',
                      isActive: activeRoute.startsWith('/admin/engage'),
                      isCollapsed: false,
                      badge: _getUnreadNotificationsCount(ref),
                      onTap: () => _navigate(context, ref, '/admin/engage'),
                    ),

                    // Insights Hub
                    SidebarNavItem(
                      icon: Icons.insights_rounded,
                      label: 'بینش‌ها',
                      route: '/admin/insights',
                      isActive: activeRoute.startsWith('/admin/insights'),
                      isCollapsed: false,
                      badge: _getOpenTicketsCount(ref),
                      onTap: () => _navigate(context, ref, '/admin/insights'),
                    ),

                    const SizedBox(height: 8),

                    // Settings
                    SidebarNavItem(
                      icon: Icons.settings_rounded,
                      label: 'تنظیمات',
                      route: '/admin/settings',
                      isActive: activeRoute.startsWith('/admin/settings') &&
                          !activeRoute.startsWith('/admin/settings/profile'),
                      isCollapsed: false,
                      onTap: () => _navigate(context, ref, '/admin/settings'),
                    ),

                    // Profile
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

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    ref.read(adminActiveRouteProvider.notifier).state = route;
    Navigator.of(context).pop(); // Close drawer after navigation
  }

  int? _getPendingCount(WidgetRef ref) {
    final pendingAsync = ref.watch(pendingContentProvider);
    return pendingAsync.whenOrNull(
      data: (items) => items.isNotEmpty ? items.length : null,
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

  int? _getOpenTicketsCount(WidgetRef ref) {
    final ticketsAsync = ref.watch(adminOpenTicketsCountProvider);
    return ticketsAsync.whenOrNull(
      data: (count) => count > 0 ? count : null,
    );
  }
}
