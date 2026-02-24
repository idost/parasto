import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show VoidCallback, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

// ══════════════════════════════════════════════════════════════════
// IAP Configuration
// ══════════════════════════════════════════════════════════════════

/// Product IDs configured in App Store Connect / Google Play Console.
class IAPConfig {
  /// Monthly subscription product ID.
  /// Must match the product ID in App Store Connect and Google Play Console.
  static const String monthlySubscriptionId = 'com.myna.audiobook.monthly';

  /// Yearly subscription product ID.
  static const String yearlySubscriptionId = 'com.myna.audiobook.yearly';

  /// Subscription product IDs to query from the store.
  /// Only monthly is surfaced in the UI; yearly is kept as a config
  /// constant but NOT queried or shown to users.
  static Set<String> get productIds => {
        monthlySubscriptionId,
      };
}

// ══════════════════════════════════════════════════════════════════
// Subscription Status Model (unchanged from previous — API-compatible)
// ══════════════════════════════════════════════════════════════════

/// Subscription status model.
/// This class is used throughout the app and must stay API-compatible.
class SubscriptionStatus {
  final bool isActive;
  final String? productId;
  final DateTime? expirationDate;
  final bool willRenew;
  final int bookCreditsRemaining;

  const SubscriptionStatus({
    this.isActive = false,
    this.productId,
    this.expirationDate,
    this.willRenew = false,
    this.bookCreditsRemaining = 0,
  });

  bool get isMonthly => productId?.contains('monthly') ?? false;
  bool get isYearly => productId?.contains('yearly') ?? false;
  bool get isLifetime => productId?.contains('lifetime') ?? false;

