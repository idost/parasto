import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/admin/admin_dashboard_screen.dart';
import 'package:myna/screens/admin/admin_settings_screen.dart';
import 'package:myna/screens/admin/admin_categories_screen.dart';
import 'package:myna/screens/admin/admin_app_settings_screen.dart';
import 'package:myna/screens/admin/admin_profile_screen.dart';
import 'package:myna/screens/admin/admin_content_hub_screen.dart';
import 'package:myna/screens/admin/admin_people_hub_screen.dart';
import 'package:myna/screens/admin/admin_engage_hub_screen.dart';
import 'package:myna/screens/admin/admin_insights_hub_screen.dart';
import 'package:myna/widgets/admin/admin_sidebar.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/widgets/mini_player.dart';

/// Admin shell with sidebar navigation (desktop-first design)
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoute = ref.watch(adminActiveRouteProvider);
    final audio = ref.watch(audioProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < AdminBreakpoints.mobile;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // Show drawer only on mobile
        drawer: isMobile ? const AdminSidebarDrawer() : null,
        body: Row(
          children: [
            // Sidebar (hidden on mobile, shown as drawer instead)
            if (!isMobile) const AdminSidebar(),

            // Main content area
            Expanded(
              child: Column(
                children: [
                  // Mobile app bar with hamburger menu
                  if (isMobile) _buildMobileAppBar(context),

                  // Main content
                  Expanded(
                    child: _getScreenForRoute(activeRoute),
                  ),

                  // Mini player at bottom (if audio is playing)
                  if (audio.hasAudio) const MiniPlayer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile app bar with hamburger menu
  Widget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_rounded, color: AppColors.primary, size: 20),
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'منو',
        ),
      ),
      title: const Text(
        'پنل مدیریت',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  /// Get the screen widget for the active route.
  /// Hub routes use startsWith() to catch sub-routes (e.g. /admin/content/music).
  /// Exact-match routes use a switch statement.
  Widget _getScreenForRoute(String route) {
    // Hub routes — startsWith checks MUST come before the switch
    if (route.startsWith('/admin/content')) {
      return AdminContentHubScreen(
        key: ValueKey('content-hub-${_contentTab(route)}'),
        initialTab: _contentTab(route),
      );
    }
    if (route.startsWith('/admin/people')) {
      return AdminPeopleHubScreen(
        key: ValueKey('people-hub-${_peopleTab(route)}'),
        initialTab: _peopleTab(route),
      );
    }
    if (route.startsWith('/admin/engage')) {
      return AdminEngageHubScreen(
        key: ValueKey('engage-hub-${_engageTab(route)}'),
        initialTab: _engageTab(route),
      );
    }
    if (route.startsWith('/admin/insights')) {
      return AdminInsightsHubScreen(
        key: ValueKey('insights-hub-${_insightsTab(route)}'),
        initialTab: _insightsTab(route),
      );
    }

    // Exact-match routes
    switch (route) {
      case '/admin/dashboard':
        return const AdminDashboardScreen();
      case '/admin/settings':
        return const AdminSettingsScreen();
      case '/admin/settings/categories':
        return const AdminCategoriesScreen();
      case '/admin/settings/app':
        return const AdminAppSettingsScreen();
      case '/admin/settings/profile':
        return const AdminProfileScreen();
      default:
        return const AdminDashboardScreen();
    }
  }

  /// Map content sub-routes to tab indices
  int _contentTab(String route) => switch (route) {
    '/admin/content/books'    => 1,
    '/admin/content/music'    => 2,
    '/admin/content/podcasts' => 3,
    '/admin/content/articles' => 4,
    '/admin/content/ebooks'   => 5,
    _                         => 0, // All
  };

  /// Map people sub-routes to tab indices
  int _peopleTab(String route) => switch (route) {
    '/admin/people/listeners' => 1,
    '/admin/people/narrators' => 2,
    '/admin/people/creators'  => 3,
    '/admin/people/admins'    => 4,
    _                         => 0, // All
  };

  /// Map engage sub-routes to tab indices
  int _engageTab(String route) => switch (route) {
    '/admin/engage/notifications' => 1,
    '/admin/engage/messaging'     => 2,
    '/admin/engage/scheduling'    => 3,
    _                             => 0, // Promotions
  };

  /// Map insights sub-routes to tab indices
  int _insightsTab(String route) => switch (route) {
    '/admin/insights/quality' => 1,
    '/admin/insights/audit'   => 2,
    '/admin/insights/support' => 3,
    _                         => 0, // Analytics
  };
}
