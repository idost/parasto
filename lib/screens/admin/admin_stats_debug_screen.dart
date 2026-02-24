import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Debug provider - fetches detailed statistics for troubleshooting
final adminDebugStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // 1. Get role distribution
    final allProfiles = await supabase.from('profiles').select('role');
    final roleDistribution = <String, int>{};
    int nullRoles = 0;

    for (final profile in allProfiles) {
      final role = profile['role'] as String?;
      if (role == null || role.isEmpty) {
        nullRoles++;
      } else {
        roleDistribution[role] = (roleDistribution[role] ?? 0) + 1;
      }
    }

    // 2. Get narrators who have uploaded content
    final narratorsWithContent = await supabase
        .from('profiles')
        .select('id, display_name, role, email')
        .inFilter('id', await _getNarratorsWithAudiobooks(supabase));

    // 3. Get audiobook status distribution
    final allAudiobooks = await supabase.from('audiobooks').select('status');
    final statusDistribution = <String, int>{};

    for (final book in allAudiobooks) {
      final status = (book['status'] as String?) ?? 'null';
      statusDistribution[status] = (statusDistribution[status] ?? 0) + 1;
    }

    // 4. Get purchase stats
    final allPurchases = await supabase.from('purchases').select('amount');
    final totalRevenue = allPurchases.fold<int>(
      0,
      (sum, p) => sum + ((p['amount'] as int?) ?? 0),
    );

    // 5. Get profiles with invalid roles
    final invalidRoles = await supabase
        .from('profiles')
        .select('id, display_name, email, role, created_at')
        .not('role', 'in', '(listener,narrator,admin)')
        .limit(50);

    return {
      'total_profiles': allProfiles.length,
      'role_distribution': roleDistribution,
      'null_roles': nullRoles,
      'narrators_with_content': narratorsWithContent,
      'status_distribution': statusDistribution,
      'total_purchases': allPurchases.length,
      'total_revenue': totalRevenue,
      'invalid_roles': invalidRoles,
    };
  } catch (e) {
    AppLogger.e('Error fetching debug stats', error: e);
    rethrow;
  }
});

/// Helper to get narrator IDs who have uploaded audiobooks
Future<List<String>> _getNarratorsWithAudiobooks(SupabaseClient supabase) async {
  final audiobooks = await supabase
      .from('audiobooks')
      .select('narrator_id')
      .not('narrator_id', 'is', null);

  return audiobooks
      .map((a) => a['narrator_id'] as String)
      .toSet()
      .toList();
}

class AdminStatsDebugScreen extends ConsumerWidget {
  const AdminStatsDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDebugStatsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('تشخیص مشکلات آمار'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(adminDebugStatsProvider),
            ),
          ],
        ),
        body: statsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'خطا در بارگذاری آمار',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(adminDebugStatsProvider),
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            ),
          ),
          data: (stats) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDebugStatsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('خلاصه کلی'),
                  _buildInfoCard(
                    'تعداد کل کاربران',
                    FarsiUtils.toFarsiDigits(stats['total_profiles'] as int),
                    Icons.people,
                    AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    'کاربران بدون نقش (NULL)',
                    FarsiUtils.toFarsiDigits(stats['null_roles'] as int),
                    Icons.warning,
                    stats['null_roles'] as int > 0 ? AppColors.error : AppColors.success,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('توزیع نقش‌ها (Role Distribution)'),
                  _buildRoleDistribution(stats['role_distribution'] as Map<String, int>),

                  const SizedBox(height: 24),
                  _buildSectionHeader('وضعیت کتاب‌ها'),
                  _buildStatusDistribution(stats['status_distribution'] as Map<String, int>),

                  const SizedBox(height: 24),
                  _buildSectionHeader('آمار خریدها'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'تعداد خریدها',
                          FarsiUtils.toFarsiDigits(stats['total_purchases'] as int),
                          Icons.shopping_cart,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoCard(
                          'کل درآمد',
                          FarsiUtils.formatPriceFarsi(stats['total_revenue'] as int),
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('گویندگان با محتوا'),
                  _buildNarratorsWithContent(stats['narrators_with_content'] as List),

                  if ((stats['invalid_roles'] as List).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('نقش‌های نامعتبر ⚠️'),
                    _buildInvalidRoles(stats['invalid_roles'] as List),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDistribution(Map<String, int> distribution) {
    final roles = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: roles.map((entry) {
          final roleLabel = _getRoleFarsiLabel(entry.key);
          final color = _getRoleColor(entry.key);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$roleLabel (${entry.key})',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  FarsiUtils.toFarsiDigits(entry.value),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusDistribution(Map<String, int> distribution) {
    final statuses = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: statuses.map((entry) {
          final statusLabel = _getStatusFarsiLabel(entry.key);
          final color = _getStatusColor(entry.key);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$statusLabel (${entry.key})',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  FarsiUtils.toFarsiDigits(entry.value),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNarratorsWithContent(List<dynamic> narrators) {
    if (narrators.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'هیچ گوینده‌ای محتوا آپلود نکرده',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعداد: ${FarsiUtils.toFarsiDigits(narrators.length)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...narrators.take(10).map((narrator) {
            final role = narrator['role'] as String?;
            // Only flag if they have listener role but uploaded content
            final isListenerRole = role == 'listener';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isListenerRole ? Icons.warning : Icons.check_circle,
                    color: isListenerRole ? AppColors.error : AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          narrator['display_name'] as String? ?? 'بدون نام',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'نقش: $role',
                          style: TextStyle(
                            fontSize: 11,
                            color: isListenerRole ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (narrators.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'و ${FarsiUtils.toFarsiDigits(narrators.length - 10)} مورد دیگر...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvalidRoles(List<dynamic> profiles) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'کاربران با نقش نامعتبر: ${FarsiUtils.toFarsiDigits(profiles.length)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...profiles.map((profile) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${profile['display_name'] ?? 'بدون نام'} - نقش: "${profile['role'] ?? "NULL"}"',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getRoleFarsiLabel(String role) {
    switch (role) {
      case 'listener':
        return 'شنونده';
      case 'narrator':
        return 'گوینده';
      case 'admin':
        return 'مدیر';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'listener':
        return AppColors.primary;
      case 'narrator':
        return AppColors.secondary;
      case 'admin':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusFarsiLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'در انتظار تأیید';
      case 'approved':
        return 'تأیید شده';
      case 'rejected':
        return 'رد شده';
      case 'draft':
        return 'پیش‌نویس';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'draft':
        return AppColors.textSecondary;
      default:
        return AppColors.textTertiary;
    }
  }
}
