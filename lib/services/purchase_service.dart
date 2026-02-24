import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Result of a purchase attempt
enum PurchaseResult {
  success,
  cancelled,
  paymentRequired,
  error,
}

/// Service for handling audiobook purchases.
///
/// SECURITY NOTE: This service implements client-side purchase logic.
/// For production, purchases should be verified server-side using:
/// 1. Stripe webhooks to confirm payment
/// 2. Supabase Edge Functions to validate and create entitlements
/// 3. RLS policies to prevent direct entitlement insertion
class PurchaseService {
  final SupabaseClient _supabase;

  PurchaseService(this._supabase);

  /// Check if user owns the audiobook (either free or purchased)
  Future<bool> checkOwnership({
    required String userId,
    required int audiobookId,
  }) async {
    try {
      // Check if audiobook is free
      final audiobook = await _supabase
          .from('audiobooks')
          .select('is_free')
          .eq('id', audiobookId)
          .maybeSingle();

      // If audiobook not found, user doesn't own it
      if (audiobook == null) {
        return false;
      }

      if (audiobook['is_free'] == true) {
        return true;
      }

      // Check for entitlement
      final entitlement = await _supabase
          .from('entitlements')
          .select('id')
          .eq('user_id', userId)
          .eq('audiobook_id', audiobookId)
          .maybeSingle();

      return entitlement != null;
    } catch (e) {
      AppLogger.e('Error checking ownership', error: e);
      return false;
    }
  }

  /// Attempt to purchase an audiobook
  ///
  /// Returns [PurchaseResult.paymentRequired] for paid content since
  /// payment integration is not yet implemented.
  Future<PurchaseResult> purchaseAudiobook({
    required BuildContext context,
    required int audiobookId,
    required int priceToman,
    required bool isFree,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      AppLogger.w('Purchase attempted without authentication');
      return PurchaseResult.error;
    }

    // Free audiobooks can be "purchased" (entitled) directly
    if (isFree) {
      return await _grantFreeEntitlement(
        userId: user.id,
        audiobookId: audiobookId,
      );
    }

    // Paid content - payment not yet implemented
    AppLogger.i('Payment required for audiobook $audiobookId');
    return PurchaseResult.paymentRequired;
  }

  /// Grant entitlement for free audiobooks
  Future<PurchaseResult> _grantFreeEntitlement({
    required String userId,
    required int audiobookId,
  }) async {
    AppLogger.i('=== FREE ENTITLEMENT FLOW START ===');
    AppLogger.i('User: $userId, Audiobook: $audiobookId');

    try {
      // Check if already owned
      AppLogger.d('Checking for existing entitlement...');
      final existing = await _supabase
          .from('entitlements')
          .select('id')
          .eq('user_id', userId)
          .eq('audiobook_id', audiobookId)
          .maybeSingle();

      if (existing != null) {
        AppLogger.i('User already has entitlement for audiobook $audiobookId - SUCCESS');
        return PurchaseResult.success;
      }
      AppLogger.d('No existing entitlement found, proceeding with claim...');

      // Verify the audiobook is actually free and approved before attempting insert
      AppLogger.d('Verifying audiobook is free and approved...');
      final audiobook = await _supabase
          .from('audiobooks')
          .select('is_free, status')
          .eq('id', audiobookId)
          .maybeSingle();

      if (audiobook == null) {
        AppLogger.e('Audiobook $audiobookId not found in database');
        return PurchaseResult.error;
      }

      AppLogger.d('Audiobook data: is_free=${audiobook['is_free']}, status=${audiobook['status']}');

      if (audiobook['is_free'] != true) {
        AppLogger.w('Audiobook $audiobookId is not free (is_free=${audiobook['is_free']})');
        return PurchaseResult.paymentRequired;
      }

      if (audiobook['status'] != 'approved') {
        AppLogger.w('Audiobook $audiobookId is not approved (status=${audiobook['status']})');
        return PurchaseResult.error;
      }

      // Create entitlement for free content
      AppLogger.i('Inserting entitlement: user_id=$userId, audiobook_id=$audiobookId, source=free');
      await _supabase.from('entitlements').insert({
        'user_id': userId,
        'audiobook_id': audiobookId,
        'source': 'free',
      });

      AppLogger.i('=== FREE ENTITLEMENT GRANTED SUCCESSFULLY ===');
      return PurchaseResult.success;
    } on PostgrestException catch (e) {
      // Handle specific Postgres errors
      AppLogger.e('=== POSTGRES EXCEPTION ===');
      AppLogger.e('Code: ${e.code}');
      AppLogger.e('Message: ${e.message}');
      AppLogger.e('Details: ${e.details}');
      AppLogger.e('Hint: ${e.hint}');

      if (e.code == '23505') {
        // Unique constraint violation - entitlement already exists
        AppLogger.i('Entitlement already exists (concurrent insert) - treating as SUCCESS');
        return PurchaseResult.success;
      }

      // RLS policy violation typically shows as 42501 or returns empty/error
      if (e.code == '42501') {
        AppLogger.e('RLS POLICY VIOLATION - Check entitlements INSERT policy');
      }

      return PurchaseResult.error;
    } catch (e, stackTrace) {
      AppLogger.e('=== UNEXPECTED ERROR ===');
      AppLogger.e('Error type: ${e.runtimeType}');
      AppLogger.e('Error: $e');
      AppLogger.e('Stack trace: $stackTrace');
      return PurchaseResult.error;
    }
  }

  /// Show payment coming soon dialog
  static void showPaymentComingSoonDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.payment, color: Color(0xFF3B82F6)),
              SizedBox(width: 12),
              Text(
                'پرداخت',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سیستم پرداخت در حال راه‌اندازی است.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'به زودی امکان خرید کتاب‌های صوتی فراهم خواهد شد.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'متوجه شدم',
                style: TextStyle(color: Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
