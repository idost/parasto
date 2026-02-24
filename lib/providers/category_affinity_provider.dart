import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Represents a user's affinity for a specific category
class CategoryAffinity {
  final int categoryId;
  final String categoryName;
  final int listenCount; // Number of audiobooks listened in this category
  final int totalListenTimeSeconds; // Total time spent in this category
  final double affinityScore; // Normalized score (0-1)

  const CategoryAffinity({
    required this.categoryId,
    required this.categoryName,
    required this.listenCount,
    required this.totalListenTimeSeconds,
    required this.affinityScore,
  });

  @override
  String toString() =>
      'CategoryAffinity($categoryName: score=$affinityScore, count=$listenCount)';
}

/// User's category preferences based on listening history
class UserCategoryProfile {
  final List<CategoryAffinity> topCategories;
  final int totalBooksListened;
  final int totalListenTimeSeconds;

  const UserCategoryProfile({
    required this.topCategories,
    required this.totalBooksListened,
    required this.totalListenTimeSeconds,
  });

  /// Get the top N category IDs (for filtering/boosting)
  List<int> getTopCategoryIds([int count = 3]) {
    return topCategories.take(count).map((c) => c.categoryId).toList();
  }

  /// Check if a category is in user's top preferences
  bool isPreferredCategory(int categoryId, [int topCount = 5]) {
    return topCategories.take(topCount).any((c) => c.categoryId == categoryId);
  }

  /// Get affinity score for a specific category (0 if not in profile)
  double getAffinityScore(int categoryId) {
    final affinity = topCategories.firstWhere(
      (c) => c.categoryId == categoryId,
      orElse: () => const CategoryAffinity(
        categoryId: -1,
        categoryName: '',
        listenCount: 0,
        totalListenTimeSeconds: 0,
        affinityScore: 0,
      ),
    );
    return affinity.affinityScore;
  }

  static const empty = UserCategoryProfile(
    topCategories: [],
    totalBooksListened: 0,
    totalListenTimeSeconds: 0,
  );
}

/// Provider for user's category affinity profile
/// Analyzes listening history to determine preferred categories
final categoryAffinityProvider =
    FutureProvider.autoDispose<UserCategoryProfile>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return UserCategoryProfile.empty;

  try {
    // Get user's listening progress with audiobook info
    final progressResponse = await Supabase.instance.client
        .from('listening_progress')
        .select('''
          audiobook_id,
          completion_percentage,
          total_listen_time_seconds,
          audiobooks!inner(id, category_id, is_music, categories(id, name_fa))
        ''')
        .eq('user_id', user.id as Object)
        .gt('completion_percentage', 10) // At least 10% listened
        .eq('audiobooks.is_music', false); // Only audiobooks, not music

    if ((progressResponse as List).isEmpty) {
      return UserCategoryProfile.empty;
    }

    // Aggregate by category
    final categoryStats = <int, _CategoryStats>{};
    int totalBooks = 0;
    int totalTime = 0;

    for (final item in progressResponse) {
      final audiobook = item['audiobooks'] as Map<String, dynamic>?;
      if (audiobook == null) continue;

      final categoryId = audiobook['category_id'] as int?;
      if (categoryId == null) continue;

      final category = audiobook['categories'] as Map<String, dynamic>?;
      final categoryName = (category?['name_fa'] as String?) ?? '';

      final listenTime =
          (item['total_listen_time_seconds'] as num?)?.toInt() ?? 0;
      final completion =
          (item['completion_percentage'] as num?)?.toDouble() ?? 0;

      // Weight by completion percentage (completed books count more)
      final weight = completion >= 80 ? 1.5 : (completion >= 50 ? 1.2 : 1.0);

      categoryStats.putIfAbsent(
        categoryId,
        () => _CategoryStats(categoryId, categoryName),
      );
      categoryStats[categoryId]!.addListen(listenTime, weight);

      totalBooks++;
      totalTime += listenTime;
    }

    if (categoryStats.isEmpty) {
      return UserCategoryProfile.empty;
    }

    // Calculate affinity scores and sort by score
    final maxScore = categoryStats.values
        .map((s) => s.weightedScore)
        .reduce((a, b) => a > b ? a : b);

    final affinities = categoryStats.values.map((stats) {
      return CategoryAffinity(
        categoryId: stats.categoryId,
        categoryName: stats.categoryName,
        listenCount: stats.listenCount,
        totalListenTimeSeconds: stats.totalListenTime,
        affinityScore: maxScore > 0 ? stats.weightedScore / maxScore : 0,
      );
    }).toList();

    // Sort by affinity score (highest first)
    affinities.sort((a, b) => b.affinityScore.compareTo(a.affinityScore));

    AppLogger.d(
        'CATEGORY_AFFINITY: User has ${affinities.length} categories, top: ${affinities.take(3)}');

    return UserCategoryProfile(
      topCategories: affinities,
      totalBooksListened: totalBooks,
      totalListenTimeSeconds: totalTime,
    );
  } catch (e) {
    AppLogger.e('Error calculating category affinity', error: e);
    return UserCategoryProfile.empty;
  }
});

