/// Model for narrator status requests
class NarratorRequest {
  final String id;
  final String userId;
  final String experienceText;
  final String voiceSamplePath;
  final NarratorRequestStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? adminFeedback;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NarratorRequest({
    required this.id,
    required this.userId,
    required this.experienceText,
    required this.voiceSamplePath,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.adminFeedback,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Supabase JSON
  factory NarratorRequest.fromJson(Map<String, dynamic> json) {
    return NarratorRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      experienceText: json['experience_text'] as String,
      voiceSamplePath: json['voice_sample_path'] as String,
      status: NarratorRequestStatus.fromString(json['status'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      adminFeedback: json['admin_feedback'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'experience_text': experienceText,
      'voice_sample_path': voiceSamplePath,
      'status': status.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'admin_feedback': adminFeedback,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copy with updated fields
  NarratorRequest copyWith({
    String? id,
    String? userId,
    String? experienceText,
    String? voiceSamplePath,
    NarratorRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? adminFeedback,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NarratorRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      experienceText: experienceText ?? this.experienceText,
      voiceSamplePath: voiceSamplePath ?? this.voiceSamplePath,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      adminFeedback: adminFeedback ?? this.adminFeedback,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Status enum for narrator requests
enum NarratorRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  final String value;
  const NarratorRequestStatus(this.value);

  static NarratorRequestStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return NarratorRequestStatus.pending;
      case 'approved':
        return NarratorRequestStatus.approved;
      case 'rejected':
        return NarratorRequestStatus.rejected;
      default:
        throw ArgumentError('Invalid status: $value');
    }
  }

  /// Get Farsi label
  String get label {
    switch (this) {
      case NarratorRequestStatus.pending:
        return 'در انتظار بررسی';
      case NarratorRequestStatus.approved:
        return 'تأیید شده';
      case NarratorRequestStatus.rejected:
        return 'رد شده';
    }
  }
}
