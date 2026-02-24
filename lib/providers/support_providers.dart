import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

// ============================================
// USER PROVIDERS (Listener/Narrator)
// ============================================

/// Provider for current user's support tickets
final userTicketsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('support_tickets')
        .select('*, audiobooks(id, title_fa, cover_url)')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching user tickets', error: e);
    rethrow;
  }
});

/// Provider for ticket detail with messages
/// NOTE(Issue 8 fix): Added ownership check to prevent users from accessing
/// other users' tickets. This is a client-side safeguard in addition to RLS.
final ticketDetailProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, ticketId) async {
  final user = Supabase.instance.client.auth.currentUser;

  try {
    // Get ticket
    final ticketResponse = await Supabase.instance.client
        .from('support_tickets')
        .select('*, audiobooks(id, title_fa, cover_url), profiles!support_tickets_user_id_fkey(id, email, display_name, full_name)')
        .eq('id', ticketId)
        .maybeSingle();

    if (ticketResponse == null) return null;

    final ticket = Map<String, dynamic>.from(ticketResponse);

    // NOTE(Issue 8 fix): Verify the user owns this ticket or is an admin
    // This prevents users from seeing other users' support conversations
    final ticketUserId = ticket['user_id'] as String?;
    if (user != null && ticketUserId != null && ticketUserId != user.id) {
      // Check if current user is admin (by checking profile role)
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final userRole = profileResponse?['role'] as String?;
      if (userRole != 'admin') {
        AppLogger.w('Support: User ${user.id} attempted to access ticket $ticketId owned by $ticketUserId');
        return null; // Block access - user doesn't own this ticket
      }
    }

    // Get messages
    final messagesResponse = await Supabase.instance.client
        .from('support_messages')
        .select('*, profiles!support_messages_sender_id_fkey(id, display_name, full_name, role)')
        .eq('ticket_id', ticketId)
        .order('created_at');

    ticket['messages'] = List<Map<String, dynamic>>.from(messagesResponse);

    return ticket;
  } catch (e) {
    AppLogger.e('Error fetching ticket detail', error: e);
    rethrow;
  }
});

/// Count of user's open tickets
final userOpenTicketsCountProvider = FutureProvider<int>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 0;

  try {
    final response = await Supabase.instance.client
        .from('support_tickets')
        .select('id')
        .eq('user_id', user.id)
        .neq('status', 'closed');
    return (response as List).length;
  } catch (e) {
    return 0;
  }
});

// ============================================
// ADMIN PROVIDERS
// ============================================

/// Provider for all support tickets (admin view)
final adminTicketsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  try {
    var query = Supabase.instance.client
        .from('support_tickets')
        .select('*, audiobooks(id, title_fa), profiles!support_tickets_user_id_fkey(id, email, display_name, full_name, role)');

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    // Fetch ALL tickets - admins need to see everything for support management
    final response = await query.order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    AppLogger.e('Error fetching admin tickets', error: e);
    rethrow;
  }
});

/// Provider for ticket statistics (for dashboard)
/// Uses efficient count queries instead of downloading all data
final adminTicketStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // Use parallel count queries for efficiency
    final results = await Future.wait([
      supabase
          .from('support_tickets')
          .select()
          .eq('status', 'open')
          .count(CountOption.exact),
      supabase
          .from('support_tickets')
          .select()
          .eq('status', 'in_progress')
          .count(CountOption.exact),
      supabase
          .from('support_tickets')
          .select()
          .eq('status', 'closed')
          .count(CountOption.exact),
    ]);

    final open = results[0].count;
    final inProgress = results[1].count;
    final closed = results[2].count;

    return {
      'open': open,
      'in_progress': inProgress,
      'closed': closed,
      'total': open + inProgress + closed,
    };
  } catch (e) {
    AppLogger.e('Error fetching ticket stats', error: e);
    return {'open': 0, 'in_progress': 0, 'closed': 0, 'total': 0};
  }
});

/// Count of unread/open tickets for admin badge
/// Uses efficient count query
final adminOpenTicketsCountProvider = FutureProvider<int>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('support_tickets')
        .select()
        .eq('status', 'open')
        .count(CountOption.exact);
    return response.count;
  } catch (e) {
    return 0;
  }
});
