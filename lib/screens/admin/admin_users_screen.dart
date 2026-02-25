import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/admin/admin_user_detail_screen.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/admin_sidebar.dart';
import 'package:myna/widgets/admin/content_card.dart';
import 'package:myna/widgets/admin/status_badge.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/utils/app_logger.dart';

/// Search parameters for user search
class UserSearchParams {
  final String query;
  final String role;

  const UserSearchParams({this.query = '', this.role = 'all'});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSearchParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          role == other.role;

  @override
  int get hashCode => query.hashCode ^ role.hashCode;
}

/// Provider for searching users with server-side filtering
/// Supports full-text search across display_name, full_name, and email
final adminUsersSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, UserSearchParams>((ref, params) async {
  final query = params.query.trim().toLowerCase();
  final role = params.role;

  AppLogger.i('AdminUsersSearchProvider: query="$query", role="$role"');

  final supabase = Supabase.instance.client;

  // Build the base query
  var queryBuilder = supabase.from('profiles').select('*');

  // Apply role filter if not "all"
  if (role != 'all') {
    queryBuilder = queryBuilder.eq('role', role);
  }

  // Apply search filter if query is not empty
  // Use ilike for case-insensitive partial matching
  if (query.isNotEmpty) {
    // Search in display_name, full_name, or email
    queryBuilder = queryBuilder.or(
      'display_name.ilike.%$query%,full_name.ilike.%$query%,email.ilike.%$query%',
    );
  }

  // Order - fetch ALL users, no arbitrary limit
  // Admin needs to see all users for proper management
  final results = await queryBuilder
      .order('created_at', ascending: false);

  final users = List<Map<String, dynamic>>.from(results);

  // Log role distribution for debugging
  final roleCount = <String, int>{};
  for (final user in users) {
    final userRole = (user['role'] as String?) ?? 'null';
    roleCount[userRole] = (roleCount[userRole] ?? 0) + 1;
  }
  AppLogger.i('AdminUsersSearchProvider: Found ${users.length} users. Roles: $roleCount');

  return users;
});