  SubscriptionStatus copyWith({
    bool? isActive,
    String? productId,
    DateTime? expirationDate,
    bool? willRenew,
    int? bookCreditsRemaining,
  }) {
    return SubscriptionStatus(
      isActive: isActive ?? this.isActive,
      productId: productId ?? this.productId,
      expirationDate: expirationDate ?? this.expirationDate,
      willRenew: willRenew ?? this.willRenew,
      bookCreditsRemaining: bookCreditsRemaining ?? this.bookCreditsRemaining,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Subscription Service — native in_app_purchase
// ══════════════════════════════════════════════════════════════════

/// Subscription service using Flutter's `in_app_purchase` plugin.
///
/// Replaces the previous RevenueCat-based implementation.
/// Uses the same public API (`SubscriptionStatus`, providers) so the
/// rest of the app doesn't need to change.
///
/// Flow:
/// 1. `initialize()` — checks store availability, queries product details,
///    starts listening to the purchase stream.
/// 2. `purchaseSubscription()` — triggers native store purchase sheet.
/// 3. Purchase stream updates `_currentStatus` and fires `onSubscriptionChanged`.
/// 4. `getSubscriptionStatus()` returns the cached status.
///
/// Receipt validation:
/// - For sandbox/testing: validates based on `purchaseDetails.status`.
/// - TODO: Add server-side receipt verification via Supabase Edge Function
///   for production (validate receipt with Apple/Google servers).
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isInitialized = false;
  bool _isAvailable = false;

  /// Debug log captured during initialization (visible on PaywallScreen in debug mode).
  final List<String> debugLog = [];

  /// Product IDs that the store confirmed it could not find (from last query).
  /// Non-empty means the store received the query but rejected these IDs —
  /// usually a mismatch between the code constant and App Store Connect / Play Console.
  List<String> lastNotFoundIDs = [];

  /// Error message from the last product query (null if no error).
  String? lastQueryError;

  /// Cached product details from the store.
  ProductDetails? _monthlyProduct;
  ProductDetails? _yearlyProduct;

  /// Current subscription status (updated by purchase stream).
  SubscriptionStatus _currentStatus = const SubscriptionStatus();

  /// Callback invoked when subscription state changes.
  /// Set from main.dart to invalidate Riverpod providers.
  VoidCallback? onSubscriptionChanged;

  // ── DEV-ONLY: Debug subscription override ──────────────────────
  static bool? _debugSubscriptionOverride;

  /// DEV ONLY — force subscription active/inactive for QA testing.
  /// Only effective in debug builds (`kDebugMode`).
  set debugSubscriptionOverride(bool? value) {
    if (kDebugMode) {
      _debugSubscriptionOverride = value;
      AppLogger.w('⚠️  DEV: Subscription override set to: $value');
    }
  }

  bool? get debugSubscriptionOverride => kDebugMode ? _debugSubscriptionOverride : null;

  /// The monthly subscription product (null until store is queried).
  ProductDetails? get monthlyProduct => _monthlyProduct;

  /// The yearly subscription product (null until store is queried).
  ProductDetails? get yearlyProduct => _yearlyProduct;

  /// Whether the IAP store is available on this device.
  bool get isStoreAvailable => _isAvailable;

  /// Whether subscription products are available for purchase.
  /// Returns `false` when the store isn't ready, products aren't configured,
  /// or the Paid Apps Agreement is pending (products show as "invalid").
  /// Only monthly subscription is surfaced — yearly is not shown to users.
  bool get isSubscriptionAvailable => _monthlyProduct != null;

  /// Re-query products from the store (e.g. when retry button is tapped).
  Future<void> retryQueryProducts() async {
    debugLog.add('--- retry ---');
    if (!_isAvailable) {
      _isAvailable = await _iap.isAvailable();
      debugLog.add('store re-check=$_isAvailable');
    }
    if (_isAvailable) {
      await _queryProducts();
    }
  }

  // ── Initialization ─────────────────────────────────────────────

  /// Initialize the IAP service.
  /// - Checks store availability
  /// - Queries product details
  /// - Starts purchase stream listener
  /// - Restores any pending transactions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugLog.clear();
      debugLog.add('init started');

      _isAvailable = await _iap.isAvailable();
      debugLog.add('store available=$_isAvailable');
      if (!_isAvailable) {
        AppLogger.w('IAP: Store is not available on this device');
        _isInitialized = true;
        return;
      }

      // Start listening to purchase stream BEFORE querying products.
      _listenToPurchaseStream();
      debugLog.add('purchase stream listening');

      // Query product details from the store.
      await _queryProducts();

      _isInitialized = true;
      debugLog.add('init done, product=${_monthlyProduct?.id ?? "NULL"}');
      AppLogger.i('IAP: Subscription service initialized'
          '${_monthlyProduct != null ? " — product: ${_monthlyProduct!.id} (${_monthlyProduct!.price})" : " — no products found"}');
    } catch (e, stack) {
      debugLog.add('init EXCEPTION: $e');
      AppLogger.e('IAP: Failed to initialize', error: e);
      _isInitialized = true;
      if (kDebugMode) {
        AppLogger.e('IAP: Stack trace', error: stack);
      }
    }
  }

