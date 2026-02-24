import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Provider for FeedbackService
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(Supabase.instance.client);
});

/// Types of admin feedback
enum FeedbackType {
  info,           // General information/note
  changeRequired, // Action required by narrator
  rejectionReason // Reason for rejection
}

extension FeedbackTypeExtension on FeedbackType {
  String get value {
    switch (this) {
      case FeedbackType.info:
        return 'info';
      case FeedbackType.changeRequired:
        return 'change_required';
      case FeedbackType.rejectionReason:
        return 'rejection_reason';
    }
  }

  String get label {
    switch (this) {
      case FeedbackType.info:
        return 'اطلاع‌رسانی';
      case FeedbackType.changeRequired:
        return 'نیاز به تغییر';
      case FeedbackType.rejectionReason:
        return 'دلیل رد';
    }
  }

  static FeedbackType fromString(String? value) {
    switch (value) {
      case 'change_required':
        return FeedbackType.changeRequired;
      case 'rejection_reason':
        return FeedbackType.rejectionReason;
      default:
        return FeedbackType.info;
    }
  }
}

/// Service for managing admin feedback on audiobooks/chapters
class FeedbackService {
  final SupabaseClient _supabase;

  FeedbackService(this._supabase);

  /// Add feedback to an audiobook
  Future<void> addAudiobookFeedback({
    required int audiobookId,
    required String narratorId,
    required String message,
    required FeedbackType feedbackType,
  }) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) throw Exception('Not authenticated');

      await _supabase.from('admin_feedback').insert({
        'audiobook_id': audiobookId,
        'chapter_id': null,
        'admin_id': adminId,
        'narrator_id': narratorId,
        'message': message,
        'feedback_type': feedbackType.value,
        'is_read': false,
      });

      AppLogger.i('Added audiobook feedback: $audiobookId');
    } catch (e) {
      AppLogger.e('Error adding audiobook feedback', error: e);
      rethrow;
    }
  }

  /// Add feedback to a specific chapter
  Future<void> addChapterFeedback({
    required int audiobookId,
    required int chapterId,
    required String narratorId,
    required String message,
    required FeedbackType feedbackType,
  }) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) throw Exception('Not authenticated');

      await _supabase.from('admin_feedback').insert({
        'audiobook_id': audiobookId,
        'chapter_id': chapterId,
        'admin_id': adminId,
        'narrator_id': narratorId,
        'message': message,
        'feedback_type': feedbackType.value,
        'is_read': false,
      });

      AppLogger.i('Added chapter feedback: chapter $chapterId');
    } catch (e) {
      AppLogger.e('Error adding chapter feedback', error: e);
      rethrow;
    }
  }

  /// Get all feedback for an audiobook (including chapter feedback)
  Future<List<Map<String, dynamic>>> getAudiobookFeedback(int audiobookId) async {
    try {
      final response = await _supabase
          .from('admin_feedback')
          .select('*, chapters(title_fa), profiles!admin_feedback_admin_id_fkey(display_name)')
          .eq('audiobook_id', audiobookId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.e('Error fetching audiobook feedback', error: e);
      // Return empty list if table/relation not found
      if (e.code == 'PGRST205' || e.code == '42P01') {
        return [];
      }
      rethrow;
    } catch (e) {
      AppLogger.e('Error fetching audiobook feedback', error: e);
      rethrow;
    }
  }

  /// Get all feedback for a narrator
  Future<List<Map<String, dynamic>>> getNarratorFeedback(String narratorId) async {
    try {
      final response = await _supabase
          .from('admin_feedback')
          .select('*, audiobooks(id, title_fa, status), chapters(title_fa), profiles!admin_feedback_admin_id_fkey(display_name)')
          .eq('narrator_id', narratorId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.e('Error fetching narrator feedback', error: e);
      // Return empty list if table/relation not found
      if (e.code == 'PGRST205' || e.code == '42P01') {
        return [];
      }
      rethrow;
    } catch (e) {
      AppLogger.e('Error fetching narrator feedback', error: e);
      rethrow;
    }
  }

  /// Get unread feedback count for a narrator
  Future<int> getUnreadFeedbackCount(String narratorId) async {
    try {
      final response = await _supabase
          .from('admin_feedback')
          .select('id')
          .eq('narrator_id', narratorId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      AppLogger.e('Error fetching unread feedback count', error: e);
      return 0;
    }
  }

  /// Mark feedback as read
  Future<void> markAsRead(int feedbackId) async {
    try {
      await _supabase
          .from('admin_feedback')
          .update({'is_read': true})
          .eq('id', feedbackId);
    } catch (e) {
      AppLogger.e('Error marking feedback as read', error: e);
      rethrow;
    }
  }

  /// Mark all feedback for a narrator as read
  /// If narratorId is null, uses the current authenticated user's ID
  Future<void> markAllAsRead(String? narratorId) async {
    try {
      final targetId = narratorId ?? _supabase.auth.currentUser?.id;
      if (targetId == null) return;

      await _supabase
          .from('admin_feedback')
          .update({'is_read': true})
          .eq('narrator_id', targetId)
          .eq('is_read', false);
    } catch (e) {
      AppLogger.e('Error marking all feedback as read', error: e);
      rethrow;
    }
  }

  /// Delete a feedback entry (admin only)
  Future<void> deleteFeedback(int feedbackId) async {
    try {
      await _supabase
          .from('admin_feedback')
          .delete()
          .eq('id', feedbackId);

      AppLogger.i('Deleted feedback: $feedbackId');
    } catch (e) {
      AppLogger.e('Error deleting feedback', error: e);
      rethrow;
    }
  }
}
