import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/models.dart';

final wishlistServiceProvider = Provider<WishlistService>((ref) {
  return WishlistService(Supabase.instance.client);
});

final wishlistProvider = FutureProvider<List<Audiobook>>((ref) async {
  final service = ref.watch(wishlistServiceProvider);
  return service.getWishlist();
});

final isInWishlistProvider = FutureProvider.family<bool, String>((ref, audiobookId) async {
  final service = ref.watch(wishlistServiceProvider);
  return service.isInWishlist(audiobookId);
});

class WishlistService {
  final SupabaseClient _supabase;

  WishlistService(this._supabase);

  Future<List<Audiobook>> getWishlist() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // First get wishlist audiobook IDs
    final wishlistResponse = await _supabase
        .from('user_wishlist')
        .select('audiobook_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if ((wishlistResponse as List).isEmpty) return [];

    // Get the audiobook IDs
    final audiobookIds = wishlistResponse.map((w) => w['audiobook_id'] as int).toList();

    // Fetch audiobooks
    final audiobooksResponse = await _supabase
        .from('audiobooks')
        .select()
        .inFilter('id', audiobookIds);

    return (audiobooksResponse as List).map((json) => Audiobook.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<bool> isInWishlist(String audiobookId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from('user_wishlist')
        .select('id')
        .eq('user_id', userId)
        .eq('audiobook_id', int.parse(audiobookId))
        .maybeSingle();

    return response != null;
  }

  Future<void> addToWishlist(String audiobookId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('user_wishlist').insert({
      'user_id': userId,
      'audiobook_id': int.parse(audiobookId),
    });
  }

  Future<void> removeFromWishlist(String audiobookId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('user_wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('audiobook_id', int.parse(audiobookId));
  }

  Future<void> toggleWishlist(String audiobookId) async {
    final isIn = await isInWishlist(audiobookId);
    if (isIn) {
      await removeFromWishlist(audiobookId);
    } else {
      await addToWishlist(audiobookId);
    }
  }
}
