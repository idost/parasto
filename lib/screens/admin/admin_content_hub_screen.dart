import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/approval_queue_widget.dart'
    show pendingContentProvider;
import 'package:myna/screens/admin/admin_audiobooks_screen.dart';
import 'package:myna/screens/admin/admin_ebooks_screen.dart';

/// Hub screen that unifies all content management tabs (audiobooks, music,
/// podcasts, articles, ebooks) under a single TabBar interface.
class AdminContentHubScreen extends ConsumerStatefulWidget {
  /// Which tab to open initially (0-5). Defaults to 0 (All).
  final int initialTab;

  const AdminContentHubScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminContentHubScreen> createState() =>
      _AdminContentHubScreenState();
}

class _AdminContentHubScreenState extends ConsumerState<AdminContentHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
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
    final pendingAsync = ref.watch(pendingContentProvider);
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          AdminScreenHeader(
            title: 'محتوا',
            icon: Icons.library_books_rounded,
            actions: [
              if (pendingCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pendingCount',
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
            tabs: const [
              Tab(text: 'همه'),
              Tab(text: 'کتاب\u200cها'),
              Tab(text: 'موسیقی'),
              Tab(text: 'پادکست\u200cها'),
              Tab(text: 'مقالات'),
              Tab(text: 'ایبوک\u200cها'),
            ],
          ),

          // ── Tab Views ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AdminAudiobooksScreen(
                  key: ValueKey('content-all'),
                  embedded: true,
                  contentTypeFilter: null,
                ),
                AdminAudiobooksScreen(
                  key: ValueKey('content-books'),
                  embedded: true,
                  contentTypeFilter: 'books',
                ),
                AdminAudiobooksScreen(
                  key: ValueKey('content-music'),
                  embedded: true,
                  contentTypeFilter: 'music',
                ),
                AdminAudiobooksScreen(
                  key: ValueKey('content-podcasts'),
                  embedded: true,
                  contentTypeFilter: 'podcasts',
                ),
                AdminAudiobooksScreen(
                  key: ValueKey('content-articles'),
                  embedded: true,
                  contentTypeFilter: 'articles',
                ),
                AdminEbooksScreen(
                  key: ValueKey('content-ebooks'),
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
