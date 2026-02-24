import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/services/feedback_service.dart';
import 'package:myna/utils/app_logger.dart';

/// Provider for feedback on a specific audiobook (admin view)
final audiobookFeedbackProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, audiobookId) async {
  final service = ref.watch(feedbackServiceProvider);
  return service.getAudiobookFeedback(audiobookId);
});

/// Provider for all feedback for the current narrator
final narratorFeedbackProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final service = ref.watch(feedbackServiceProvider);
  return service.getNarratorFeedback(userId);
});

/// Provider for unread feedback count (narrator badge)
final unreadFeedbackCountProvider = FutureProvider<int>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;

  final service = ref.watch(feedbackServiceProvider);
  return service.getUnreadFeedbackCount(userId);
});

/// Provider for feedback filtered by audiobook for narrator view
final narratorAudiobookFeedbackProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, audiobookId) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await Supabase.instance.client
        .from('admin_feedback')
        .select('*, chapters(title_fa), profiles!admin_feedback_admin_id_fkey(display_name)')
        .eq('audiobook_id', audiobookId)
        .eq('narrator_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching narrator audiobook feedback', error: e);
    return [];
  }
});
