import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/config/env.dart';
import 'package:myna/config/audio_config.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/screens/payment/payment_processing_screen.dart';

/// Payment result types
enum PaymentResult {
  success,      // Entitlement confirmed
  processing,   // Payment submitted, waiting for webhook confirmation
  cancelled,    // User cancelled the payment
  failed,       // Payment failed
  notConfigured, // Stripe not configured
}

/// Service for handling payments via Stripe.
///
/// SECURE ARCHITECTURE:
/// 1. Client calls create-payment-intent with ONLY audiobook_id
/// 2. Server looks up price from database and creates PaymentIntent
/// 3. Client shows Stripe payment sheet
/// 4. Stripe webhook creates entitlement server-side on payment success
/// 5. Client polls for entitlement confirmation
///
/// Client NEVER creates entitlements for paid content directly.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  bool _isInitialized = false;

  /// Polling configuration - use centralized AudioConfig values
  static int get _maxPollingAttempts => AudioConfig.entitlementPollingMaxAttempts;
  static Duration get _pollingInterval => AudioConfig.entitlementPollingInterval;

  /// Initialize Stripe SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      AppLogger.d('Stripe initialization skipped on web');
      _isInitialized = true;
      return;
    }

    if (!Env.isStripeConfigured) {
      AppLogger.w('Stripe not configured - payments disabled');
      return;
    }

    try {
      Stripe.publishableKey = Env.stripePublishableKey;
      Stripe.merchantIdentifier = Env.stripeMerchantId;
      await Stripe.instance.applySettings();
      _isInitialized = true;
      AppLogger.i('Stripe initialized successfully');
    } catch (e) {
      AppLogger.e('Failed to initialize Stripe', error: e);
    }
  }

  /// Check if payments are available
  bool get isAvailable => _isInitialized && Env.isStripeConfigured && !kIsWeb;

  /// Process payment for an audiobook purchase
  ///
  /// [audiobookId] - The audiobook to purchase
  /// [audiobookTitle] - Title for display in payment sheet
  /// [ref] - Optional WidgetRef to suspend audio position updates during payment
  ///
  /// Returns:
  /// - [PaymentResult.success] if entitlement is confirmed
  /// - [PaymentResult.processing] if payment submitted but entitlement not yet visible
  /// - [PaymentResult.cancelled] if user cancelled
  /// - [PaymentResult.failed] if payment failed
  Future<PaymentResult> processPayment({
    required BuildContext context,
    required int audiobookId,
    required String audiobookTitle,
    WidgetRef? ref,
  }) async {
    if (!Env.isStripeConfigured) {
      AppLogger.w('Payment attempted but Stripe not configured');
      return PaymentResult.notConfigured;
    }

    if (kIsWeb) {
      AppLogger.w('Payments not supported on web');
      return PaymentResult.notConfigured;
    }

    try {
      // Step 1: Create Payment Intent on backend (server looks up price)
      final clientSecret = await _createPaymentIntent(audiobookId: audiobookId);

      if (clientSecret == null) {
        return PaymentResult.failed;
      }

      // Step 2: Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: Env.appNameFa,
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              background: Color(0xFF0D1117),
              primary: Color(0xFF3B82F6),
              componentBackground: Color(0xFF161B22),
              componentText: Colors.white,
              primaryText: Colors.white,
              secondaryText: Color(0xFF9CA3AF),
              placeholderText: Color(0xFF6B7280),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
            ),
          ),
        ),
      );

      // Step 3: Suspend position updates to reduce CPU while payment sheet is open
      // This improves typing responsiveness in the native Stripe UI
      ref?.read(audioProvider.notifier).suspendPositionUpdates();

      // Step 4: Present payment sheet
      try {
        await Stripe.instance.presentPaymentSheet();
      } finally {
        // Always resume position updates, even if payment fails/cancels
        ref?.read(audioProvider.notifier).resumePositionUpdates();
      }

      // Step 5: Show processing overlay while polling for entitlement
      // The webhook creates the entitlement; we show a spinner during the wait
      AppLogger.i('Payment sheet completed, showing processing screen...');

      bool showedProcessingScreen = false;
      if (context.mounted) {
        showedProcessingScreen = true;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PaymentProcessingScreen(
              audiobookTitle: audiobookTitle,
            ),
          ),
        );
      }

      final entitlementConfirmed = await _pollForEntitlement(audiobookId);

      // Dismiss processing screen
      if (showedProcessingScreen && context.mounted) {
        Navigator.of(context).pop();
      }

      if (entitlementConfirmed) {
        AppLogger.i('Payment successful for audiobook $audiobookId');
        return PaymentResult.success;
      } else {
        // Entitlement not yet visible - webhook might be delayed
        AppLogger.i('Payment submitted but entitlement not yet confirmed for audiobook $audiobookId');
        return PaymentResult.processing;
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        AppLogger.d('Payment cancelled by user');
        return PaymentResult.cancelled;
      }
      AppLogger.e('Stripe payment error', error: e);
      return PaymentResult.failed;
    } catch (e) {
      AppLogger.e('Payment processing error', error: e);
      return PaymentResult.failed;
    }
  }

  /// Create a Payment Intent via Supabase Edge Function
  ///
  /// Only sends audiobook_id - server looks up price securely
  Future<String?> _createPaymentIntent({required int audiobookId}) async {
    try {
      // Call Supabase Edge Function with ONLY audiobook_id
      final response = await Supabase.instance.client.functions.invoke(
        'create-payment-intent',
        body: {
          'audiobook_id': audiobookId,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] as String?;
        AppLogger.e('Failed to create payment intent: ${response.status} - $error');
        return null;
      }

      return response.data?['client_secret'] as String?;
    } catch (e) {
      AppLogger.e('Error creating payment intent', error: e);
      return null;
    }
  }

  /// Poll for entitlement after payment
  ///
  /// Waits up to [_maxPollingAttempts] seconds for the webhook to create
  /// the entitlement. Returns true if entitlement is found.
  Future<bool> _pollForEntitlement(int audiobookId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    for (int attempt = 0; attempt < _maxPollingAttempts; attempt++) {
      try {
        // PERFORMANCE: Only select 'id' - we just need to check existence
        final response = await Supabase.instance.client
            .from('entitlements')
            .select('id')
            .eq('user_id', user.id)
            .eq('audiobook_id', audiobookId)
            .maybeSingle();

        if (response != null) {
          AppLogger.d('Entitlement found on attempt ${attempt + 1}');
          return true;
        }
      } catch (e) {
        AppLogger.d('Polling attempt ${attempt + 1} failed: $e');
      }

      if (attempt < _maxPollingAttempts - 1) {
        await Future<void>.delayed(_pollingInterval);
      }
    }

    AppLogger.d('Entitlement not found after $_maxPollingAttempts attempts');
    return false;
  }

  /// Public method to poll for entitlement (used when PaymentResult.processing)
  Future<bool> pollForEntitlement(int audiobookId) => _pollForEntitlement(audiobookId);

  // ── Ebook payment wrappers ──────────────────────────────────────────────────

  /// Process payment for an ebook — delegates to the standard Stripe flow.
  Future<PaymentResult> processEbookPayment({
    required BuildContext context,
    required int ebookId,
    required String ebookTitle,
  }) => processPayment(
        context: context,
        audiobookId: ebookId,
        audiobookTitle: ebookTitle,
      );

  /// Poll for ebook entitlement after payment.
  Future<bool> pollForEbookEntitlement(int ebookId) =>
      _pollForEntitlement(ebookId);

  /// Check current ebook entitlement without polling.
  Future<bool> checkEbookEntitlement(int ebookId) => checkEntitlement(ebookId);

  /// Check if user has entitlement for an audiobook
  Future<bool> checkEntitlement(int audiobookId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('entitlements')
          .select('id')
          .eq('user_id', user.id)
          .eq('audiobook_id', audiobookId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      AppLogger.e('Error checking entitlement', error: e);
      return false;
    }
  }

  /// Show dialog explaining payment is not configured
  static void showNotConfiguredDialog(BuildContext context) {
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

  /// Show payment failed dialog
  static void showPaymentFailedDialog(BuildContext context, {String? message}) {
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
              Icon(Icons.error_outline, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Text(
                'خطا در پرداخت',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            message ?? 'پرداخت انجام نشد. لطفاً دوباره تلاش کنید.',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'باشه',
                style: TextStyle(color: Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show payment processing dialog (webhook delayed)
  /// [onCheckAgain] - Optional callback to retry checking entitlement
  /// [audiobookId] - Required if onCheckAgain is provided
  static void showProcessingDialog(
    BuildContext context, {
    Future<bool> Function()? onCheckAgain,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => _ProcessingDialog(onCheckAgain: onCheckAgain),
    );
  }
}

/// Stateful dialog for processing state with "Check Again" functionality
class _ProcessingDialog extends StatefulWidget {
  final Future<bool> Function()? onCheckAgain;

  const _ProcessingDialog({this.onCheckAgain});

  @override
  State<_ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<_ProcessingDialog> {
  bool _isChecking = false;
  String? _statusMessage;

  Future<void> _handleCheckAgain() async {
    if (widget.onCheckAgain == null || _isChecking) return;

    setState(() {
      _isChecking = true;
      _statusMessage = 'در حال بررسی...';
    });

    try {
      final success = await widget.onCheckAgain!();
      if (!mounted) return;

      if (success) {
        setState(() {
          _statusMessage = 'تایید شد! کتاب به کتابخانه اضافه شد.';
          _isChecking = false;
        });
        // Close dialog after short delay
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _statusMessage = 'هنوز تایید نشده. لطفاً کمی صبر کنید و دوباره امتحان کنید.';
          _isChecking = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'خطا در بررسی. لطفاً دوباره تلاش کنید.';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            if (_isChecking)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF59E0B),
                ),
              )
            else
              const Icon(Icons.hourglass_empty, color: Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            const Text(
              'در حال پردازش',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'پرداخت شما ثبت شد و در حال تایید نهایی است.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'کتاب به زودی به کتابخانه شما اضافه می‌شود. اگر تا چند دقیقه دیگر کتاب ظاهر نشد، لطفاً با پشتیبانی تماس بگیرید.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2530),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_statusMessage!.contains('تایید شد'))
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20)
                    else if (_statusMessage!.contains('خطا'))
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20)
                    else
                      const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.onCheckAgain != null)
            TextButton(
              onPressed: _isChecking ? null : _handleCheckAgain,
              child: Text(
                'بررسی مجدد',
                style: TextStyle(
                  color: _isChecking ? Colors.grey : const Color(0xFFF59E0B),
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'متوجه شدم',
              style: TextStyle(color: Color(0xFF3B82F6)),
            ),
          ),
        ],
      ),
    );
  }
}
