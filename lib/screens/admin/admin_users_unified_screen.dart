import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/screens/admin/admin_users_screen.dart';
import 'package:myna/screens/admin/admin_user_detail_screen.dart';
import 'package:myna/screens/admin/admin_narrator_request_detail_screen.dart';
import 'package:myna/providers/narrator_request_providers.dart';
import 'package:myna/models/narrator_request.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';

/// User type for the unified users hub
enum UsersHubType {
  listeners,
  narrators,
  requests,
}

/// Provider for tracking the active user type in the hub
final usersHubTypeProvider = StateProvider<UsersHubType>((ref) => UsersHubType.listeners);

/// Unified Users Hub Screen for admin
///
/// This screen consolidates all user management into a single location:
/// - شنونده‌ها (Listeners)
/// - راوی‌ها (Narrators)
/// - درخواست‌ها (Requests - narrator onboarding requests)
class AdminUsersUnifiedScreen extends ConsumerStatefulWidget {
  /// Optional initial user type to display
  final UsersHubType? initialType;

  const AdminUsersUnifiedScreen({super.key, this.initialType});

  @override
  ConsumerState<AdminUsersUnifiedScreen> createState() => _AdminUsersUnifiedScreenState();
}

class _AdminUsersUnifiedScreenState extends ConsumerState<AdminUsersUnifiedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    UsersHubType.listeners,
    UsersHubType.narrators,
    UsersHubType.requests,
  ];

  @override
  void initState() {
    super.initState();

    final initialIndex = widget.initialType != null ? _tabs.indexOf(widget.initialType!) : 0;

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );

    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref.read(usersHubTypeProvider.notifier).state = _tabs[_tabController.index];
    }
  }

  void _refreshAll() {
    // Invalidate all user-related providers
    ref.invalidate(adminUsersSearchProvider(const UserSearchParams(role: 'listener')));
    ref.invalidate(adminUsersSearchProvider(const UserSearchParams(role: 'narrator')));
    ref.invalidate(adminNarratorRequestsProvider(null));
    ref.invalidate(narratorRequestStatsProvider);
    ref.invalidate(pendingNarratorRequestsCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Clean minimal header
          _buildHeader(),

          // User type tabs
          _buildUserTypeTabs(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ListenersTab(),
                _NarratorsTab(),
                _RequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Get counts for summary
    final listenersAsync = ref.watch(adminUsersSearchProvider(const UserSearchParams(role: 'listener')));
    final narratorsAsync = ref.watch(adminUsersSearchProvider(const UserSearchParams(role: 'narrator')));
    final pendingRequestsAsync = ref.watch(pendingNarratorRequestsCountProvider);

    final listenersCount = listenersAsync.valueOrNull?.length ?? 0;
    final narratorsCount = narratorsAsync.valueOrNull?.length ?? 0;
    final pendingCount = pendingRequestsAsync.valueOrNull ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Title and icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.small,
            ),
            child: const Icon(
              Icons.people_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Title and summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('کاربران', style: AppTypography.headlineMedium),
                const SizedBox(height: 2),
                Text(
                  '${FarsiUtils.toFarsiDigits(listenersCount)} شنونده • '
                  '${FarsiUtils.toFarsiDigits(narratorsCount)} راوی • '
                  '${FarsiUtils.toFarsiDigits(pendingCount)} درخواست در انتظار',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _refreshAll,
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeTabs() {
    final pendingCount = ref.watch(pendingNarratorRequestsCountProvider).valueOrNull ?? 0;

    return ColoredBox(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        isScrollable: false,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelMedium,
        tabs: [
          _buildTab(Icons.headphones_rounded, 'شنونده‌ها'),
          _buildTab(Icons.mic_rounded, 'راوی‌ها'),
          _buildTabWithBadge(Icons.person_add_rounded, 'درخواست‌ها', pendingCount),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildTabWithBadge(IconData icon, String label, int badgeCount) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(label),
          if (badgeCount > 0) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 99 ? '۹۹+' : FarsiUtils.toFarsiDigits(badgeCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Tab Content Widgets
// =============================================================================

/// Listeners tab content
class _ListenersTab extends ConsumerStatefulWidget {
  const _ListenersTab();

  @override
  ConsumerState<_ListenersTab> createState() => _ListenersTabState();
}

class _ListenersTabState extends ConsumerState<_ListenersTab> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'disabled'
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(
      adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'listener')),
    );

    return Column(
      children: [
        // Search and filter bar
        _buildSearchBar(),

        // Status filter chips
        _buildStatusFilters(),

        // Users list
        Expanded(
          child: usersAsync.when(
            loading: () => const LoadingState(message: 'در حال بارگذاری شنوندگان...'),
            error: (e, _) => ErrorState(
              message: 'خطا در بارگذاری شنوندگان',
              onRetry: () => ref.invalidate(
                adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'listener')),
              ),
            ),
            data: (users) {
              // Apply client-side status filter
              final filteredUsers = _filterByStatus(users);

              if (filteredUsers.isEmpty) {
                return EmptyState(
                  icon: Icons.person_search_rounded,
                  message: 'شنونده‌ای یافت نشد',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'جستجوی دیگری را امتحان کنید'
                      : _statusFilter != 'all'
                          ? 'هیچ کاربری با این وضعیت یافت نشد'
                          : null,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(
                  adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'listener')),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) => _UserRowCard(
                    user: filteredUsers[index],
                    roleLabel: 'شنونده',
                    onTap: () => _openUserDetail(filteredUsers[index]),
                    onRefresh: () => ref.invalidate(
                      adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'listener')),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'جستجوی نام، ایمیل یا شماره...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _buildFilterChip('همه', 'all'),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('فعال', 'active'),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('غیرفعال', 'disabled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = selected ? value : 'all');
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
      ),
    );
  }

  List<Map<String, dynamic>> _filterByStatus(List<Map<String, dynamic>> users) {
    if (_statusFilter == 'all') return users;

    return users.where((user) {
      final isDisabled = user['is_disabled'] == true;
      if (_statusFilter == 'active') return !isDisabled;
      if (_statusFilter == 'disabled') return isDisabled;
      return true;
    }).toList();
  }

  void _openUserDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminUserDetailScreen(
          user: user,
          onUpdate: () => ref.invalidate(
            adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'listener')),
          ),
        ),
      ),
    );
  }
}

