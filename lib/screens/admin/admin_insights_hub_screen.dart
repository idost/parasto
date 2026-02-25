import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/providers/support_providers.dart';
import 'package:myna/screens/admin/analytics/admin_analytics_screen.dart';
import 'package:myna/screens/admin/admin_quality_screen.dart';
import 'package:myna/screens/admin/admin_audit_screen.dart';
import 'package:myna/screens/admin/admin_support_screen.dart';

class AdminInsightsHubScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const AdminInsightsHubScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminInsightsHubScreen> createState() =>
      _AdminInsightsHubScreenState();
}

class _AdminInsightsHubScreenState
    extends ConsumerState<AdminInsightsHubScreen>
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
    final openTickets = ref.watch(adminOpenTicketsCountProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          const AdminScreenHeader(
            title: 'بینش\u200cها',
            icon: Icons.insights_rounded,
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
              const Tab(text: 'آنالیتیکس'),
              const Tab(text: 'کنترل کیفیت'),
              const Tab(text: 'گزارش فعالیت'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('پشتیبانی'),
                    if (openTickets.valueOrNull != null &&
                        openTickets.valueOrNull! > 0) ...[
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
                          '${openTickets.valueOrNull}',
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
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AdminAnalyticsScreen(embedded: true),
                AdminQualityScreen(embedded: true),
                AdminAuditScreen(embedded: true),
                AdminSupportScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
