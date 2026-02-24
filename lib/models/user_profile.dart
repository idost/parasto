// User profile models for type-safe user data handling.

/// User role in the application.
enum UserRole {
  listener('listener'),
  narrator('narrator'),
  admin('admin'),
  superAdmin('super_admin');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.listener,
    );
  }

  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isNarrator => this == UserRole.narrator;
  bool get isListener => this == UserRole.listener;
}

/// User subscription tier.
enum SubscriptionTier {
  free('free'),
  premium('premium'),
  family('family');

  final String value;
  const SubscriptionTier(this.value);

  static SubscriptionTier fromString(String? value) {
    return SubscriptionTier.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SubscriptionTier.free,
    );
  }

  bool get isPremium => this != SubscriptionTier.free;
}

/// User profile model.
class UserProfile {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final UserRole role;
  final SubscriptionTier subscriptionTier;
  final String? bio;
  final bool isVerified;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final Map<String, dynamic>? preferences;

  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    required this.role,
    required this.subscriptionTier,
    this.bio,
    this.isVerified = false,
    this.isActive = true,
    this.createdAt,
    this.lastSeenAt,
    this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      subscriptionTier: SubscriptionTier.fromString(json['subscription_tier'] as String?),
      bio: json['bio'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: _parseDateTime(json['created_at']),
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (email != null) 'email': email,
    if (displayName != null) 'display_name': displayName,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    'role': role.value,
    'subscription_tier': subscriptionTier.value,
    if (bio != null) 'bio': bio,
    'is_verified': isVerified,
    'is_active': isActive,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
    if (preferences != null) 'preferences': preferences,
  };

  /// Get a display-friendly name.
  String get name => displayName ?? email?.split('@').first ?? 'کاربر';

  /// Check if user has admin privileges.
  bool get isAdmin => role.isAdmin;

  /// Check if user has narrator privileges.
  bool get isNarrator => role.isNarrator || role.isAdmin;

  /// Check if user has premium subscription.
  bool get isPremium => subscriptionTier.isPremium;

  /// Copy with updated fields.
  UserProfile copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    UserRole? role,
    SubscriptionTier? subscriptionTier,
    String? bio,
    bool? isVerified,
    bool? isActive,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt,
      preferences: preferences ?? this.preferences,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Creator/narrator profile with additional metadata.
class CreatorProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? websiteUrl;
  final String? instagramHandle;
  final int audiobookCount;
  final int followerCount;
  final double avgRating;
  final bool isVerified;
  final bool isActive;
  final DateTime? createdAt;

  const CreatorProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.websiteUrl,
    this.instagramHandle,
    this.audiobookCount = 0,
    this.followerCount = 0,
    this.avgRating = 0.0,
    this.isVerified = false,
    this.isActive = true,
    this.createdAt,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    return CreatorProfile(
      id: json['id']?.toString() ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      websiteUrl: json['website_url'] as String?,
      instagramHandle: json['instagram_handle'] as String?,
      audiobookCount: (json['audiobook_count'] as int?) ?? 0,
      followerCount: (json['follower_count'] as int?) ?? 0,
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      isVerified: (json['is_verified'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (bio != null) 'bio': bio,
    if (websiteUrl != null) 'website_url': websiteUrl,
    if (instagramHandle != null) 'instagram_handle': instagramHandle,
    'audiobook_count': audiobookCount,
    'follower_count': followerCount,
    'avg_rating': avgRating,
    'is_verified': isVerified,
    'is_active': isActive,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