/// Internal helper for aggregating category stats
class _CategoryStats {
  final int categoryId;
  final String categoryName;
  int listenCount = 0;
  int totalListenTime = 0;
  double weightedScore = 0;

  _CategoryStats(this.categoryId, this.categoryName);

  void addListen(int listenTime, double weight) {
    listenCount++;
    totalListenTime += listenTime;
    // Score = listen time * weight (completed books weighted higher)
    weightedScore += listenTime * weight;
  }
}

/// Data for "Top in Your Favorite Categories" section
class FavoriteCategoryContent {
  final CategoryAffinity category;
  final List<Map<String, dynamic>> topBooks;

  const FavoriteCategoryContent({
    required this.category,
    required this.topBooks,
  });
}

/// Provider for "Top in Your Favorite Categories" section
/// Fetches top-rated content from user's top 2 categories
final favoriteCategoriesContentProvider =
    FutureProvider.autoDispose<List<FavoriteCategoryContent>>((ref) async {
  // First get user's category profile
  final profile = await ref.watch(categoryAffinityProvider.future);

  if (profile.topCategories.isEmpty) return [];

  final user = Supabase.instance.client.auth.currentUser;

  try {
    // Get user's owned audiobook IDs to filter them out
    Set<int> ownedIds = {};
    if (user != null) {
      final entitlements = await Supabase.instance.client
          .from('entitlements')
          .select('audiobook_id')
          .eq('user_id', user.id);
      ownedIds = (entitlements as List)
          .map((e) => e['audiobook_id'] as int)
          .toSet();
    }

    // Take top 2 categories
    final topCategories = profile.topCategories.take(2).toList();
    final results = <FavoriteCategoryContent>[];

    for (final category in topCategories) {
      // Fetch top books in this category
      final booksResponse = await Supabase.instance.client
          .from('audiobooks')
          .select('id, title_fa, title_en, cover_url, author_fa, avg_rating, play_count, is_music, status')
          .eq('category_id', category.categoryId)
          .eq('status', 'approved')
          .eq('is_music', false)
          .order('avg_rating', ascending: false)
          .order('play_count', ascending: false)
          .limit(10);

      final books = (booksResponse as List)
          .map((b) => Map<String, dynamic>.from(b as Map))
          .where((b) => !ownedIds.contains(b['id'] as int))
          .take(6)
          .toList();

      if (books.isNotEmpty) {
        results.add(FavoriteCategoryContent(
          category: category,
          topBooks: books,
        ));
      }
    }

    AppLogger.d('FAVORITE_CATEGORIES: Found ${results.length} categories with content');
    return results;
  } catch (e) {
    AppLogger.e('Error fetching favorite categories content', error: e);
    return [];
  }
});
