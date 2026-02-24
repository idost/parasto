// Centralized access gate for all content in Parasto.
//
// Every play/read/download check in the app routes through
// [AccessGateService.checkAccess]. This ensures a single source of truth
// for the subscription-based access model:
//
//   • Purchased items → always accessible (permanent)
//   • Preview chapters → always accessible
//   • Free items (is_free) + active subscription → accessible
//   • Free items (is_free) + NO subscription → LOCKED
//   • Free items (is_free) + subscription NOT AVAILABLE → LOCKED
//     (is_free always requires active subscription, no bypass)
//   • Paid items not owned → LOCKED (needs purchase)
//
// ── Grace Period / Billing Retry ─────────────────────────────────
//
// This service does NOT implement its own grace-period logic.
// The native IAP purchase stream reports subscription state as-is:
//
//   1. Normal active subscription → isActive = true
//   2. Apple/Google billing retry period → purchase stream updates status
//   3. Grace period (configurable in App Store Connect) → handled by store
//
// We pass the boolean from SubscriptionService directly as
// [isSubscriptionActive]. For production, server-side receipt
// verification should be added to validate subscription state.
//
// ── Guardrails ───────────────────────────────────────────────────
//
// 1. Grace period: Handled by the native store — no separate check needed.
// 2. Preview content: ALWAYS allowed — checked BEFORE subscription gate.
// 3. Background playback: Active playback is never interrupted. Only
//    starting a NEW locked chapter is blocked.

/// The 3 possible outcomes of an access check.
enum AccessType {
  /// User has access (purchased, free+subscribed, or preview).
  allowed,

  /// Item is free but user has no active subscription.
  needsSubscription,

  /// Item is paid and user has not purchased it.
  needsPurchase,
}

/// Result of an access check — the single source of truth.
class AccessResult {
  final AccessType type;

  /// Whether this is preview content (always allowed regardless of sub).
  final bool isPreview;

  const AccessResult({
    required this.type,
    this.isPreview = false,
  });

  /// Shorthand: can the user access this content right now?
  bool get canAccess => type == AccessType.allowed;

  /// Does the user need to subscribe?
  bool get needsSubscription => type == AccessType.needsSubscription;

  /// Does the user need to purchase?
  bool get needsPurchase => type == AccessType.needsPurchase;

  // ── Convenience factories ──────────────────────────────────────────

  factory AccessResult.allowed({bool isPreview = false}) =>
      AccessResult(type: AccessType.allowed, isPreview: isPreview);

  factory AccessResult.subscriptionRequired() =>
      const AccessResult(type: AccessType.needsSubscription);

  factory AccessResult.purchaseRequired() =>
      const AccessResult(type: AccessType.needsPurchase);
}

/// Centralized access gate — pure logic, no side effects.
///
/// Usage:
/// ```dart
/// final result = AccessGateService.checkAccess(
///   isOwned: entitlementExists,
///   isFree: audiobook['is_free'] == true,
///   isSubscriptionActive: subStatus.isActive,
/// );
/// if (!result.canAccess) { /* show CTA */ }
/// ```
class AccessGateService {
  /// Check whether the user can access a content item.
  ///
  /// [isOwned] — Does the user have an entitlement row (purchased or claimed)?
  /// [isFree] — Is this item marked `is_free` in the database?
  ///   `is_free` means "free with active subscription", NOT publicly free.
  /// [isSubscriptionActive] — Does the user have an active Parasto Premium
  ///   subscription? This value comes from `SubscriptionService`, which
  ///   uses the native `in_app_purchase` plugin. The store's billing grace
  ///   period and retry window are reflected in the purchase stream status.
  ///   When this is `true`, the user has access. When `false`, access
  ///   to `is_free` items is denied.
  /// [isPreviewContent] — Is this content a free preview (e.g. chapter
  ///   preview, article excerpt)?
  ///   Preview content is ALWAYS allowed, checked before the subscription
  ///   gate per guardrail #2.
  /// [isSubscriptionAvailable] — Are subscription products available for
  ///   purchase in the store? When `false` (store not ready, products not
  ///   configured, or Paid Apps Agreement pending), free items remain
  ///   locked — `is_free` always requires an active subscription.
  ///   Defaults to `true`.
  static AccessResult checkAccess({
    required bool isOwned,
    required bool isFree,
    required bool isSubscriptionActive,
    bool isPreviewContent = false,
    bool isSubscriptionAvailable = true,
  }) {
    // 1. Purchased / entitled items → always accessible (permanent).
    if (isOwned) return AccessResult.allowed();

    // 2. Preview content → always accessible.
    //    Checked BEFORE subscription gate so previews work for everyone.
    if (isPreviewContent) return AccessResult.allowed(isPreview: true);

    // 3. Free items → always require active subscription.
    //    is_free means "free with active subscription", never publicly free.
    //    When IAP is unavailable, content stays locked.
    if (isFree) {
      if (isSubscriptionActive) return AccessResult.allowed();
      return AccessResult.subscriptionRequired();
    }

    // 4. Paid item that user has not purchased.
    return AccessResult.purchaseRequired();
  }
}
