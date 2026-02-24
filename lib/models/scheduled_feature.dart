/// Types of featured content
enum FeatureType {
  featured,
  banner,
  hero,
  categoryHighlight,
}

/// Status of a scheduled feature
enum ScheduleStatus {
  scheduled,
  active,
  completed,
  cancelled,
}

/// Represents a scheduled feature for an audiobook
class ScheduledFeature {
  final String id;
  final int audiobookId;
  final DateTime startDate;
  final DateTime? endDate;
  final ScheduleStatus status;
  final FeatureType featureType;
  final int priority;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;

  // Joined audiobook data (optional)
  final String? audiobookTitle;
  final String? audiobookCoverUrl;
  final bool? isMusic;

  const ScheduledFeature({
    required this.id,
    required this.audiobookId,
    required this.startDate,
    this.endDate,
    this.status = ScheduleStatus.scheduled,
    this.featureType = FeatureType.featured,
    this.priority = 0,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.audiobookTitle,
    this.audiobookCoverUrl,
    this.isMusic,
  });

  factory ScheduledFeature.fromJson(Map<String, dynamic> json) {
    // Handle joined audiobook data
    final audiobook = json['audiobooks'] as Map<String, dynamic>?;

    return ScheduledFeature(
      id: json['id'] as String,
      audiobookId: json['audiobook_id'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: _parseStatus(json['status'] as String? ?? 'scheduled'),
      featureType: _parseFeatureType(json['feature_type'] as String? ?? 'featured'),
      priority: json['priority'] as int? ?? 0,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      notes: json['notes'] as String?,
      audiobookTitle: audiobook?['title_fa'] as String?,
      audiobookCoverUrl: audiobook?['cover_url'] as String?,
      isMusic: audiobook?['is_music'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audiobook_id': audiobookId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status.name,
      'feature_type': _featureTypeToString(featureType),
      'priority': priority,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  ScheduledFeature copyWith({
    DateTime? startDate,
    DateTime? endDate,
    ScheduleStatus? status,
    FeatureType? featureType,
    int? priority,
    String? notes,
    bool clearEndDate = false,
  }) {
    return ScheduledFeature(
      id: id,
      audiobookId: audiobookId,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      featureType: featureType ?? this.featureType,
      priority: priority ?? this.priority,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      notes: notes ?? this.notes,
      audiobookTitle: audiobookTitle,
      audiobookCoverUrl: audiobookCoverUrl,
      isMusic: isMusic,
    );
  }

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /// Check if the schedule is currently active
  bool get isActive => status == ScheduleStatus.active;

  /// Check if the schedule is pending (scheduled but not started)
  bool get isPending =>
      status == ScheduleStatus.scheduled && startDate.isAfter(DateTime.now());

  /// Days until the schedule starts
  int get daysUntilStart => startDate.difference(DateTime.now()).inDays;

  /// Days remaining until the schedule ends
  int? get daysRemaining {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }

  /// Duration of the schedule in days
  int? get durationDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays;
  }

  /// Check if the schedule has no end date (indefinite)
  bool get isIndefinite => endDate == null;

  // ============================================================================
  // DISPLAY HELPERS
  // ============================================================================

  /// Label for the feature type (in Persian)
  String get featureTypeLabel {
    switch (featureType) {
      case FeatureType.featured:
        return 'ویژه';
      case FeatureType.banner:
        return 'بنر';
      case FeatureType.hero:
        return 'قهرمان';
      case FeatureType.categoryHighlight:
        return 'برجسته دسته‌بندی';
    }
  }

  /// Status label (in Persian)
  String get statusLabel {
    switch (status) {
      case ScheduleStatus.scheduled:
        return 'زمان‌بندی شده';
      case ScheduleStatus.active:
        return 'فعال';
      case ScheduleStatus.completed:
        return 'تکمیل شده';
      case ScheduleStatus.cancelled:
        return 'لغو شده';
    }
  }

  // ============================================================================
  // PARSERS
  // ============================================================================

  static ScheduleStatus _parseStatus(String status) {
    switch (status) {
      case 'scheduled':
        return ScheduleStatus.scheduled;
      case 'active':
        return ScheduleStatus.active;
      case 'completed':
        return ScheduleStatus.completed;
      case 'cancelled':
        return ScheduleStatus.cancelled;
      default:
        return ScheduleStatus.scheduled;
    }
  }

  static FeatureType _parseFeatureType(String type) {
    switch (type) {
      case 'featured':
        return FeatureType.featured;
      case 'banner':
        return FeatureType.banner;
      case 'hero':
        return FeatureType.hero;
      case 'category_highlight':
        return FeatureType.categoryHighlight;
      default:
        return FeatureType.featured;
    }
  }

  static String _featureTypeToString(FeatureType type) {
    switch (type) {
      case FeatureType.featured:
        return 'featured';
      case FeatureType.banner:
        return 'banner';
      case FeatureType.hero:
        return 'hero';
      case FeatureType.categoryHighlight:
        return 'category_highlight';
    }
  }
}

/// Represents a scheduled promotion (discount)
class ScheduledPromotion {
  final String id;
  final int? audiobookId;
  final int? categoryId;
  final int? creatorId;
  final String scope; // 'audiobook', 'category', 'creator', 'all'
  final String discountType; // 'percentage', 'fixed', 'free'
  final double discountValue;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'scheduled', 'active', 'completed', 'cancelled'
  final String titleFa;
  final String? titleEn;
  final String? description;
  final String? bannerUrl;
  final String? createdBy;
  final DateTime createdAt;

  const ScheduledPromotion({
    required this.id,
    this.audiobookId,
    this.categoryId,
    this.creatorId,
    required this.scope,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    this.status = 'scheduled',
    required this.titleFa,
    this.titleEn,
    this.description,
    this.bannerUrl,
    this.createdBy,
    required this.createdAt,
  });

  factory ScheduledPromotion.fromJson(Map<String, dynamic> json) {
    return ScheduledPromotion(
      id: json['id'] as String,
      audiobookId: json['audiobook_id'] as int?,
      categoryId: json['category_id'] as int?,
      creatorId: json['creator_id'] as int?,
      scope: json['scope'] as String,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String? ?? 'scheduled',
      titleFa: json['title_fa'] as String,
      titleEn: json['title_en'] as String?,
      description: json['description'] as String?,
      bannerUrl: json['banner_url'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audiobook_id': audiobookId,
      'category_id': categoryId,
      'creator_id': creatorId,
      'scope': scope,
      'discount_type': discountType,
      'discount_value': discountValue,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'title_fa': titleFa,
      'title_en': titleEn,
      'description': description,
      'banner_url': bannerUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if the promotion is currently active
  bool get isActive => status == 'active';

  /// Discount display string
  String get discountLabel {
    switch (discountType) {
      case 'percentage':
        return '${discountValue.toInt()}٪ تخفیف';
      case 'fixed':
        return '${discountValue.toInt()} تومان تخفیف';
      case 'free':
        return 'رایگان';
      default:
        return '';
    }
  }

  /// Scope label (in Persian)
  String get scopeLabel {
    switch (scope) {
      case 'audiobook':
        return 'یک محتوا';
      case 'category':
        return 'دسته‌بندی';
      case 'creator':
        return 'سازنده';
      case 'all':
        return 'همه محتوا';
      default:
        return '';
    }
  }

  /// Duration in days
  int get durationDays => endDate.difference(startDate).inDays;
}
