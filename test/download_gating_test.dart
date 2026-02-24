// Tests for download access gating via AccessGateService.
//
// These tests verify that the download gate logic (identical to the
// AccessGateService truth table) correctly blocks downloads when access
// is denied. The gate is checked in download_provider.dart BEFORE any
// network/file I/O happens.
//
// We test the gate logic directly (pure function, no side effects)
// rather than mocking SubscriptionService, since the download provider
// delegates all access decisions to AccessGateService.checkAccess().

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/services/access_gate_service.dart';

void main() {
  group('Download gating via AccessGateService', () {
    test('free item + inactive subscription → download blocked (needsSubscription)', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
      );
      expect(access.canAccess, isFalse,
          reason: 'Free items without active sub must be blocked');
      expect(access.type, AccessType.needsSubscription);
    });

    test('paid item + not owned → download blocked (needsPurchase)', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(access.canAccess, isFalse,
          reason: 'Paid items that are not owned must be blocked');
      expect(access.type, AccessType.needsPurchase);
    });

    test('owned item → download allowed regardless of subscription', () {
      final access = AccessGateService.checkAccess(
        isOwned: true,
        isFree: false,
        isSubscriptionActive: false,
      );
      expect(access.canAccess, isTrue,
          reason: 'Owned items are always downloadable');
      expect(access.type, AccessType.allowed);
    });

    test('free item + active subscription → download allowed', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true,
      );
      expect(access.canAccess, isTrue,
          reason: 'Free items with active sub should be downloadable');
    });

    test('paid item + not owned + active subscription → still blocked', () {
      // Subscription does NOT unlock paid items — only purchase does.
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: true,
      );
      expect(access.canAccess, isFalse,
          reason: 'Subscription does not unlock paid items');
      expect(access.type, AccessType.needsPurchase);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // Preview chapter download gating
  // ══════════════════════════════════════════════════════════════
  group('Preview chapter download gating', () {
    test('preview + free + no subscription → download allowed', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(access.canAccess, isTrue,
          reason: 'Preview chapters on free items are always downloadable');
      expect(access.isPreview, isTrue);
    });

    test('preview + paid + not owned → download allowed', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: false,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(access.canAccess, isTrue,
          reason: 'Preview chapters on paid items are always downloadable');
      expect(access.isPreview, isTrue);
    });

    test('preview + is_free + subscription inactive → still allowed', () {
      // KEY: Even when is_free=true and subscription is inactive,
      // a preview chapter must be accessible. Preview bypasses sub gate.
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: true,
      );
      expect(access.canAccess, isTrue,
          reason: 'Preview bypasses the subscription gate');
      expect(access.type, AccessType.allowed);
      expect(access.isPreview, isTrue);
    });

    test('non-preview + free + no sub → blocked (only preview bypasses)', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isPreviewContent: false,
      );
      expect(access.canAccess, isFalse,
          reason: 'Non-preview free chapters need subscription');
      expect(access.type, AccessType.needsSubscription);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // IAP unavailable — no auto-grant
  // ══════════════════════════════════════════════════════════════
  group('IAP unavailable — no bypass', () {
    test('free item + IAP unavailable + no subscription → LOCKED', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: false,
        isSubscriptionAvailable: false,
      );
      expect(access.canAccess, isFalse,
          reason: 'is_free always requires active subscription, even when IAP unavailable');
      expect(access.type, AccessType.needsSubscription);
    });

    test('free item + IAP unavailable + active subscription → allowed', () {
      final access = AccessGateService.checkAccess(
        isOwned: false,
        isFree: true,
        isSubscriptionActive: true,
        isSubscriptionAvailable: false,
      );
      expect(access.canAccess, isTrue,
          reason: 'Active subscription grants access regardless of IAP availability');
    });

    test('owned item + IAP unavailable → allowed', () {
      final access = AccessGateService.checkAccess(
        isOwned: true,
        isFree: false,
        isSubscriptionActive: false,
        isSubscriptionAvailable: false,
      );
      expect(access.canAccess, isTrue,
          reason: 'Owned items always accessible regardless of IAP');
    });
  });
}