  /// Query subscription product details from the store.
  ///
  /// Tries the default `in_app_purchase` query first (uses SK2 on iOS 15+).
  /// If that fails on iOS (common on physical devices with local .storekit),
  /// falls back to StoreKit 1's SKProductsRequest which works on both
  /// simulator and physical devices with StoreKit Configuration files.
  Future<void> _queryProducts() async {
    // Reset diagnostic fields before each query.
    lastNotFoundIDs = [];
    lastQueryError = null;

    debugLog.add('querying: ${IAPConfig.productIds}');

    // ── Attempt 1: Default query (SK2 on iOS 15+) ──
    try {
      final response = await _iap.queryProductDetails(IAPConfig.productIds);

      // Capture structured diagnostics for PaywallScreen display.
      lastNotFoundIDs = List<String>.from(response.notFoundIDs);
      if (response.error != null) {
        lastQueryError = response.error!.message;
      }

      debugLog.add('SK2 result: found=${response.productDetails.length}, '
          'notFound=${response.notFoundIDs}, '
          'error=${response.error?.message ?? "none"}');

      if (response.error == null && response.productDetails.isNotEmpty) {
        for (final product in response.productDetails) {
          if (product.id == IAPConfig.monthlySubscriptionId) {
            _monthlyProduct = product;
            debugLog.add('matched monthly: ${product.id} (${product.price})');
          } else if (product.id == IAPConfig.yearlySubscriptionId) {
            _yearlyProduct = product;
            debugLog.add('matched yearly: ${product.id} (${product.price})');
          }
        }
        if (_monthlyProduct != null) return;
      }
    } catch (e) {
      debugLog.add('SK2 threw: $e');
      lastQueryError = e.toString();
    }

    // ── Attempt 2: SK1 fallback (works on physical devices) ──
    if (Platform.isIOS && _monthlyProduct == null) {
      debugLog.add('trying SK1 fallback...');
      try {
        final sk1Response = await SKRequestMaker().startProductRequest(
          IAPConfig.productIds.toList(),
        );
        debugLog.add('SK1 result: ${sk1Response.products.length} products, '
            '${sk1Response.invalidProductIdentifiers.length} invalid');

        // SK1 invalid IDs are the SK1 equivalent of notFoundIDs.
        if (sk1Response.invalidProductIdentifiers.isNotEmpty) {
          lastNotFoundIDs = List<String>.from(sk1Response.invalidProductIdentifiers);
          debugLog.add('SK1 invalid IDs: ${sk1Response.invalidProductIdentifiers}');
        }

        for (final sk1Product in sk1Response.products) {
          debugLog.add('SK1 product: ${sk1Product.productIdentifier}, '
              'price=${sk1Product.price}');
          if (sk1Product.productIdentifier == IAPConfig.monthlySubscriptionId) {
            _monthlyProduct = AppStoreProductDetails.fromSKProduct(sk1Product);
            debugLog.add('SK1 matched monthly!');
          } else if (sk1Product.productIdentifier == IAPConfig.yearlySubscriptionId) {
            _yearlyProduct = AppStoreProductDetails.fromSKProduct(sk1Product);
            debugLog.add('SK1 matched yearly!');
          }
        }
        if (_monthlyProduct != null) return;
      } catch (e) {
        debugLog.add('SK1 threw: $e');
        lastQueryError ??= e.toString();
      }
    }

    if (_monthlyProduct == null) {
      debugLog.add('NO PRODUCT FOUND');
    }
  }

  // ── Purchase Stream ────────────────────────────────────────────

