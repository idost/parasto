import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

final adminReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('reviews')
      .select('*, profiles(display_name, full_name), audiobooks(title_fa)')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class AdminReviewsScreen extends ConsumerWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(adminReviewsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('مدیریت نظرات'),
          centerTitle: true,
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(adminReviewsProvider))],
        ),
        body: reviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('خطا: $e', style: const TextStyle(color: AppColors.error))),
          data: (reviews) {
            if (reviews.isEmpty) {
              return const Center(child: Text('نظری یافت نشد', style: TextStyle(color: AppColors.textSecondary)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                final profile = review['profiles'] as Map<String, dynamic>?;
                final audiobook = review['audiobooks'] as Map<String, dynamic>?;
                final rating = review['rating'] as int? ?? 0;

                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((profile?['display_name'] as String?) ?? (profile?['full_name'] as String?) ?? 'کاربر', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('کتاب: ${(audiobook?['title_fa'] as String?) ?? 'نامشخص'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Row(
                              children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, size: 16, color: Colors.amber)),
                            ),
                          ],
                        ),
                        if (review['title'] != null) ...[
                          const SizedBox(height: 8),
                          Text(review['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                        if (review['content'] != null) ...[
                          const SizedBox(height: 4),
                          Text(review['content'] as String, style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _deleteReview(context, ref, review['id'] as int),
                              icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                              label: const Text('حذف', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteReview(BuildContext context, WidgetRef ref, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف نظر', style: TextStyle(color: AppColors.error)),
        content: const Text('آیا مطمئن هستید؟', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('reviews').delete().eq('id', id);
        ref.invalidate(adminReviewsProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نظر حذف شد'), backgroundColor: AppColors.success));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}