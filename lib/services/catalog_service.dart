import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/models.dart';

final catalogServiceProvider = Provider<CatalogService>((ref) {
  return CatalogService(Supabase.instance.client);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.watch(catalogServiceProvider);
  return service.getCategories();
});

final featuredAudiobooksProvider = FutureProvider<List<Audiobook>>((ref) async {
  final service = ref.watch(catalogServiceProvider);
  return service.getFeaturedAudiobooks();
});

final newReleasesProvider = FutureProvider<List<Audiobook>>((ref) async {
  final service = ref.watch(catalogServiceProvider);
  return service.getNewReleases();
});

final popularAudiobooksProvider = FutureProvider<List<Audiobook>>((ref) async {
  final service = ref.watch(catalogServiceProvider);
  return service.getPopularAudiobooks();
});

final audiobookDetailProvider = FutureProvider.family<Audiobook?, String>((ref, id) async {
  final service = ref.watch(catalogServiceProvider);
  return service.getAudiobook(id);
});

final chaptersProvider = FutureProvider.family<List<Chapter>, String>((ref, audiobookId) async {
  final service = ref.watch(catalogServiceProvider);
  return service.getChapters(audiobookId);
});

class CatalogService {
  final SupabaseClient _supabase;

  CatalogService(this._supabase);

  Future<List<Category>> getCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return (response as List).map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Audiobook>> getFeaturedAudiobooks() async {
    final response = await _supabase
        .from('audiobooks')
        .select()
        .eq('status', 'approved')
        .eq('is_featured', true)
        .order('published_at', ascending: false)
        .limit(10);

    return (response as List).map((json) => Audiobook.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Audiobook>> getNewReleases() async {
    final response = await _supabase
        .from('audiobooks')
        .select()
        .eq('status', 'approved')
        .order('published_at', ascending: false)
        .limit(10);

    return (response as List).map((json) => Audiobook.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Audiobook>> getPopularAudiobooks() async {
    final response = await _supabase
        .from('audiobooks')
        .select()
        .eq('status', 'approved')
        .order('play_count', ascending: false)
        .limit(10);

    return (response as List).map((json) => Audiobook.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Audiobook>> searchAudiobooks(String query) async {
    final response = await _supabase
        .from('audiobooks')
        .select()
        .eq('status', 'approved')
        .or('title_fa.ilike.%$query%,title_en.ilike.%$query%')
        .limit(20);

    return (response as List).map((json) => Audiobook.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Audiobook?> getAudiobook(String id) async {
    final response = await _supabase
        .from('audiobooks')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Audiobook.fromJson(response);
  }

  Future<List<Chapter>> getChapters(String audiobookId) async {
    final response = await _supabase
        .from('chapters')
        .select()
        .eq('audiobook_id', audiobookId)
        .order('chapter_index', ascending: true);

    return (response as List).map((json) => Chapter.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Audiobook>> getAudiobooksByCategory(int categoryId) async {
    final response = await _supabase
        .from('audiobooks')
        .select()
        .eq('status', 'approved')
        .eq('category_id', categoryId)
        .order('published_at', ascending: false);

    return (response as List).map((json) => Audiobook.fromJson(json as Map<String, dynamic>)).toList();
  }
}
