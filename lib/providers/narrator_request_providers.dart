import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/narrator_request.dart';
import 'package:myna/services/narrator_request_service.dart';

/// Service provider
final narratorRequestServiceProvider = Provider<NarratorRequestService>((ref) {
  return NarratorRequestService();
});

// ============================================================================
// USER PROVIDERS
// ============================================================================

/// Get the current user's pending narrator request (if any)
final userPendingRequestProvider = FutureProvider<NarratorRequest?>((ref) async {
  final service = ref.watch(narratorRequestServiceProvider);
  return await service.getUserPendingRequest();
});

/// Get all of the current user's narrator requests (history)
final userRequestsProvider = FutureProvider<List<NarratorRequest>>((ref) async {
  final service = ref.watch(narratorRequestServiceProvider);
  return await service.getUserRequests();
});

// ============================================================================
// ADMIN PROVIDERS
// ============================================================================

/// Get all narrator requests with optional status filter (admin only)
///
/// Pass null for all requests, or 'pending'/'approved'/'rejected' to filter
final adminNarratorRequestsProvider =
    FutureProvider.family<List<NarratorRequest>, String?>((ref, statusFilter) async {
  final service = ref.watch(narratorRequestServiceProvider);
  return await service.getAdminRequests(statusFilter: statusFilter);
});

/// Get narrator request statistics for admin dashboard
///
/// Returns map with counts: {pending, approved, rejected}
final narratorRequestStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(narratorRequestServiceProvider);
  return await service.getRequestStats();
});

/// Get count of pending narrator requests for sidebar badge
final pendingNarratorRequestsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(narratorRequestServiceProvider);
  return await service.getPendingCount();
});
