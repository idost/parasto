// Comprehensive hardening tests for AccessGateService.
//
// These tests verify every access path including edge cases,
// priority ordering, and AccessResult property correctness.

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/services/access_gate_service.dart';

void main() {
  // ══════════════════════════════════════════════════════════════
  // 1. OWNED (purchased / entitled) — always allowed, permanent
  // ══════════════════════════════════════════════════════════════
  group('Owned items → always allowed (permanent)', () {
    test('owned + paid + no sub → allowed', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(r.canAccess, isTrue);
      expect(r.type, AccessType.allowed);
      expect(r.isPreview, isFalse);
      expect(r.needsSubscription, isFalse);
      expect(r.needsPurchase, isFalse);
    });

    test('owned + paid + active sub → allowed', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: false,
        isSubscriptionActive: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.type, AccessType.allowed);
    });

    test('owned + is_free + no sub → allowed (ownership overrides sub)', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: false,
      );
      expect(r.canAccess, isTrue);
      expect(r.type, AccessType.allowed);
      expect(r.isPreview, isFalse);
    });

    test('owned + is_free + active sub → allowed', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: true,
      );
      expect(r.canAccess, isTrue);
    });

    test('owned + preview → allowed (owned takes precedence, isPreview=false)', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(r.canAccess, isTrue);
      // Owned takes precedence over preview — isPreview should be false
      // because the user has full access, not just preview access.
      expect(r.isPreview, isFalse);
    });

    test('all flags true → allowed (owned takes precedence)', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: true,
        isPreviewContent: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isFalse, reason: 'Owned takes precedence');
      expect(r.type, AccessType.allowed);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 2. PREVIEW — always allowed, checked BEFORE subscription gate
  // ══════════════════════════════════════════════════════════════
  group('Preview chapters → always allowed (guardrail #2)', () {
    test('preview + not owned + not free + no sub → allowed (preview)', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isTrue);
      expect(r.type, AccessType.allowed);
    });

    test('preview + not owned + is_free + no sub → allowed (preview before sub gate)', () {
      // KEY GUARDRAIL: Preview must work even for free items without sub.
      // Preview is checked BEFORE the subscription gate.
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isTrue);
    });

    test('preview + not owned + is_free + active sub → allowed (preview)', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true,
        isPreviewContent: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isTrue);
    });

    test('preview + not owned + paid + active sub → allowed (preview)', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: true,
        isPreviewContent: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 3. FREE ITEMS + SUBSCRIPTION
  // ══════════════════════════════════════════════════════════════
  group('Free items (is_free) + subscription', () {
    test('is_free + active subscription → allowed', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true,
      );
      expect(r.canAccess, isTrue);
      expect(r.type, AccessType.allowed);
      expect(r.isPreview, isFalse);
      expect(r.needsSubscription, isFalse);
    });

    test('is_free + inactive subscription → needsSubscription', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsSubscription);
      expect(r.needsSubscription, isTrue);
      expect(r.needsPurchase, isFalse);
      expect(r.isPreview, isFalse);
    });

    test('is_free + inactive sub (no preview) → locked, NOT needsPurchase', () {
      // Verify the distinction: free items need sub, not purchase.
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: false,
      );
      expect(r.needsSubscription, isTrue);
      expect(r.needsPurchase, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 4. PAID ITEMS NOT OWNED
  // ══════════════════════════════════════════════════════════════
  group('Paid items not owned → needsPurchase', () {
    test('paid + not owned + no sub → needsPurchase', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsPurchase);
      expect(r.needsPurchase, isTrue);
      expect(r.needsSubscription, isFalse);
    });

    test('paid + not owned + active sub → still needsPurchase (sub does NOT unlock paid items)', () {
      // KEY: Subscription only unlocks is_free items, never paid items.
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: true,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsPurchase);
      expect(r.needsPurchase, isTrue);
    });

    test('paid + not owned + no sub + no preview → needsPurchase', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.needsPurchase, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 5. PRIORITY ORDERING
  // ══════════════════════════════════════════════════════════════
  group('Priority ordering', () {
    test('priority: owned > preview > free+sub > purchase', () {
      // Verify each level overrides the ones below it:

      // Level 1: Owned always wins
      final owned = AccessGateService.checkAccess(
        isOwned: true, isFree: true, isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(owned.canAccess, isTrue);
      expect(owned.isPreview, isFalse, reason: 'Owned takes precedence over preview');

      // Level 2: Preview wins over sub check
      final preview = AccessGateService.checkAccess(
        isOwned: false, isFree: true, isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(preview.canAccess, isTrue);
      expect(preview.isPreview, isTrue, reason: 'Preview wins when not owned');

      // Level 3: Free + sub wins over purchase
      final freeSub = AccessGateService.checkAccess(
        isOwned: false, isFree: true, isSubscriptionActive: true,
      );
      expect(freeSub.canAccess, isTrue);

      // Level 4: Free without sub → locked (needs subscription, not purchase)
      final freeNoSub = AccessGateService.checkAccess(
        isOwned: false, isFree: true, isSubscriptionActive: false,
      );
      expect(freeNoSub.canAccess, isFalse);
      expect(freeNoSub.needsSubscription, isTrue);

      // Level 5: Paid + not owned → needs purchase
      final paidNotOwned = AccessGateService.checkAccess(
        isOwned: false, isFree: false, isSubscriptionActive: false,
      );
      expect(paidNotOwned.canAccess, isFalse);
      expect(paidNotOwned.needsPurchase, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 6. EDGE CASES
  // ══════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('all false → needsPurchase', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.needsPurchase, isTrue);
    });

    test('isPreviewContent default is false', () {
      // Not passing isPreviewContent should default to false
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.needsPurchase, isTrue);
    });

    test('AccessResult getters are mutually exclusive', () {
      final allowed = AccessResult.allowed();
      expect(allowed.canAccess, isTrue);
      expect(allowed.needsSubscription, isFalse);
      expect(allowed.needsPurchase, isFalse);

      final subReq = AccessResult.subscriptionRequired();
      expect(subReq.canAccess, isFalse);
      expect(subReq.needsSubscription, isTrue);
      expect(subReq.needsPurchase, isFalse);

      final purchReq = AccessResult.purchaseRequired();
      expect(purchReq.canAccess, isFalse);
      expect(purchReq.needsSubscription, isFalse);
      expect(purchReq.needsPurchase, isTrue);
    });

    test('AccessResult.allowed(isPreview: true) is still allowed', () {
      final r = AccessResult.allowed(isPreview: true);
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isTrue);
      expect(r.type, AccessType.allowed);
    });

    test('AccessResult.subscriptionRequired() has isPreview=false', () {
      final r = AccessResult.subscriptionRequired();
      expect(r.isPreview, isFalse);
    });

    test('AccessResult.purchaseRequired() has isPreview=false', () {
      final r = AccessResult.purchaseRequired();
      expect(r.isPreview, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 7. GRACE PERIOD (documented behavior)
  // ══════════════════════════════════════════════════════════════
  group('Grace period behavior (documented)', () {
    // NOTE: Grace period is handled by the native store (Apple/Google).
    // The IAP purchase stream reports active status during billing retry.
    // AccessGateService treats isSubscriptionActive=true as active, period.
    // This test documents that the gate doesn't need its own grace logic.

    test('isSubscriptionActive=true covers grace period (store handles it)', () {
      // During grace period, the store reports subscription as active.
      // We pass that through as isSubscriptionActive=true.
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true, // store says active (in grace period)
      );
      expect(r.canAccess, isTrue);
      expect(r.type, AccessType.allowed);
    });

    test('isSubscriptionActive=false means truly expired (no grace)', () {
      // When RC finally reports inactive (grace period exhausted),
      // we correctly lock the content.
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false, // RC says truly expired
      );
      expect(r.canAccess, isFalse);
      expect(r.needsSubscription, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 8. SUBSCRIPTION AVAILABILITY (graceful fallback)
  // ══════════════════════════════════════════════════════════════
  group('Subscription availability (isSubscriptionAvailable)', () {
    test('free + no sub + sub NOT available → LOCKED (no auto-grant)', () {
      // is_free always requires active subscription. No bypass when IAP unavailable.
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isSubscriptionAvailable: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsSubscription);
    });

    test('free + no sub + sub available → needsSubscription (normal gate)', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isSubscriptionAvailable: true,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsSubscription);
    });

    test('free + active sub + sub NOT available → allowed', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true,
        isSubscriptionAvailable: false,
      );
      expect(r.canAccess, isTrue);
    });

    test('paid + not owned + sub NOT available → still needsPurchase', () {
      // Subscription availability only affects free items, not paid ones
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isSubscriptionAvailable: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsPurchase);
    });

    test('owned + sub NOT available → allowed (owned always wins)', () {
      final r = AccessGateService.checkAccess(
        isOwned: true,
        isFree: true,
        isSubscriptionActive: false,
        isSubscriptionAvailable: false,
      );
      expect(r.canAccess, isTrue);
    });

    test('preview + sub NOT available → allowed (preview always wins)', () {
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: true,
        isSubscriptionAvailable: false,
      );
      expect(r.canAccess, isTrue);
      expect(r.isPreview, isTrue);
    });

    test('isSubscriptionAvailable defaults to true', () {
      // When not explicitly passed, behaves as before (gate enforced)
      final r = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
      );
      expect(r.canAccess, isFalse);
      expect(r.type, AccessType.needsSubscription);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // 9. EXHAUSTIVE TRUTH TABLE (all 16 input combinations)
  // ══════════════════════════════════════════════════════════════
  group('Exhaustive truth table (all 16 combinations)', () {
    // Inputs: isOwned, isFree, isSubscriptionActive, isPreviewContent
    // Each can be true/false → 2^4 = 16 combinations.

    final cases = <(bool, bool, bool, bool, bool, AccessType, bool)>[
      // (owned, free, sub, preview) → (canAccess, type, isPreview)
      (false, false, false, false, false, AccessType.needsPurchase, false),
      (false, false, false, true,  true,  AccessType.allowed, true),
      (false, false, true,  false, false, AccessType.needsPurchase, false),
      (false, false, true,  true,  true,  AccessType.allowed, true),
      (false, true,  false, false, false, AccessType.needsSubscription, false),
      (false, true,  false, true,  true,  AccessType.allowed, true),
      (false, true,  true,  false, true,  AccessType.allowed, false),
      (false, true,  true,  true,  true,  AccessType.allowed, true),
      (true,  false, false, false, true,  AccessType.allowed, false),
      (true,  false, false, true,  true,  AccessType.allowed, false),
      (true,  false, true,  false, true,  AccessType.allowed, false),
      (true,  false, true,  true,  true,  AccessType.allowed, false),
      (true,  true,  false, false, true,  AccessType.allowed, false),
      (true,  true,  false, true,  true,  AccessType.allowed, false),
      (true,  true,  true,  false, true,  AccessType.allowed, false),
      (true,  true,  true,  true,  true,  AccessType.allowed, false),
    ];

    for (int i = 0; i < cases.length; i++) {
      final (owned, free, sub, preview, expectedAccess, expectedType, expectedPreview) = cases[i];
      test('case ${i + 1}: owned=$owned free=$free sub=$sub preview=$preview', () {
        final r = AccessGateService.checkAccess(
          isOwned: owned,
          isFree: free,
          isSubscriptionActive: sub,
          isPreviewContent: preview,
        );
        expect(r.canAccess, expectedAccess,
            reason: 'canAccess should be $expectedAccess');
        expect(r.type, expectedType,
            reason: 'type should be $expectedType');
        expect(r.isPreview, expectedPreview,
            reason: 'isPreview should be $expectedPreview');
      });
    }
  });
}
