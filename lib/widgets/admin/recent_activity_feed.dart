import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Activity type enum
enum ActivityType {
  newUser,
  purchase,
  review,
  contentSubmitted,
  contentApproved,
  supportTicket,
}

/// Activity item model
class ActivityItem {
  final String id;
  final ActivityType type;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ActivityItem({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.metadata,
  });
}

/// Provider to fetch recent activity
final recentActivityProvider = FutureProvider<List<ActivityItem>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final activities = <ActivityItem>[];

    // Fetch recent data in parallel
    // Fetch more items from each source to get a diverse mix of recent activity
    final results = await Future.wait([
      // Recent users (limit 10)
      supabase
          .from('profiles')
          .select('id, display_name, created_at')
          .order('created_at', ascending: false)
          .limit(10),

      // Recent purchases (limit 10)
      supabase
          .from('purchases')
          .select('id, audiobook_id, created_at')
          .order('created_at', ascending: false)
          .limit(10),

      // Recent audiobook submissions (limit 10)
      supabase
          .from('audiobooks')
          .select('id, title_fa, status, created_at')
          .eq('status', 'submitted')
          .order('created_at', ascending: false)
          .limit(10),
    ]);

    final newUsers = results[0] as List;
    final purchases = results[1] as List;
    final submissions = results[2] as List;

    // Convert to ActivityItems (toString() handles both int and String PKs)
    for (final user in newUsers) {
      final displayName = user['display_name'] as String? ?? 'کاربر جدید';
      activities.add(ActivityItem(
        id: user['id'].toString(),
        type: ActivityType.newUser,
        description: '$displayName ثبت‌نام کرد',
        timestamp: DateTime.parse(user['created_at'] as String),
      ));
    }

    for (final purchase in purchases) {
      activities.add(ActivityItem(
        id: purchase['id'].toString(),
        type: ActivityType.purchase,
        description: 'خرید جدید انجام شد',
        timestamp: DateTime.parse(purchase['created_at'] as String),
        metadata: {'audiobook_id': purchase['audiobook_id']},
      ));
    }

    for (final submission in submissions) {
      final title = submission['title_fa'] as String;
      activities.add(ActivityItem(
        id: submission['id'].toString(),
        type: ActivityType.contentSubmitted,
        description: 'محتوای جدید: $title',
        timestamp: DateTime.parse(submission['created_at'] as String),
      ));
    }

    // Sort by timestamp (newest first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Return top 8 most recent
    return activities.take(8).toList();
  } catch (e) {
    AppLogger.e('Error fetching recent activity', error: e);
    rethrow;
  }
});

/// Recent activity feed widget for dashboard
class RecentActivityFeed extends ConsumerWidget {
  const RecentActivityFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivityProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with warm gradient background
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.06),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.history,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'فعالیت‌های اخیر',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Activity list
          activitiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'خطا در بارگذاری: $error',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
            data: (activities) {
              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 42,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'فعالیتی یافت نشد',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'فعالیت‌های اخیر اینجا نمایش داده می‌شوند',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 16, top: 4),
                itemCount: activities.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.borderSubtle,
                  indent: 48,
                ),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _buildActivityItem(activity);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    final icon = _getActivityIcon(activity.type);
    final color = _getActivityColor(activity.type);
    final timeAgo = _formatTimeAgo(activity.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with glow
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 11, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Optional badge
          if (activity.type == ActivityType.contentSubmitted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Text(
                'جدید',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.newUser:
        return Icons.person_add_rounded;
      case ActivityType.purchase:
        return Icons.shopping_bag_rounded;
      case ActivityType.review:
        return Icons.star_rounded;
      case ActivityType.contentSubmitted:
        return Icons.upload_file_rounded;
      case ActivityType.contentApproved:
        return Icons.check_circle_rounded;
      case ActivityType.supportTicket:
        return Icons.support_agent_rounded;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.newUser:
        return AppColors.primary;
      case ActivityType.purchase:
        return Colors.green;
      case ActivityType.review:
        return Colors.amber;
      case ActivityType.contentSubmitted:
        return AppColors.warning;
      case ActivityType.contentApproved:
        return AppColors.success;
      case ActivityType.supportTicket:
        return AppColors.secondary;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'لحظاتی پیش';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه پیش';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت پیش';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return '${FarsiUtils.toFarsiDigits(days)} روز پیش';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${FarsiUtils.toFarsiDigits(months)} ماه پیش';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${FarsiUtils.toFarsiDigits(years)} سال پیش';
    }
  }
}
