import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/review/rating_stars.dart';
import 'package:myna/widgets/review/review_card.dart';
import 'package:myna/screens/listener/write_review_screen.dart';
import 'package:myna/utils/farsi_utils.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final int audiobookId;
  final String audiobookTitle;
  final double averageRating;
  final int reviewCount;
  const ReviewsScreen({super.key, required this.audiobookId, required this.audiobookTitle, required this.averageRating, required this.reviewCount});
  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.from('reviews')
        .select('*, profiles(id, display_name, full_name, avatar_url)')
        .eq('audiobook_id', widget.audiobookId as Object).eq('is_approved', true as Object)
        .order('created_at', ascending: false);
      setState(() { _reviews = List<Map<String, dynamic>>.from(response); _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _openWriteReview({Map<String, dynamic>? existing}) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => WriteReviewScreen(
      audiobookId: widget.audiobookId, audiobookTitle: widget.audiobookTitle, existingReview: existing)));
    if (result == true) _loadData();
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl,
      child: AlertDialog(backgroundColor: AppColors.surface, title: const Text('حذف نظر'), content: const Text('آیا از حذف نظر اطمینان دارید؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('حذف'))])));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('reviews').delete().eq('id', review['id'] as Object);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نظر حذف شد'), backgroundColor: AppColors.success));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('نظرات کاربران'), centerTitle: true),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadData, color: AppColors.primary, child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [Text(FarsiUtils.toFarsiDigits(widget.averageRating.toStringAsFixed(1)), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RatingStars(rating: widget.averageRating, size: 20),
                const SizedBox(height: 4), Text('از ${FarsiUtils.toFarsiDigits(widget.reviewCount)} نظر', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))])])))),
          _reviews.isEmpty
            ? SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                const SizedBox(height: 16), const Text('هنوز نظری ثبت نشده', style: TextStyle(color: AppColors.textSecondary))])))
            : SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final review = _reviews[index];
                final isOwn = review['user_id'] == userId;
                return ReviewCard(review: review, isOwn: isOwn, onEdit: isOwn ? () => _openWriteReview(existing: review) : null, onDelete: isOwn ? () => _deleteReview(review) : null);
              }, childCount: _reviews.length)))]))));
  }
}
