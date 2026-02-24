/// Types of content quality issues
enum QualityIssueType {
  audioFormat,
  audioBitrate,
  audioDuration,
  missingCover,
  lowQualityCover,
  coverDimensions,
  missingMetadata,
  duplicateContent,
  duplicateTitle,
  profanityDetected,
  copyrightFlag,
}

/// Severity levels for quality issues
enum QualitySeverity {
  info,
  warning,
  error,
  critical,
}

/// Status of a quality issue
enum QualityIssueStatus {
  open,
  resolved,
  ignored,
}

/// Represents a content quality issue
class QualityIssue {
  final String id;
  final int audiobookId;
  final QualityIssueType type;
  final QualitySeverity severity;
  final String message;
  final Map<String, dynamic> details;
  final QualityIssueStatus status;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final DateTime createdAt;

  const QualityIssue({
    required this.id,
    required this.audiobookId,
    required this.type,
    required this.severity,
    required this.message,
    this.details = const {},
    this.status = QualityIssueStatus.open,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    required this.createdAt,
  });

  factory QualityIssue.fromJson(Map<String, dynamic> json) {
    return QualityIssue(
      id: json['id'] as String,
      audiobookId: json['audiobook_id'] as int,
      type: _parseType(json['type'] as String),
      severity: _parseSeverity(json['severity'] as String),
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>? ?? {},
      status: _parseStatus(json['status'] as String? ?? 'open'),
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolutionNote: json['resolution_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audiobook_id': audiobookId,
      'type': _typeToString(type),
      'severity': severity.name,
      'message': message,
      'details': details,
      'status': status.name,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_note': resolutionNote,
      'created_at': createdAt.toIso8601String(),
    };
  }

  QualityIssue copyWith({
    QualityIssueStatus? status,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNote,
  }) {
    return QualityIssue(
      id: id,
      audiobookId: audiobookId,
      type: type,
      severity: severity,
      message: message,
      details: details,
      status: status ?? this.status,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      createdAt: createdAt,
    );
  }

  // ============================================================================
  // DISPLAY HELPERS
  // ============================================================================

  /// Label for the issue type (in Persian)
  String get typeLabel {
    switch (type) {
      case QualityIssueType.audioFormat:
        return 'فرمت صوتی';
      case QualityIssueType.audioBitrate:
        return 'کیفیت صوتی';
      case QualityIssueType.audioDuration:
        return 'مدت زمان';
      case QualityIssueType.missingCover:
        return 'جلد ناموجود';
      case QualityIssueType.lowQualityCover:
        return 'کیفیت جلد';
      case QualityIssueType.coverDimensions:
        return 'ابعاد جلد';
      case QualityIssueType.missingMetadata:
        return 'اطلاعات ناقص';
      case QualityIssueType.duplicateContent:
        return 'محتوای تکراری';
      case QualityIssueType.duplicateTitle:
        return 'عنوان تکراری';
      case QualityIssueType.profanityDetected:
        return 'محتوای نامناسب';
      case QualityIssueType.copyrightFlag:
        return 'مشکل کپی‌رایت';
    }
  }

  /// Severity label (in Persian)
  String get severityLabel {
    switch (severity) {
      case QualitySeverity.info:
        return 'اطلاعاتی';
      case QualitySeverity.warning:
        return 'هشدار';
      case QualitySeverity.error:
        return 'خطا';
      case QualitySeverity.critical:
        return 'بحرانی';
    }
  }

  /// Status label (in Persian)
  String get statusLabel {
    switch (status) {
      case QualityIssueStatus.open:
        return 'باز';
      case QualityIssueStatus.resolved:
        return 'حل شده';
      case QualityIssueStatus.ignored:
        return 'نادیده';
    }
  }

  // ============================================================================
  // PARSERS
  // ============================================================================

  static QualityIssueType _parseType(String type) {
    switch (type) {
      case 'audio_format':
        return QualityIssueType.audioFormat;
      case 'audio_bitrate':
        return QualityIssueType.audioBitrate;
      case 'audio_duration':
        return QualityIssueType.audioDuration;
      case 'missing_cover':
        return QualityIssueType.missingCover;
      case 'low_quality_cover':
        return QualityIssueType.lowQualityCover;
      case 'cover_dimensions':
        return QualityIssueType.coverDimensions;
      case 'missing_metadata':
        return QualityIssueType.missingMetadata;
      case 'duplicate_content':
        return QualityIssueType.duplicateContent;
      case 'duplicate_title':
        return QualityIssueType.duplicateTitle;
      case 'profanity_detected':
        return QualityIssueType.profanityDetected;
      case 'copyright_flag':
        return QualityIssueType.copyrightFlag;
      default:
        return QualityIssueType.missingMetadata;
    }
  }

  static QualitySeverity _parseSeverity(String severity) {
    switch (severity) {
      case 'info':
        return QualitySeverity.info;
      case 'warning':
        return QualitySeverity.warning;
      case 'error':
        return QualitySeverity.error;
      case 'critical':
        return QualitySeverity.critical;
      default:
        return QualitySeverity.warning;
    }
  }

  static QualityIssueStatus _parseStatus(String status) {
    switch (status) {
      case 'open':
        return QualityIssueStatus.open;
      case 'resolved':
        return QualityIssueStatus.resolved;
      case 'ignored':
        return QualityIssueStatus.ignored;
      default:
        return QualityIssueStatus.open;
    }
  }

  static String _typeToString(QualityIssueType type) {
    switch (type) {
      case QualityIssueType.audioFormat:
        return 'audio_format';
      case QualityIssueType.audioBitrate:
        return 'audio_bitrate';
      case QualityIssueType.audioDuration:
        return 'audio_duration';
      case QualityIssueType.missingCover:
        return 'missing_cover';
      case QualityIssueType.lowQualityCover:
        return 'low_quality_cover';
      case QualityIssueType.coverDimensions:
        return 'cover_dimensions';
      case QualityIssueType.missingMetadata:
        return 'missing_metadata';
      case QualityIssueType.duplicateContent:
        return 'duplicate_content';
      case QualityIssueType.duplicateTitle:
        return 'duplicate_title';
      case QualityIssueType.profanityDetected:
        return 'profanity_detected';
      case QualityIssueType.copyrightFlag:
        return 'copyright_flag';
    }
  }
}

/// Quality check run record
class QualityCheckRun {
  final String id;
  final String scope; // 'single', 'batch', 'full'
  final List<int>? audiobookIds;
  final String status; // 'running', 'completed', 'failed'
  final int totalItems;
  final int checkedItems;
  final int issuesFound;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? triggeredBy;

