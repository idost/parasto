import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/services/user_analytics_service.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUpdate;

  const AdminUserDetailScreen({super.key, required this.user, required this.onUpdate});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _user;
  bool _isLoading = false;
  bool _isSavingNote = false;
  late TextEditingController _adminNoteController;
  late TabController _tabController;
  final UserAnalyticsService _analyticsService = UserAnalyticsService();

  // Analytics data
  ListenerStats? _listenerStats;
  NarratorStats? _narratorStats;
  List<ListeningActivity>? _recentActivity;
  List<LibraryItem>? _library;
  List<ContentPerformance>? _topContent;
  bool _isLoadingAnalytics = true;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _adminNoteController = TextEditingController(text: _user['admin_note'] as String? ?? '');

    final role = _user['role'] as String? ?? 'listener';
    // 3 tabs for narrators (Overview, Performance, Activity), 3 for listeners (Overview, Library, Activity)
    _tabController = TabController(length: 3, vsync: this);

    _loadAnalytics(role);
  }

  Future<void> _loadAnalytics(String role) async {
    setState(() => _isLoadingAnalytics = true);

    final userId = _user['id'] as String;

    try {
      // Load common data
      _recentActivity = await _analyticsService.getRecentActivity(userId);
      _library = await _analyticsService.getUserLibrary(userId);

      if (role == 'narrator' || role == 'admin') {
        _narratorStats = await _analyticsService.getNarratorStats(userId);
        _topContent = await _analyticsService.getNarratorTopContent(userId);
      }

      _listenerStats = await _analyticsService.getListenerStats(userId);
    } catch (e) {
      AppLogger.e('Error loading analytics for $userId', error: e);
    }

    if (mounted) {
      setState(() => _isLoadingAnalytics = false);
    }
  }

  @override
  void dispose() {
    _adminNoteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changeRole(String newRole) async {
    final userId = _user['id'] as String;
    final oldRole = _user['role'] as String? ?? 'listener';

    if (newRole == oldRole) return;

    AppLogger.i('Admin changing user role: userId=$userId, oldRole=$oldRole, newRole=$newRole');

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId)
          .select('role')
          .maybeSingle();

      if (response == null) {
        AppLogger.e('Role update failed: No response from server');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در تغییر نقش کاربر. دسترسی رد شد.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final updatedRole = response['role'] as String?;
      if (updatedRole != newRole) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در تغییر نقش کاربر.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() => _user['role'] = newRole);
      widget.onUpdate();
      _loadAnalytics(newRole); // Reload analytics for new role

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نقش کاربر با موفقیت تغییر کرد.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Role update exception', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDisabled() async {
    setState(() => _isLoading = true);
    try {
      final newValue = !(_user['is_disabled'] == true);
      await Supabase.instance.client
          .from('profiles')
          .update({'is_disabled': newValue})
          .eq('id', _user['id'] as Object);
      setState(() => _user['is_disabled'] = newValue);
      widget.onUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'کاربر غیرفعال شد' : 'کاربر فعال شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAdminNote() async {
    setState(() => _isSavingNote = true);
    try {
      final note = _adminNoteController.text.trim();
      await Supabase.instance.client
          .from('profiles')
          .update({'admin_note': note.isEmpty ? null : note})
          .eq('id', _user['id'] as Object);
      setState(() => _user['admin_note'] = note.isEmpty ? null : note);
      widget.onUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('یادداشت ذخیره شد'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSavingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _user['role'] as String? ?? 'listener';
    final avatarUrl = _user['avatar_url'] as String?;
    final displayName = (_user['display_name'] as String?) ?? (_user['full_name'] as String?) ?? 'کاربر';
    final email = (_user['email'] as String?) ?? '';
    final isDisabled = _user['is_disabled'] == true;
    final isNarrator = role == 'narrator' || role == 'admin';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // App Bar with user info
                  SliverAppBar(
                    backgroundColor: AppColors.surface,
                    expandedHeight: 200,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.surface,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              // Avatar
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: AppColors.surfaceLight,
                                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                            style: const TextStyle(fontSize: 28, color: AppColors.textSecondary),
                                          )
                                        : null,
                                  ),
                                  if (isDisabled)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.block, size: 14, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(height: 8),
                              _buildRoleBadge(role),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tab Bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        tabs: [
                          const Tab(text: 'نمای کلی'),
                          Tab(text: isNarrator ? 'عملکرد' : 'کتابخانه'),
                          const Tab(text: 'فعالیت'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Overview
                    _buildOverviewTab(role, isDisabled),

                    // Tab 2: Performance (narrators) or Library (listeners)
                    isNarrator ? _buildPerformanceTab() : _buildLibraryTab(),

                    // Tab 3: Activity
                    _buildActivityTab(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;
    IconData icon;

    switch (role) {
      case 'narrator':
        color = AppColors.secondary;
        label = 'گوینده';
        icon = Icons.mic;
        break;
      case 'admin':
        color = Colors.purple;
        label = 'مدیر';
        icon = Icons.admin_panel_settings;
        break;
      default:
        color = AppColors.primary;
        label = 'شنونده';
        icon = Icons.headphones;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(String role, bool isDisabled) {
    final createdAt = _user['created_at'] != null ? DateTime.tryParse(_user['created_at'] as String) : null;
    final bio = _user['bio'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          if (_listenerStats != null) ...[
            _buildSectionHeader('آمار کلی', Icons.analytics_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('ساعت شنیدن', _listenerStats!.totalHours.toStringAsFixed(1), Icons.headphones_rounded, AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('محتوای شنیده', _listenerStats!.uniqueAudiobooks.toString(), Icons.library_music_rounded, AppColors.secondary)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('خریدها', _listenerStats!.purchaseCount.toString(), Icons.shopping_bag_rounded, AppColors.success)),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Disabled status warning
          if (isDisabled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('این کاربر غیرفعال است و نمی‌تواند وارد شود', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Info section
          _buildSectionHeader('اطلاعات کاربر', Icons.person_rounded),
          const SizedBox(height: 12),
          _buildInfoCard([
            if (bio != null && bio.isNotEmpty) _buildInfoRow('بیو', bio),
            if (createdAt != null)
              _buildInfoRow('تاریخ عضویت', '${FarsiUtils.toFarsiDigits(createdAt.year)}/${FarsiUtils.toFarsiDigits(createdAt.month)}/${FarsiUtils.toFarsiDigits(createdAt.day)}'),
            _buildInfoRow('روزهای فعال', FarsiUtils.toFarsiDigits(_listenerStats?.activeDays ?? 0)),
            _buildInfoRow('تعداد جلسات', FarsiUtils.toFarsiDigits(_listenerStats?.totalSessions ?? 0)),
          ]),
          const SizedBox(height: 24),

          // Role selection
          _buildSectionHeader('نقش کاربر', Icons.badge_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              _roleChip('listener', 'شنونده', role, AppColors.primary),
              const SizedBox(width: 8),
              _roleChip('narrator', 'گوینده', role, AppColors.secondary),
              const SizedBox(width: 8),
              _roleChip('admin', 'مدیر', role, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Disable/Enable toggle
          _buildSectionHeader('وضعیت حساب', Icons.security_rounded),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: SwitchListTile(
              title: Text(
                isDisabled ? 'فعال کردن کاربر' : 'غیرفعال کردن کاربر',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                isDisabled ? 'کاربر قادر به ورود نیست' : 'کاربر می‌تواند وارد شود',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: isDisabled,
              onChanged: (_) => _toggleDisabled(),
              activeColor: AppColors.error,
              secondary: Icon(
                isDisabled ? Icons.block : Icons.check_circle,
                color: isDisabled ? AppColors.error : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Admin note
          _buildSectionHeader('یادداشت مدیر', Icons.note_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _adminNoteController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'یادداشت درباره این کاربر...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingNote ? null : _saveAdminNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSavingNote
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('ذخیره یادداشت'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_narratorStats == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('اطلاعات عملکرد موجود نیست', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final stats = _narratorStats!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance stats
          _buildSectionHeader('آمار عملکرد', Icons.trending_up_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('کل محتوا', stats.totalContent.toString(), Icons.library_books_rounded, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('تأیید شده', stats.approvedCount.toString(), Icons.check_circle_rounded, AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('در انتظار', stats.pendingCount.toString(), Icons.pending_rounded, AppColors.warning)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('پخش‌ها', FarsiUtils.toFarsiDigits(stats.totalPlays), Icons.play_arrow_rounded, AppColors.secondary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('ساعت شنیده', stats.totalListenHours.toStringAsFixed(1), Icons.headphones_rounded, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('امتیاز', stats.avgRating > 0 ? stats.avgRating.toStringAsFixed(1) : '-', Icons.star_rounded, AppColors.warning)),
            ],
          ),
          const SizedBox(height: 24),

          // Revenue & Sales
          _buildSectionHeader('فروش و درآمد', Icons.monetization_on_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        FarsiUtils.toFarsiDigits(stats.totalPurchases),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                      const SizedBox(height: 4),
                      const Text('تعداد فروش', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.borderSubtle),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '\$${stats.totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      const Text('کل درآمد', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Top content
          if (_topContent != null && _topContent!.isNotEmpty) ...[
            _buildSectionHeader('محتوای برتر', Icons.emoji_events_rounded),
            const SizedBox(height: 12),
            ...List.generate(_topContent!.length, (index) {
              final content = _topContent![index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index == 0 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index == 0 ? AppColors.warning : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Cover
                    Container(
                      width: 40,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: content.coverUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(content.coverUrl!, fit: BoxFit.cover),
                            )
                          : Icon(
                              content.isMusic ? Icons.music_note : Icons.book,
                              color: AppColors.textTertiary,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.title,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${FarsiUtils.toFarsiDigits(content.playCount)} پخش',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (content.avgRating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            content.avgRating.toStringAsFixed(1),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_library == null || _library!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('کتابخانه خالی است', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _library!.length,
      itemBuilder: (context, index) {
        final item = _library![index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 65,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(item.coverUrl!, fit: BoxFit.cover),
                      )
                    : Icon(
                        item.isMusic ? Icons.music_note : Icons.book,
                        color: AppColors.textTertiary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(item.isMusic ? Icons.music_note : Icons.book, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          item.isMusic ? 'موسیقی' : 'کتاب',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${FarsiUtils.toFarsiDigits(item.grantedAt.year)}/${FarsiUtils.toFarsiDigits(item.grantedAt.month)}/${FarsiUtils.toFarsiDigits(item.grantedAt.day)}',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_recentActivity == null || _recentActivity!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('فعالیتی ثبت نشده', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentActivity!.length,
      itemBuilder: (context, index) {
        final activity = _recentActivity![index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.headphones_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.audiobookTitle ?? 'محتوای ناشناخته',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FarsiUtils.toFarsiDigits(activity.date.year)}/${FarsiUtils.toFarsiDigits(activity.date.month)}/${FarsiUtils.toFarsiDigits(activity.date.day)}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                FarsiUtils.formatDurationFarsi(activity.durationSeconds),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String value, String label, String currentRole, Color color) {
    final isSelected = currentRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeRole(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : AppColors.borderSubtle),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliver delegate for sticky tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
