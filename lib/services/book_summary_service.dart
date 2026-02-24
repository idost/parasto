import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Provider for the BookSummaryService
final bookSummaryServiceProvider = Provider<BookSummaryService>((ref) {
  return BookSummaryService(Supabase.instance.client);
});

/// Result of a book summary fetch operation.
class BookSummaryResult {
  final String? summary;
  final bool rateLimitExceeded;
  final bool error;
  final String? errorType;
  final int? errorStatus;
  final String? errorCode;

  const BookSummaryResult({
    this.summary,
    this.rateLimitExceeded = false,
    this.error = false,
    this.errorType,
    this.errorStatus,
    this.errorCode,
  });

  bool get hasContent => summary != null && summary!.isNotEmpty;
}

/// Service for fetching AI-generated book summaries.
///
/// This service calls the Supabase Edge Function "book-summary" which:
/// - Checks for cached summaries first
/// - Generates new summaries using Anthropic Claude if needed
/// - Caches results for future requests
/// - Rate limits: 10 new generations per user per 24 hours
///
/// All errors are handled gracefully - returns BookSummaryResult with error flags.
class BookSummaryService {
  final SupabaseClient _supabase;

  // In-memory cache to avoid redundant calls within the same session
  final Map<int, String> _sessionCache = {};

  BookSummaryService(this._supabase);

  /// Fetches a 2-line AI-generated summary for an audiobook.
  ///
  /// [audiobookId] - The ID of the audiobook to summarize
  /// [forceRefresh] - If true, bypasses both session and DB cache to generate fresh summary
  ///
  /// Returns BookSummaryResult with summary or error flags.
  /// This method NEVER throws - all errors are caught and logged.
  Future<BookSummaryResult> getBookSummary(int audiobookId, {bool forceRefresh = false}) async {
    // Check session cache first (unless force refresh)
    if (!forceRefresh && _sessionCache.containsKey(audiobookId)) {
      return BookSummaryResult(summary: _sessionCache[audiobookId]);
    }

    try {
      // Check if we have a valid session - Edge Function requires authenticated user
      final session = _supabase.auth.currentSession;
      if (session == null) {
        AppLogger.w('SUMMARY: No valid session (currentSession is null or expired).');
        return const BookSummaryResult(error: true, errorType: 'unauthorized');
      }

      // Check if session is expired and try to refresh
      if (session.isExpired) {
        try {
          await _supabase.auth.refreshSession();
        } catch (e) {
          AppLogger.e('SUMMARY: No valid session (currentSession is null or expired).', error: e);
          return const BookSummaryResult(error: true, errorType: 'unauthorized');
        }
      }

      // Call the Edge Function with a timeout
      final response = await _supabase.functions
          .invoke(
            'book-summary',
            body: {
              'audiobook_id': audiobookId,
              'force_refresh': forceRefresh,
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              AppLogger.w('SUMMARY: Request timed out');
              throw TimeoutException('Request timed out');
            },
          );

      // NOTE: Supabase functions.invoke() throws FunctionException for non-2xx responses
      final summaryFa = response.data?['summary_fa'] as String?;

      if (summaryFa == null || summaryFa.isEmpty) {
        AppLogger.w('SUMMARY: Empty or invalid summary_fa from Edge Function.');
        return const BookSummaryResult(error: true, errorType: 'invalid_summary');
      }

      // Cache in session memory
      _sessionCache[audiobookId] = summaryFa;
      return BookSummaryResult(summary: summaryFa);

    } on TimeoutException catch (_) {
      AppLogger.w('SUMMARY: Request timed out');
      return const BookSummaryResult(error: true, errorType: 'timeout');
    } on FunctionException catch (e) {
      final errorDetails = _parseErrorDetails(e.details);
      final errorCode = _extractErrorCode(errorDetails);
      final errorMessage = _extractErrorMessage(errorDetails);
      AppLogger.d(
        'SUMMARY: FunctionException status=${e.status} code=${errorCode ?? 'unknown'} message=${errorMessage ?? 'unknown'}',
        error: errorDetails,
      );

      // Check if this is a rate limit error
      if (e.status == 429) {
        return const BookSummaryResult(
          rateLimitExceeded: true,
          errorType: 'rate_limited',
          errorStatus: 429,
          errorCode: 'rate_limit_exceeded',
        );
      }

      // Log error for debugging
      AppLogger.e('SUMMARY: Edge Function error - status=${e.status}', error: e.details);
      return BookSummaryResult(
        error: true,
        errorType: _mapErrorType(e.status, errorCode),
        errorStatus: e.status,
        errorCode: errorCode,
      );
    } catch (e) {
      AppLogger.e('SUMMARY: Unexpected error', error: e);
      return const BookSummaryResult(error: true, errorType: 'unknown');
    }
  }

  /// Legacy method for backward compatibility - returns just the summary string
  @Deprecated('Use getBookSummary instead which returns BookSummaryResult')
  Future<String?> getBookSummaryLegacy(int audiobookId, {bool forceRefresh = false}) async {
    final result = await getBookSummary(audiobookId, forceRefresh: forceRefresh);
    return result.summary;
  }

  /// Clears the session cache for a specific audiobook.
  /// Useful if you want to force a fresh fetch on next request.
  void clearCache(int audiobookId) {
    _sessionCache.remove(audiobookId);
  }

  /// Clears all session cache.
  void clearAllCache() {
    _sessionCache.clear();
  }

  /// Checks if a summary is available in session cache.
  bool hasCachedSummary(int audiobookId) {
    return _sessionCache.containsKey(audiobookId);
  }

  /// Gets a cached summary without making a network request.
  /// Returns null if not in session cache.
  String? getCachedSummary(int audiobookId) {
    return _sessionCache[audiobookId];
  }
}

Map<String, dynamic>? _parseErrorDetails(dynamic details) {
  if (details == null) return null;
  if (details is Map<String, dynamic>) return details;
  if (details is Map) {
    return Map<String, dynamic>.from(details);
  }
  if (details is String) {
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _extractErrorCode(Map<String, dynamic>? details) {
  if (details == null) return null;
  final error = details['error'] ?? details['code'];
  return error?.toString();
}

String? _extractErrorMessage(Map<String, dynamic>? details) {
  if (details == null) return null;
  final message = details['message'] ?? details['error_description'];
  return message?.toString();
}

String _mapErrorType(int? status, String? errorCode) {
  if (errorCode != null && errorCode.isNotEmpty) return errorCode;
  switch (status) {
    case 400:
      return 'invalid_request';
    case 401:
      return 'unauthorized';
    case 404:
      return 'not_found';
    case 503:
      return 'service_unavailable';
    default:
      return 'unknown';
  }
}

/// Custom exception for timeout handling
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
