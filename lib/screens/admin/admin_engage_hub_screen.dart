import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/providers/notification_providers.dart';
import 'package:myna/screens/admin/admin_promotions_screen.dart';
import 'package:myna/screens/admin/admin_notifications_screen.dart';
import 'package:myna/screens/admin/admin_messaging_screen.dart';
import 'package:myna/screens/admin/admin_scheduling_screen.dart';

class AdminEngageHubScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const AdminEngageHubScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminEngageHubScreen> createState() =>
      _AdminEngageHubScreenState();
}

class _AdminEngageHubScreenState extends ConsumerState<AdminEngageHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
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
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          const AdminScreenHeader(
            title: 'تعامل',
            icon: Icons.campaign_rounded,
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              const Tab(text: 'تبلیغات'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('اعلان\u200cها'),
                    if (unreadCount.valueOrNull != null &&
                        unreadCount.valueOrNull! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${unreadCount.valueOrNull}',
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
              const Tab(text: 'پیام\u200cها'),
              const Tab(text: 'زمان\u200cبندی'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AdminPromotionsScreen(embedded: true),
                AdminNotificationsScreen(embedded: true),
                AdminMessagingScreen(embedded: true),
                AdminSchedulingScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
