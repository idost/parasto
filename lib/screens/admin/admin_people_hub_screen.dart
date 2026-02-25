import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/providers/narrator_request_providers.dart';
import 'package:myna/screens/admin/admin_users_screen.dart';
import 'package:myna/screens/admin/admin_creators_screen.dart';

/// Hub screen that unifies all people management tabs (users by role,
/// creators, narrator requests) under a single TabBar interface.
class AdminPeopleHubScreen extends ConsumerStatefulWidget {
  /// Which tab to open initially (0-4). Defaults to 0 (All).
  final int initialTab;

  const AdminPeopleHubScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminPeopleHubScreen> createState() =>
      _AdminPeopleHubScreenState();
}

class _AdminPeopleHubScreenState extends ConsumerState<AdminPeopleHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequestsAsync =
        ref.watch(pendingNarratorRequestsCountProvider);
    final pendingRequests = pendingRequestsAsync.valueOrNull ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          AdminScreenHeader(
            title: 'افراد',
            icon: Icons.people_rounded,
            actions: [
              if (pendingRequests > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pendingRequests',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          // ── Tab Bar ─────────────────────────────────────────────────────
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: [
              const Tab(text: 'همه'),
              const Tab(text: 'شنوندگان'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('گویندگان'),
                    if (pendingRequests > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingRequests',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'سازندگان'),
              const Tab(text: 'مدیران'),
            ],
          ),

          // ── Tab Views ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AdminUsersScreen(
                  key: ValueKey('users-all'),
                  embedded: true,
                  initialRole: null,
                ),
                AdminUsersScreen(
                  key: ValueKey('users-listener'),
                  embedded: true,
                  initialRole: 'listener',
                ),
                AdminUsersScreen(
                  key: ValueKey('users-narrator'),
                  embedded: true,
                  initialRole: 'narrator',
                ),
                AdminCreatorsScreen(
                  key: ValueKey('users-creators'),
                  embedded: true,
                ),
                AdminUsersScreen(
                  key: ValueKey('users-admin'),
                  embedded: true,
                  initialRole: 'admin',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