// Legacy provider for backwards compatibility (no search)
final adminUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminUsersSearchProvider(const UserSearchParams()).future);
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  /// When true, hides AdminScreenHeader (used inside hub tabs)
  final bool embedded;
  /// Role filter passed from hub. Overrides route-based detection.
  /// Values: 'listener', 'narrator', 'admin', or null (all)
  final String? initialRole;

  const AdminUsersScreen({super.key, this.embedded = false, this.initialRole});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _filterRole = 'all';
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => widget.embedded;

  @override
  void initState() {
    super.initState();
    // Use constructor param if provided (hub mode), otherwise route detection
    if (widget.initialRole != null) {
      _filterRole = widget.initialRole!;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activeRoute = ref.read(adminActiveRouteProvider);
        setState(() {
          if (activeRoute == '/admin/people/listeners') {
            _filterRole = 'listener';
          } else if (activeRoute == '/admin/people/narrators') {
            _filterRole = 'narrator';
          } else if (activeRoute == '/admin/people/admins') {
            _filterRole = 'admin';
          } else {
            _filterRole = 'all';
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Use server-side search provider with current query and role filter
    final searchParams = UserSearchParams(query: _searchQuery, role: _filterRole);
    final usersAsync = ref.watch(adminUsersSearchProvider(searchParams));

    // Route-based role sync (only when NOT embedded — hub passes initialRole instead)
    if (!widget.embedded) {
      final activeRoute = ref.watch(adminActiveRouteProvider);

      if (activeRoute == '/admin/people/listeners' && _filterRole != 'listener') {
        Future.microtask(() => setState(() => _filterRole = 'listener'));
      } else if (activeRoute == '/admin/people/narrators' && _filterRole != 'narrator') {
        Future.microtask(() => setState(() => _filterRole = 'narrator'));
      } else if (activeRoute == '/admin/people/admins' && _filterRole != 'admin') {
        Future.microtask(() => setState(() => _filterRole = 'admin'));
      } else if (activeRoute == '/admin/people' && _filterRole != 'all') {
        Future.microtask(() => setState(() => _filterRole = 'all'));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header (hidden when embedded in hub)
          if (!widget.embedded) ...[
            AdminScreenHeader(
              title: _filterRole == 'listener' ? 'شنوندگان'
                  : _filterRole == 'narrator' ? 'گویندگان'
                  : _filterRole == 'admin' ? 'فهرست مدیران'
                  : 'مدیریت کاربران',
              icon: _filterRole == 'narrator' ? Icons.mic_rounded
                  : _filterRole == 'admin' ? Icons.admin_panel_settings_rounded
                  : Icons.people_rounded,
            ),
          ],
          // Search and filter
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'جستجوی کاربر...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.filter_list),
                  ),
                  color: AppColors.surface,
                  onSelected: (value) => setState(() => _filterRole = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'all', child: Text('همه')),
                    const PopupMenuItem(value: 'listener', child: Text('شنوندگان')),
                    const PopupMenuItem(value: 'narrator', child: Text('گویندگان')),
                    const PopupMenuItem(value: 'admin', child: Text('مدیران')),
                  ],
                ),
              ],
            ),
          ),
          // Filter chip
          if (_filterRole != 'all')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Chip(
                    label: Text(_getRoleLabel(_filterRole)),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _filterRole = 'all'),
                    backgroundColor: AppColors.surface,
                  ),
                ],
              ),
            ),
          // Users list
          Expanded(
            child: usersAsync.when(
              loading: () => const LoadingState(message: 'در حال بارگذاری کاربران...'),
              error: (e, _) => ErrorState(
                message: 'خطا در بارگذاری کاربران',
                onRetry: () => ref.invalidate(adminUsersSearchProvider(searchParams)),
              ),
              data: (users) {
                // Server-side filtering is already applied, just display results
                if (users.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search_rounded,
                    message: 'کاربری یافت نشد',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'جستجوی دیگری را امتحان کنید'
                        : _filterRole != 'all'
                            ? 'هیچ کاربری با این نقش یافت نشد'
                            : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminUsersSearchProvider(searchParams)),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: users.length,
                    itemBuilder: (context, index) => _UserCard(
                      user: users[index],
                      onUpdate: () => ref.invalidate(adminUsersSearchProvider(searchParams)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'مدیران';
      case 'narrator': return 'گویندگان';
      case 'listener': return 'شنوندگان';
      default: return role;
    }
  }
}

/// User card using modern ContentCard component
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUpdate;

  const _UserCard({required this.user, required this.onUpdate});

  /// Get role color and label
  (Color, String) _getRoleInfo(String role) {
    return switch (role) {
      'admin' => (Colors.purple, 'مدیر'),
      'narrator' => (AppColors.secondary, 'گوینده'),
      _ => (AppColors.primary, 'شنونده'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? 'listener';
    final avatarUrl = user['avatar_url'] as String?;
    final displayName = (user['display_name'] as String?) ?? (user['full_name'] as String?) ?? 'کاربر';
    final email = (user['email'] as String?) ?? '';
    final isDisabled = user['is_disabled'] == true;
    final (roleColor, roleLabel) = _getRoleInfo(role);

    return ContentCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => AdminUserDetailScreen(user: user, onUpdate: onUpdate)),
      ),
      accentColor: isDisabled ? AppColors.error : roleColor,
      leading: Stack(
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
                child: const Icon(Icons.block, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: isDisabled ? AppColors.textTertiary : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        email,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      badges: [
        StatusBadge(
          label: roleLabel,
          color: roleColor,
        ),
        if (isDisabled)
          StatusBadge(
            label: 'غیرفعال',
            color: AppColors.error,
            icon: Icons.block,
          ),
      ],
    );
  }
}