/// Narrators tab content
class _NarratorsTab extends ConsumerStatefulWidget {
  const _NarratorsTab();

  @override
  ConsumerState<_NarratorsTab> createState() => _NarratorsTabState();
}

class _NarratorsTabState extends ConsumerState<_NarratorsTab> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(
      adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'narrator')),
    );

    return Column(
      children: [
        // Search bar
        _buildSearchBar(),

        // Status filter chips
        _buildStatusFilters(),

        // Narrators list
        Expanded(
          child: usersAsync.when(
            loading: () => const LoadingState(message: 'در حال بارگذاری راوی‌ها...'),
            error: (e, _) => ErrorState(
              message: 'خطا در بارگذاری راوی‌ها',
              onRetry: () => ref.invalidate(
                adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'narrator')),
              ),
            ),
            data: (users) {
              final filteredUsers = _filterByStatus(users);

              if (filteredUsers.isEmpty) {
                return EmptyState(
                  icon: Icons.mic_off_rounded,
                  message: 'راوی‌ای یافت نشد',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'جستجوی دیگری را امتحان کنید'
                      : _statusFilter != 'all'
                          ? 'هیچ راوی با این وضعیت یافت نشد'
                          : null,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(
                  adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'narrator')),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) => _UserRowCard(
                    user: filteredUsers[index],
                    roleLabel: 'راوی',
                    onTap: () => _openUserDetail(filteredUsers[index]),
                    onRefresh: () => ref.invalidate(
                      adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'narrator')),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'جستجوی نام، ایمیل یا شماره...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _buildFilterChip('همه', 'all'),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('فعال', 'active'),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('غیرفعال', 'disabled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = selected ? value : 'all');
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
      ),
    );
  }

  List<Map<String, dynamic>> _filterByStatus(List<Map<String, dynamic>> users) {
    if (_statusFilter == 'all') return users;

    return users.where((user) {
      final isDisabled = user['is_disabled'] == true;
      if (_statusFilter == 'active') return !isDisabled;
      if (_statusFilter == 'disabled') return isDisabled;
      return true;
    }).toList();
  }

  void _openUserDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminUserDetailScreen(
          user: user,
          onUpdate: () => ref.invalidate(
            adminUsersSearchProvider(UserSearchParams(query: _searchQuery, role: 'narrator')),
          ),
        ),
      ),
    );
  }
}

