import 'package:flutter_test/flutter_test.dart';
import 'package:myna/services/access_gate_service.dart';

void main() {
  group('AccessGateService.checkAccess', () {
    // ── 1. Purchased items ─────────────────────────────────────────

    test('purchased paid item → allowed (permanent)', () {
      final result = AccessGateService.checkAccess(
        isOwned: true,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(result.canAccess, isTrue);
      expect(result.type, AccessType.allowed);
      expect(result.isPreview, isFalse);
    });

    test('purchased free item → allowed even without subscription', () {
      final result = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: false,
      );
      expect(result.canAccess, isTrue);
      expect(result.type, AccessType.allowed);
    });

    test('purchased free item with active sub → still allowed', () {
      final result = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: true,
      );
      expect(result.canAccess, isTrue);
    });

    // ── 2. Preview chapters ────────────────────────────────────────

    test('preview chapter → always allowed, no subscription needed', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(result.canAccess, isTrue);
      expect(result.isPreview, isTrue);
    });

    test('preview chapter of free item without sub → allowed', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(result.canAccess, isTrue);
      expect(result.isPreview, isTrue);
    });

    // ── 3. Free items + subscription ───────────────────────────────

    test('free item + active subscription → allowed', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true,
      );
      expect(result.canAccess, isTrue);
      expect(result.type, AccessType.allowed);
      expect(result.needsSubscription, isFalse);
    });

    test('free item + NO subscription → LOCKED (needs subscription)', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
      );
      expect(result.canAccess, isFalse);
      expect(result.type, AccessType.needsSubscription);
      expect(result.needsSubscription, isTrue);
      expect(result.needsPurchase, isFalse);
    });

    // ── 4. Paid items not owned ────────────────────────────────────

    test('paid item not owned → LOCKED (needs purchase)', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(result.canAccess, isFalse);
      expect(result.type, AccessType.needsPurchase);
      expect(result.needsPurchase, isTrue);
      expect(result.needsSubscription, isFalse);
    });

    test('paid item not owned even with active sub → still needs purchase', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: true,
      );
      expect(result.canAccess, isFalse);
      expect(result.type, AccessType.needsPurchase);
    });

    // ── 5. Edge cases ──────────────────────────────────────────────

    test('all false → needs purchase (no free, no owned, no sub)', () {
      final result = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: false,
      );
      expect(result.canAccess, isFalse);
      expect(result.needsPurchase, isTrue);
    });

    test('all true → allowed (owned takes precedence)', () {
      final result = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: true,
        isPreviewContent: true,
      );
      expect(result.canAccess, isTrue);
      // Owned takes precedence, so isPreview should be false
      expect(result.isPreview, isFalse);
    });
  });

  group('AccessResult', () {
    test('factory allowed() has correct defaults', () {
      final result = AccessResult.allowed();
      expect(result.canAccess, isTrue);
      expect(result.isPreview, isFalse);
    });

    test('factory allowed(isPreview: true) sets preview', () {
      final result = AccessResult.allowed(isPreview: true);
      expect(result.canAccess, isTrue);
      expect(result.isPreview, isTrue);
    });

    test('factory subscriptionRequired() is not accessible', () {
      final result = AccessResult.subscriptionRequired();
      expect(result.canAccess, isFalse);
      expect(result.needsSubscription, isTrue);
    });

    test('factory purchaseRequired() is not accessible', () {
      final result = AccessResult.purchaseRequired();
      expect(result.canAccess, isFalse);
      expect(result.needsPurchase, isTrue);
    });
  });
}
