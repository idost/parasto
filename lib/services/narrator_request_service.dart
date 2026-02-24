import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/narrator_request.dart';

/// Service for managing narrator status requests
class NarratorRequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // USER METHODS
  // ============================================================================

  /// Get the current user's pending narrator request (if any)
  Future<NarratorRequest?> getUserPendingRequest() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('narrator_requests')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    if (response == null) return null;
    return NarratorRequest.fromJson(response);
  }

  /// Get all of the current user's narrator requests (history)
  Future<List<NarratorRequest>> getUserRequests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('narrator_requests')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => NarratorRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Submit a new narrator request with voice sample
  ///
  /// Throws exception if user already has a pending request
  Future<NarratorRequest> submitRequest({
    required String experienceText,
    required File voiceSampleFile,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Check for existing pending request
    final existingRequest = await getUserPendingRequest();
    if (existingRequest != null) {
      throw Exception('شما در حال حاضر یک درخواست در انتظار بررسی دارید');
    }

    // Generate request ID first
    final requestId = _generateUuid();

    // Upload voice sample to storage
    final voiceSamplePath = await _uploadVoiceSample(
      userId: userId,
      requestId: requestId,
      file: voiceSampleFile,
    );

    try {
      // Insert database record
      final response = await _supabase
          .from('narrator_requests')
          .insert({
            'id': requestId,
            'user_id': userId,
            'experience_text': experienceText,
            'voice_sample_path': voiceSamplePath,
            'status': 'pending',
          })
          .select()
          .single();

      return NarratorRequest.fromJson(response);
    } catch (e) {
      // If database insert fails, cleanup uploaded file
      try {
        await _supabase.storage
            .from('narrator-requests')
            .remove([voiceSamplePath]);
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  // ============================================================================
  // ADMIN METHODS
  // ============================================================================

  /// Get all narrator requests (admin only)
  ///
  /// Optional statusFilter: 'pending', 'approved', 'rejected', or null for all
  Future<List<NarratorRequest>> getAdminRequests({String? statusFilter}) async {
    dynamic query = _supabase.from('narrator_requests').select();

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    query = query.order('created_at', ascending: false);

    final response = await query;

    return (response as List)
        .map((json) => NarratorRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get narrator request statistics for admin dashboard
  ///
  /// Returns map with counts: {pending, approved, rejected}
  Future<Map<String, int>> getRequestStats() async {
    final response = await _supabase
        .from('narrator_requests')
        .select('status');

    final List<Map<String, dynamic>> data = (response as List)
        .map((item) => item as Map<String, dynamic>)
        .toList();

    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final item in data) {
      final status = item['status'] as String;
      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
      }
    }

    return {
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
    };
  }

  /// Get count of pending requests for sidebar badge
  Future<int> getPendingCount() async {
    final response = await _supabase
        .from('narrator_requests')
        .select('id')
        .eq('status', 'pending');

    return (response as List).length;
  }

  /// Approve a narrator request (admin only)
  ///
  /// This will:
  /// 1. Update request status to 'approved'
  /// 2. Change user's role to 'narrator' in profiles table
  Future<void> approveRequest(String requestId) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('Admin not authenticated');

    // Get the request to find the user
    final requestData = await _supabase
        .from('narrator_requests')
        .select('user_id')
        .eq('id', requestId)
        .single();

    final userId = requestData['user_id'] as String;

    // Update request status
    await _supabase
        .from('narrator_requests')
        .update({
          'status': 'approved',
          'reviewed_by': adminId,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // Update user role to narrator
    await _supabase
        .from('profiles')
        .update({'role': 'narrator'})
        .eq('id', userId);
  }

  /// Reject a narrator request (admin only)
  ///
  /// Optional feedback message for the user
  Future<void> rejectRequest(String requestId, {String? feedback}) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('Admin not authenticated');

    await _supabase
        .from('narrator_requests')
        .update({
          'status': 'rejected',
          'reviewed_by': adminId,
          'reviewed_at': DateTime.now().toIso8601String(),
          'admin_feedback': feedback,
        })
        .eq('id', requestId);
  }

  // ============================================================================
  // STORAGE METHODS
  // ============================================================================

  /// Get signed URL for voice sample (1-hour expiry)
  Future<String> getVoiceSampleUrl(String path) async {
    return await _supabase.storage
        .from('narrator-requests')
        .createSignedUrl(path, 3600); // 1 hour
  }

  /// Upload voice sample to storage
  ///
  /// Returns the storage path
  Future<String> _uploadVoiceSample({
    required String userId,
    required String requestId,
    required File file,
  }) async {
    final fileName = '$requestId.m4a';
    final path = '$userId/$fileName';

    await _supabase.storage
        .from('narrator-requests')
        .upload(path, file);

    return path;
  }

  /// Generate a UUID v4 string
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version to 4 (random UUID)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    // Convert to hex string with dashes
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
           '${hex(bytes[4])}${hex(bytes[5])}-'
           '${hex(bytes[6])}${hex(bytes[7])}-'
           '${hex(bytes[8])}${hex(bytes[9])}-'
           '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