/// Requests tab content (narrator requests)
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  String? _statusFilter = 'pending'; // Default to pending

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminNarratorRequestsProvider(_statusFilter));
    final statsAsync = ref.watch(narratorRequestStatsProvider);

    return Column(
      children: [
        // Stats bar
        statsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.hourglass_empty_rounded,
                    value: stats['pending'] ?? 0,
                    label: 'در انتظار',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_rounded,
                    value: stats['approved'] ?? 0,
                    label: 'تأیید شده',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    icon: Icons.cancel_rounded,
                    value: stats['rejected'] ?? 0,
                    label: 'رد شده',
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Status filter chips
        _buildStatusFilters(),

        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1),

        // Requests list
        Expanded(
          child: requestsAsync.when(
            loading: () => const LoadingState(message: 'در حال بارگذاری درخواست‌ها...'),
            error: (e, _) => ErrorState(
              message: 'خطا در بارگذاری درخواست‌ها',
              onRetry: () => ref.invalidate(adminNarratorRequestsProvider(_statusFilter)),
            ),
            data: (requests) {
              if (requests.isEmpty) {
                return EmptyState(
                  icon: Icons.inbox_rounded,
                  message: _statusFilter == null ? 'درخواستی وجود ندارد' : 'درخواستی با این وضعیت یافت نشد',
                  subtitle: 'هنگامی که کاربران درخواست گویندگی می‌دهند، اینجا نمایش داده می‌شود',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminNarratorRequestsProvider(_statusFilter));
                  ref.invalidate(narratorRequestStatsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: requests.length,
                  itemBuilder: (context, index) => _RequestRowCard(
                    request: requests[index],
                    onTap: () => _openRequestDetail(requests[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _buildFilterChip('همه', null),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('در انتظار', 'pending'),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('تأیید شده', 'approved'),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('رد شده', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = selected ? value : null);
        ref.invalidate(adminNarratorRequestsProvider(_statusFilter));
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
      ),
    );
  }

  void _openRequestDetail(NarratorRequest request) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminNarratorRequestDetailScreen(request: request),
      ),
    );

    // Refresh data after returning
    ref.invalidate(adminNarratorRequestsProvider(_statusFilter));
    ref.invalidate(narratorRequestStatsProvider);
    ref.invalidate(pendingNarratorRequestsCountProvider);
  }
}

// =============================================================================
// Shared Components
// =============================================================================

/// User row card widget - reusable for listeners and narrators
class _UserRowCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String roleLabel;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const _UserRowCard({
    required this.user,
    required this.roleLabel,
    required this.onTap,
    required this.onRefresh,
  });

  Color _getRoleColor(String role) {
    return switch (role) {
      'admin' => Colors.purple,
      'narrator' => AppColors.secondary,
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? 'listener';
    final avatarUrl = user['avatar_url'] as String?;
    final displayName = (user['display_name'] as String?) ?? (user['full_name'] as String?) ?? 'کاربر';
    final email = (user['email'] as String?) ?? '';
    final phone = user['phone'] as String?;
    final isDisabled = user['is_disabled'] == true;
    final createdAt = user['created_at'] as String?;
    final roleColor = _getRoleColor(role);

    // Format created date
    String createdDateStr = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        createdDateStr =
            '${FarsiUtils.toFarsiDigits(date.year)}/${FarsiUtils.toFarsiDigits(date.month.toString().padLeft(2, '0'))}/${FarsiUtils.toFarsiDigits(date.day.toString().padLeft(2, '0'))}';
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isDisabled ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor.withValues(alpha: 0.1),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  if (isDisabled)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.block, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: AppSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDisabled ? AppColors.textTertiary : AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // Role + created date
                    Row(
                      children: [
                        Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: roleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (createdDateStr.isNotEmpty) ...[
                          Text(
                            ' • عضویت: $createdDateStr',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Email or phone
                    if (email.isNotEmpty || phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        email.isNotEmpty ? email : phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDisabled ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      isDisabled ? 'غیرفعال' : 'فعال',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Request row card widget - for narrator requests
class _RequestRowCard extends StatelessWidget {
  final NarratorRequest request;
  final VoidCallback onTap;

  const _RequestRowCard({
    required this.request,
    required this.onTap,
  });

  Color _getStatusColor(NarratorRequestStatus status) {
    return switch (status) {
      NarratorRequestStatus.pending => AppColors.warning,
      NarratorRequestStatus.approved => AppColors.success,
      NarratorRequestStatus.rejected => AppColors.error,
    };
  }

  IconData _getStatusIcon(NarratorRequestStatus status) {
    return switch (status) {
      NarratorRequestStatus.pending => Icons.hourglass_empty_rounded,
      NarratorRequestStatus.approved => Icons.check_circle_rounded,
      NarratorRequestStatus.rejected => Icons.cancel_rounded,
    };
  }

  String _formatDate(DateTime date) {
    return '${FarsiUtils.toFarsiDigits(date.year)}/'
        '${FarsiUtils.toFarsiDigits(date.month.toString().padLeft(2, '0'))}/'
        '${FarsiUtils.toFarsiDigits(date.day.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Status icon
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(
                  _getStatusIcon(request.status),
                  color: statusColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User ID (shortened)
                    Text(
                      'کاربر: ${request.userId.substring(0, 8)}...',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Experience text
                    Text(
                      request.experienceText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Date info
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(request.createdAt),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        ),
                        if (request.reviewedAt != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.done_all, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'بررسی: ${_formatDate(request.reviewedAt!)}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge and arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      request.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stat card for requests tab
class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                FarsiUtils.toFarsiDigits(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
