// Unit tests for payment models.
// Tests type safety, JSON parsing, and business logic for payment flows.

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/models/payment_models.dart';

void main() {
  group('Entitlement', () {
    test('fromJson parses valid entitlement data', () {
      final json = {
        'id': 'ent_123',
        'user_id': 'user_456',
        'audiobook_id': 789,
        'source': 'purchase',
        'created_at': '2024-01-15T10:30:00Z',
        'expires_at': null,
      };

      final entitlement = Entitlement.fromJson(json);

      expect(entitlement.id, equals('ent_123'));
      expect(entitlement.odId, equals('user_456'));
      expect(entitlement.audiobookId, equals(789));
      expect(entitlement.source, equals('purchase'));
      expect(entitlement.createdAt, isNotNull);
      expect(entitlement.expiresAt, isNull);
    });

    test('isValid returns true when no expiry set', () {
      final entitlement = Entitlement(
        id: '1',
        odId: 'user_1',
        audiobookId: 100,
        expiresAt: null,
      );

      expect(entitlement.isValid, isTrue);
    });

    test('isValid returns true when expiry is in future', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final entitlement = Entitlement(
        id: '1',
        odId: 'user_1',
        audiobookId: 100,
        expiresAt: futureDate,
      );

      expect(entitlement.isValid, isTrue);
    });

    test('isValid returns false when expired', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final entitlement = Entitlement(
        id: '1',
        odId: 'user_1',
        audiobookId: 100,
        expiresAt: pastDate,
      );

      expect(entitlement.isValid, isFalse);
    });

    test('toJson produces valid JSON', () {
      final entitlement = Entitlement(
        id: 'ent_1',
        odId: 'user_1',
        audiobookId: 100,
        source: 'gift',
      );

      final json = entitlement.toJson();

      expect(json['id'], equals('ent_1'));
      expect(json['user_id'], equals('user_1'));
      expect(json['audiobook_id'], equals(100));
      expect(json['source'], equals('gift'));
    });
  });

  group('PaymentIntentResponse', () {
    test('fromJson parses successful response', () {
      final json = {
        'client_secret': 'pi_secret_123',
        'amount': 50000,
        'currency': 'IRR',
      };

      final response = PaymentIntentResponse.fromJson(json);

      expect(response.clientSecret, equals('pi_secret_123'));
      expect(response.amount, equals(50000));
      expect(response.currency, equals('IRR'));
      expect(response.isSuccess, isTrue);
      expect(response.hasError, isFalse);
    });

    test('fromJson parses error response', () {
      final json = {
        'error': 'Invalid audiobook ID',
      };

      final response = PaymentIntentResponse.fromJson(json);

      expect(response.clientSecret, isNull);
      expect(response.error, equals('Invalid audiobook ID'));
      expect(response.isSuccess, isFalse);
      expect(response.hasError, isTrue);
    });
  });

  group('PaymentIntentRequest', () {
    test('toJson produces minimal request for regular purchase', () {
      const request = PaymentIntentRequest(audiobookId: 123);

      final json = request.toJson();

      expect(json['audiobook_id'], equals(123));
      expect(json.containsKey('gift_recipient_email'), isFalse);
      expect(json.containsKey('gift_message'), isFalse);
      expect(request.isGift, isFalse);
    });

    test('toJson includes gift fields for gift purchase', () {
      const request = PaymentIntentRequest(
        audiobookId: 123,
        giftRecipientEmail: 'friend@example.com',
        giftMessage: 'Enjoy this book!',
      );

      final json = request.toJson();

      expect(json['audiobook_id'], equals(123));
      expect(json['gift_recipient_email'], equals('friend@example.com'));
      expect(json['gift_message'], equals('Enjoy this book!'));
      expect(request.isGift, isTrue);
    });
  });

  group('PurchaseContext', () {
    test('fromAudiobook creates context from audiobook data', () {
      final audiobook = {
        'id': 456,
        'title_fa': 'کتاب تست',
        'price_toman': 25000,
        'is_free': false,
      };

      final context = PurchaseContext.fromAudiobook(audiobook);

      expect(context.audiobookId, equals(456));
      expect(context.audiobookTitle, equals('کتاب تست'));
      expect(context.priceToman, equals(25000));
      expect(context.isFree, isFalse);
      expect(context.isGift, isFalse);
    });

    test('fromAudiobook handles free audiobook', () {
      final audiobook = {
        'id': 789,
        'title_fa': 'کتاب رایگان',
        'price_toman': 0,
        'is_free': true,
      };

      final context = PurchaseContext.fromAudiobook(audiobook);

      expect(context.isFree, isTrue);
      expect(context.priceToman, equals(0));
    });

    test('asGift creates gift version of context', () {
      final context = PurchaseContext(
        audiobookId: 100,
        audiobookTitle: 'Test Book',
        priceToman: 15000,
        isFree: false,
      );

      final giftContext = context.asGift(
        recipientEmail: 'gift@example.com',
        message: 'Happy Birthday!',
      );

      expect(giftContext.audiobookId, equals(100));
      expect(giftContext.audiobookTitle, equals('Test Book'));
      expect(giftContext.isGift, isTrue);
      expect(giftContext.giftRecipientEmail, equals('gift@example.com'));
      expect(giftContext.giftMessage, equals('Happy Birthday!'));
    });
  });

  group('OwnershipResult', () {
    test('owned factory creates owned result', () {
      final result = OwnershipResult.owned();

      expect(result.isOwned, isTrue);
      expect(result.isFree, isFalse);
      expect(result.hasError, isFalse);
    });

    test('free factory creates free result', () {
      final result = OwnershipResult.free();

      expect(result.isOwned, isTrue);
      expect(result.isFree, isTrue);
    });

    test('notOwned factory creates not owned result', () {
      final result = OwnershipResult.notOwned();

      expect(result.isOwned, isFalse);
      expect(result.hasError, isFalse);
    });

    test('error factory creates error result', () {
      final result = OwnershipResult.error('Network error');

      expect(result.isOwned, isFalse);
      expect(result.hasError, isTrue);
      expect(result.errorMessage, equals('Network error'));
    });
  });

  group('GiftRecipientResult', () {
    test('fromJson parses valid recipient', () {
      final json = {
        'ok': true,
        'user_id': 'user_abc',
        'display_name': 'جان دو',
      };

      final result = GiftRecipientResult.fromJson(json);

      expect(result.isValid, isTrue);
      expect(result.recipientUserId, equals('user_abc'));
      expect(result.recipientDisplayName, equals('جان دو'));
      expect(result.isNotFound, isFalse);
    });

    test('fromJson parses not found response', () {
      final json = {
        'ok': false,
        'reason': 'not_found',
      };

      final result = GiftRecipientResult.fromJson(json);

      expect(result.isValid, isFalse);
      expect(result.isNotFound, isTrue);
      expect(result.reason, equals('not_found'));
    });
  });

  group('StripeEventType', () {
    test('fromString parses known event types', () {
      expect(
        StripeEventType.fromString('payment_intent.succeeded'),
        equals(StripeEventType.paymentIntentSucceeded),
      );
      expect(
        StripeEventType.fromString('payment_intent.payment_failed'),
        equals(StripeEventType.paymentIntentFailed),
      );
      expect(
        StripeEventType.fromString('charge.refunded'),
        equals(StripeEventType.chargeRefunded),
      );
    });

    test('fromString returns unknown for unrecognized events', () {
      expect(
        StripeEventType.fromString('some.other.event'),
        equals(StripeEventType.unknown),
      );
      expect(
        StripeEventType.fromString(null),
        equals(StripeEventType.unknown),
      );
    });
  });
}