  void _listenToPurchaseStream() {
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        AppLogger.i('IAP: Purchase stream closed');
        _purchaseSubscription?.cancel();
      },
      onError: (Object error) {
        AppLogger.e('IAP: Purchase stream error', error: error);
      },
    );
  }

  /// Process incoming purchase updates from the store.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (kDebugMode) {
        AppLogger.d('IAP: Purchase update — '
            'product=${purchase.productID}, status=${purchase.status}, '
            'pending=${purchase.pendingCompletePurchase}');
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // TODO: Server-side receipt verification.
          // For production, send purchase.verificationData.serverVerificationData
          // to a Supabase Edge Function that validates with Apple/Google servers.
          // For now, trust the client-side status for sandbox testing.
          _handleSuccessfulPurchase(purchase);

        case PurchaseStatus.pending:
          AppLogger.i('IAP: Purchase pending for ${purchase.productID}');

        case PurchaseStatus.error:
          AppLogger.e('IAP: Purchase error for ${purchase.productID}: '
              '${purchase.error?.message ?? "unknown"}');

        case PurchaseStatus.canceled:
          AppLogger.i('IAP: Purchase cancelled for ${purchase.productID}');
      }

      // Complete pending purchases to acknowledge the transaction.
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchase) {
    AppLogger.i('IAP: Subscription activated — product=${purchase.productID}');

    _currentStatus = SubscriptionStatus(
      isActive: true,
      productId: purchase.productID,
      // Expiration date not directly available from in_app_purchase.
      // Server-side receipt verification would provide this.
      willRenew: true,
    );

    // Notify listeners (invalidates Riverpod providers in main.dart)
    onSubscriptionChanged?.call();

    // Sync to Supabase
    _syncSubscriptionToSupabase(
      isActive: true,
      productId: purchase.productID,
    );
  }

  // ── Public API ─────────────────────────────────────────────────

  /// Get current subscription status.
  ///
  /// Defensive guarantees (same as before):
  /// - Not initialized → `isActive: false`
  /// - Any error → `isActive: false`
  /// - Store not available → `isActive: false`
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    // DEV-ONLY override (tree-shaken in release)
    if (kDebugMode && _debugSubscriptionOverride != null) {
      AppLogger.w('⚠️  DEV: Using subscription override = $_debugSubscriptionOverride');
      return SubscriptionStatus(isActive: _debugSubscriptionOverride!);
    }

    if (!_isInitialized) {
      await initialize();
    }

    return _currentStatus;
  }

  /// Trigger native store purchase for the monthly subscription.
  ///
  /// Returns `true` on success, `false` if cancelled or product unavailable.
  /// The actual purchase result arrives asynchronously via the purchase stream.
  Future<bool> purchaseSubscription() async {
    if (!_isInitialized) await initialize();

    if (_monthlyProduct == null) {
      AppLogger.e('IAP: Cannot purchase — product not available');
      return false;
    }

    if (kDebugMode) {
      AppLogger.d('IAP: Initiating purchase — '
          'product=${_monthlyProduct!.id}, price=${_monthlyProduct!.price}');
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: _monthlyProduct!);
      // Use buyNonConsumable for auto-renewable subscriptions.
      // On iOS, the system handles subscription renewal automatically.
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (kDebugMode) {
        AppLogger.d('IAP: buyNonConsumable returned=$started');
      }
      return started;
    } catch (e) {
      AppLogger.e('IAP: Purchase initiation failed', error: e);
      return false;
    }
  }

  /// Restore previous purchases (e.g., after reinstall or new device).
  Future<bool> restorePurchases() async {
    if (!_isInitialized) await initialize();

    try {
      AppLogger.i('IAP: Restoring purchases...');
      await _iap.restorePurchases();
      // Results will arrive via the purchase stream.
      // We wait briefly for the stream to process restored purchases.
      await Future<void>.delayed(const Duration(seconds: 2));
      return _currentStatus.isActive;
    } catch (e) {
      AppLogger.e('IAP: Failed to restore purchases', error: e);
      return false;
    }
  }

  /// Refresh subscription status.
  /// Re-queries the store for current subscription state.
  Future<void> refreshStatus() async {
    if (!_isInitialized) await initialize();
    // Restoring purchases is the standard way to check current status
    // with in_app_purchase — it triggers the purchase stream with
    // any active subscriptions.
    try {
      await _iap.restorePurchases();
    } catch (e) {
      AppLogger.w('IAP: Refresh status failed (silent)', error: e);
    }
  }

  /// Called on user sign out — clears cached status.
  void onUserLogout() {
    _currentStatus = const SubscriptionStatus();
    AppLogger.i('IAP: Subscription state cleared on logout');
  }

  /// Called on user sign in — checks for existing subscription.
  Future<void> onUserLogin(String userId) async {
    AppLogger.i('IAP: User login — refreshing subscription for $userId');
    await refreshStatus();
  }

  // ── Supabase sync ──────────────────────────────────────────────

  Future<void> _syncSubscriptionToSupabase({
    required bool isActive,
    String? productId,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({
            'subscription_status': isActive ? 'active' : 'inactive',
            'subscription_product_id': productId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.i('IAP: Subscription synced to Supabase');
    } catch (e) {
      AppLogger.e('IAP: Failed to sync subscription to Supabase', error: e);
    }
  }

  /// Dispose the purchase stream subscription.
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}

// ══════════════════════════════════════════════════════════════════
// Riverpod Providers (same API as before — drop-in replacement)
// ══════════════════════════════════════════════════════════════════

/// Provider for subscription service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Provider for subscription status (auto-refreshes)
final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getSubscriptionStatus();
});

/// Provider to check if user has premium access
final hasPremiumProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(subscriptionStatusProvider.future);
  return status.isActive;
});

/// Whether subscription products are available for purchase.
/// When `false`, free content should be auto-granted (no products to buy).
final subscriptionAvailableProvider = Provider<bool>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.isSubscriptionAvailable;
});
