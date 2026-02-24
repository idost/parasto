// Payment and entitlement models for type-safe payment processing.
//
// These models ensure type safety for:
// - Payment intents and responses
// - Entitlements and ownership checks
// - Purchase flow data

/// Represents a user's entitlement (ownership) of content.
class Entitlement {
  final String id;
  final String odId;
  final int audiobookId;
  final String? source;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const Entitlement({
    required this.id,
    required this.odId,
    required this.audiobookId,
    this.source,
    this.createdAt,
    this.expiresAt,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    return Entitlement(
      id: json['id']?.toString() ?? '',
      odId: json['user_id']?.toString() ?? '',
      audiobookId: _parseInt(json['audiobook_id']),
      source: json['source'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      expiresAt: _parseDateTime(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': odId,
    'audiobook_id': audiobookId,
    if (source != null) 'source': source,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
  };

  /// Check if entitlement is still valid (not expired).
  bool get isValid {
    if (expiresAt == null) return true; // No expiry = permanent
    return DateTime.now().isBefore(expiresAt!);
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Response from create-payment-intent Edge Function.
class PaymentIntentResponse {
  final String? clientSecret;
  final String? error;
  final int? amount;
  final String? currency;

  const PaymentIntentResponse({
    this.clientSecret,
    this.error,
    this.amount,
    this.currency,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResponse(
      clientSecret: json['client_secret'] as String?,
      error: json['error'] as String?,
      amount: json['amount'] as int?,
      currency: json['currency'] as String?,
    );
  }

  bool get isSuccess => clientSecret != null && error == null;
  bool get hasError => error != null;
}

/// Request data for creating a payment intent.
class PaymentIntentRequest {
  final int audiobookId;
  final String? giftRecipientEmail;
  final String? giftMessage;

  const PaymentIntentRequest({
    required this.audiobookId,
    this.giftRecipientEmail,
    this.giftMessage,
  });

  Map<String, dynamic> toJson() => {
    'audiobook_id': audiobookId,
    if (giftRecipientEmail != null) 'gift_recipient_email': giftRecipientEmail,
    if (giftMessage != null) 'gift_message': giftMessage,
  };

  /// Whether this is a gift purchase.
  bool get isGift => giftRecipientEmail != null;
}

/// Purchase context for tracking the full purchase flow.
class PurchaseContext {
  final int audiobookId;
  final String audiobookTitle;
  final int priceToman;
  final bool isFree;
  final bool isGift;
  final String? giftRecipientEmail;
  final String? giftMessage;

  const PurchaseContext({
    required this.audiobookId,
    required this.audiobookTitle,
    required this.priceToman,
    required this.isFree,
    this.isGift = false,
    this.giftRecipientEmail,
    this.giftMessage,
  });

  /// Create from audiobook data map.
  factory PurchaseContext.fromAudiobook(Map<String, dynamic> audiobook) {
    return PurchaseContext(
      audiobookId: _parseInt(audiobook['id']),
      audiobookTitle: (audiobook['title_fa'] as String?) ?? '',
      priceToman: (audiobook['price_toman'] as int?) ?? 0,
      isFree: (audiobook['is_free'] as bool?) ?? false,
    );
  }

  /// Create a gift version of this context.
  PurchaseContext asGift({
    required String recipientEmail,
    String? message,
  }) {
    return PurchaseContext(
      audiobookId: audiobookId,
      audiobookTitle: audiobookTitle,
      priceToman: priceToman,
      isFree: isFree,
      isGift: true,
      giftRecipientEmail: recipientEmail,
      giftMessage: message,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Ownership check result with details.
class OwnershipResult {
  final bool isOwned;
  final bool isFree;
  final Entitlement? entitlement;
  final String? errorMessage;

  const OwnershipResult({
    required this.isOwned,
    this.isFree = false,
    this.entitlement,
    this.errorMessage,
  });

  /// User owns (free or purchased).
  factory OwnershipResult.owned({Entitlement? entitlement}) {
    return OwnershipResult(isOwned: true, entitlement: entitlement);
  }

  /// Content is free (no purchase needed).
  factory OwnershipResult.free() {
    return const OwnershipResult(isOwned: true, isFree: true);
  }

  /// User does not own.
  factory OwnershipResult.notOwned() {
    return const OwnershipResult(isOwned: false);
  }

  /// Error checking ownership.
  factory OwnershipResult.error(String message) {
    return OwnershipResult(isOwned: false, errorMessage: message);
  }

  bool get hasError => errorMessage != null;
}

/// Gift recipient verification result.
class GiftRecipientResult {
  final bool isValid;
  final String? recipientUserId;
  final String? recipientDisplayName;
  final String? reason;

  const GiftRecipientResult({
    required this.isValid,
    this.recipientUserId,
    this.recipientDisplayName,
    this.reason,
  });

  factory GiftRecipientResult.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] as bool? ?? false;
    return GiftRecipientResult(
      isValid: ok,
      recipientUserId: json['user_id'] as String?,
      recipientDisplayName: json['display_name'] as String?,
      reason: json['reason'] as String?,
    );
  }

  /// Recipient not found in the system.
  bool get isNotFound => reason == 'not_found';
}

/// Stripe webhook event types relevant to payments.
enum StripeEventType {
  paymentIntentSucceeded('payment_intent.succeeded'),
  paymentIntentFailed('payment_intent.payment_failed'),
  chargeRefunded('charge.refunded'),
  unknown('unknown');

  final String value;
  const StripeEventType(this.value);

  static StripeEventType fromString(String? value) {
    return StripeEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StripeEventType.unknown,
    );
  }
}
