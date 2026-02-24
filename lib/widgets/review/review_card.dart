import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/review/rating_stars.dart';
import 'package:myna/utils/farsi_utils.dart';

class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReviewCard({super.key, required this.review, this.isOwn = false, this.onEdit, this.onDelete});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) return diff.inHours == 0 ? '${FarsiUtils.toFarsiDigits(diff.inMinutes)} دقیقه پیش' : '${FarsiUtils.toFarsiDigits(diff.inHours)} ساعت پیش';
      if (diff.inDays < 7) return '${FarsiUtils.toFarsiDigits(diff.inDays)} روز پیش';
      if (diff.inDays < 30) return '${FarsiUtils.toFarsiDigits((diff.inDays / 7).floor())} هفته پیش';
      return '${FarsiUtils.toFarsiDigits((diff.inDays / 30).floor())} ماه پیش';
    } catch (e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final profile = review['profiles'] as Map<String, dynamic>?;
    final userName = (profile?['display_name'] as String?) ?? (profile?['full_name'] as String?) ?? 'کاربر';
    final avatarUrl = profile?['avatar_url'] as String?;
    final rating = review['rating'] as int? ?? 0;
    final title = review['title'] as String?;
    final content = review['content'] as String?;
    final createdAt = review['created_at'] as String?;

    return Card(color: AppColors.surface, margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundColor: AppColors.surfaceLight,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [RatingStars(rating: rating.toDouble(), size: 14), const SizedBox(width: 8),
              Text(_formatDate(createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary))])])),
          if (isOwn) PopupMenuButton<String>(icon: const Icon(Icons.more_vert, color: AppColors.textTertiary), color: AppColors.surface,
            onSelected: (v) {
              if (v == 'edit' && onEdit != null) {
                onEdit!();
              } else if (v == 'delete' && onDelete != null) {
                onDelete!();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: AppColors.primary), SizedBox(width: 8), Text('ویرایش')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.error), SizedBox(width: 8), Text('حذف', style: TextStyle(color: AppColors.error))]))])]),
        if (title != null && title.isNotEmpty) ...[const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary))],
        if (content != null && content.isNotEmpty) ...[const SizedBox(height: 8), Text(content, style: const TextStyle(color: AppColors.textSecondary, height: 1.5))],
      ])));
  }
}
