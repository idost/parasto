import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/admin/admin_dashboard_screen.dart';
import 'package:myna/screens/admin/admin_audiobooks_screen.dart';
import 'package:myna/screens/admin/admin_users_screen.dart';
import 'package:myna/screens/admin/admin_support_screen.dart';
import 'package:myna/screens/admin/admin_settings_screen.dart';
import 'package:myna/screens/admin/admin_categories_screen.dart';
import 'package:myna/screens/admin/admin_app_settings_screen.dart';
import 'package:myna/screens/admin/admin_profile_screen.dart';
import 'package:myna/screens/admin/admin_creators_screen.dart';
import 'package:myna/screens/admin/admin_promotions_screen.dart';
import 'package:myna/screens/admin/admin_narrator_requests_screen.dart';
import 'package:myna/screens/admin/analytics/admin_analytics_screen.dart';
import 'package:myna/screens/admin/admin_audit_screen.dart';
import 'package:myna/screens/admin/admin_notifications_screen.dart';
import 'package:myna/screens/admin/admin_quality_screen.dart';
import 'package:myna/screens/admin/admin_scheduling_screen.dart';
import 'package:myna/screens/admin/admin_import_export_screen.dart';
import 'package:myna/screens/admin/admin_messaging_screen.dart';
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

  /// Get the screen widget for the active route
  Widget _getScreenForRoute(String route) {
    switch (route) {
      case '/admin/dashboard':
        return const AdminDashboardScreen();
      case '/admin/books':
        return const AdminAudiobooksScreen(key: ValueKey('books'));
      case '/admin/music':
        return const AdminAudiobooksScreen(key: ValueKey('music'));
      case '/admin/podcasts':
        return const AdminAudiobooksScreen(key: ValueKey('podcasts'));
      case '/admin/audiobooks':
        // All content routes go to audiobooks screen with content type filter
        return const AdminAudiobooksScreen(key: ValueKey('audiobooks'));
      case '/admin/approval-queue':
        // TODO: Create dedicated approval queue screen in Phase 2
        return const AdminAudiobooksScreen();
      case '/admin/promotions':
        return const AdminPromotionsScreen();
      case '/admin/users':
      case '/admin/users/listeners':
      case '/admin/users/narrators':
      case '/admin/users/admins':
        return const AdminUsersScreen();
      case '/admin/users/creators':
        return const AdminCreatorsScreen();
      case '/admin/users/narrator-requests':
        return const AdminNarratorRequestsScreen();
      case '/admin/support':
        return const AdminSupportScreen();
      case '/admin/analytics':
        return const AdminAnalyticsScreen();
      case '/admin/audit':
        return const AdminAuditScreen();
      case '/admin/notifications':
        return const AdminNotificationsScreen();
      case '/admin/quality':
        return const AdminQualityScreen();
      case '/admin/scheduling':
        return const AdminSchedulingScreen();
      case '/admin/import-export':
        return const AdminImportExportScreen();
      case '/admin/messaging':
        return const AdminMessagingScreen();
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
}