  const QualityCheckRun({
    required this.id,
    required this.scope,
    this.audiobookIds,
    required this.status,
    this.totalItems = 0,
    this.checkedItems = 0,
    this.issuesFound = 0,
    required this.startedAt,
    this.completedAt,
    this.triggeredBy,
  });

  factory QualityCheckRun.fromJson(Map<String, dynamic> json) {
    return QualityCheckRun(
      id: json['id'] as String,
      scope: json['scope'] as String,
      audiobookIds: (json['audiobook_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      status: json['status'] as String,
      totalItems: json['total_items'] as int? ?? 0,
      checkedItems: json['checked_items'] as int? ?? 0,
      issuesFound: json['issues_found'] as int? ?? 0,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      triggeredBy: json['triggered_by'] as String?,
    );
  }

  /// Progress percentage (0-100)
  double get progress {
    if (totalItems == 0) return 0;
    return (checkedItems / totalItems) * 100;
  }

  /// Check if running
  bool get isRunning => status == 'running';

  /// Check if completed
  bool get isCompleted => status == 'completed';

  /// Duration of the run
  Duration? get duration {
    if (completedAt == null) return null;
    return completedAt!.difference(startedAt);
  }
}

/// Quality stats summary
class QualityStats {
  final int totalIssues;
  final int openIssues;
  final int resolvedIssues;
  final int ignoredIssues;
  final Map<QualitySeverity, int> bySeverity;
  final Map<QualityIssueType, int> byType;

  const QualityStats({
    this.totalIssues = 0,
    this.openIssues = 0,
    this.resolvedIssues = 0,
    this.ignoredIssues = 0,
    this.bySeverity = const {},
    this.byType = const {},
  });

  factory QualityStats.empty() => const QualityStats();
}
