/// Types of audit actions tracked in the system
enum AuditAction {
  create,
  update,
  delete,
  approve,
  reject,
  feature,
  unfeature,
  ban,
  unban,
  roleChange,
  login,
  logout,
  export,
  import,
  bulkAction,
}

/// Types of entities that can be audited
enum AuditEntityType {
  audiobook,
  user,
  creator,
  category,
  ticket,
  narratorRequest,
  promotion,
  schedule,
  settings,
}

/// Represents a single audit log entry
class AuditLog {
  final String id;
  final String? actorId;
  final String? actorEmail;
  final String? actorRole;
  final AuditAction action;
  final AuditEntityType entityType;
  final String entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final List<String>? changedFields;
  final String? description;
  final String? ipAddress;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    this.actorId,
    this.actorEmail,
    this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValues,
    this.newValues,
    this.changedFields,
    this.description,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      actorId: json['actor_id'] as String?,
      actorEmail: json['actor_email'] as String?,
      actorRole: json['actor_role'] as String?,
      action: _parseAction(json['action'] as String),
      entityType: _parseEntityType(json['entity_type'] as String),
      entityId: json['entity_id'] as String,
      oldValues: json['old_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      changedFields: json['changed_fields'] != null
          ? List<String>.from(json['changed_fields'] as List)
          : null,
      description: json['description'] as String?,
      ipAddress: json['ip_address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actor_id': actorId,
      'actor_email': actorEmail,
      'actor_role': actorRole,
      'action': action.name,
      'entity_type': _entityTypeToString(entityType),
      'entity_id': entityId,
      'old_values': oldValues,
      'new_values': newValues,
      'changed_fields': changedFields,
      'description': description,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static AuditAction _parseAction(String action) {
    switch (action) {
      case 'create':
        return AuditAction.create;
      case 'update':
        return AuditAction.update;
      case 'delete':
        return AuditAction.delete;
      case 'approve':
        return AuditAction.approve;
      case 'reject':
        return AuditAction.reject;
      case 'feature':
        return AuditAction.feature;
      case 'unfeature':
        return AuditAction.unfeature;
      case 'ban':
        return AuditAction.ban;
      case 'unban':
        return AuditAction.unban;
      case 'role_change':
        return AuditAction.roleChange;
      case 'login':
        return AuditAction.login;
      case 'logout':
        return AuditAction.logout;
      case 'export':
        return AuditAction.export;
      case 'import':
        return AuditAction.import;
      case 'bulk_action':
        return AuditAction.bulkAction;
      default:
        return AuditAction.update;
    }
  }

  static AuditEntityType _parseEntityType(String type) {
    switch (type) {
      case 'audiobook':
      case 'audiobooks':
        return AuditEntityType.audiobook;
      case 'user':
      case 'profiles':
        return AuditEntityType.user;
      case 'creator':
      case 'creators':
        return AuditEntityType.creator;
      case 'category':
      case 'categories':
        return AuditEntityType.category;
      case 'ticket':
      case 'support_tickets':
        return AuditEntityType.ticket;
      case 'narrator_request':
      case 'narrator_requests':
        return AuditEntityType.narratorRequest;
      case 'promotion':
      case 'promotions':
        return AuditEntityType.promotion;
      case 'schedule':
      case 'scheduled_features':
        return AuditEntityType.schedule;
      case 'settings':
      case 'app_settings':
        return AuditEntityType.settings;
      default:
        return AuditEntityType.settings;
    }
  }

  static String _entityTypeToString(AuditEntityType type) {
    switch (type) {
      case AuditEntityType.audiobook:
        return 'audiobook';
      case AuditEntityType.user:
        return 'user';
      case AuditEntityType.creator:
        return 'creator';
      case AuditEntityType.category:
        return 'category';
      case AuditEntityType.ticket:
        return 'ticket';
      case AuditEntityType.narratorRequest:
        return 'narrator_request';
      case AuditEntityType.promotion:
        return 'promotion';
      case AuditEntityType.schedule:
        return 'schedule';
      case AuditEntityType.settings:
        return 'settings';
    }
  }

  // ============================================================================
  // DISPLAY HELPERS
  // ============================================================================

  /// Persian label for the action
  String get actionLabel {
    switch (action) {
      case AuditAction.create:
        return 'ایجاد';
      case AuditAction.update:
        return 'ویرایش';
      case AuditAction.delete:
        return 'حذف';
      case AuditAction.approve:
        return 'تأیید';
      case AuditAction.reject:
        return 'رد';
      case AuditAction.feature:
        return 'ویژه کردن';
      case AuditAction.unfeature:
        return 'حذف از ویژه';
      case AuditAction.ban:
        return 'مسدود کردن';
      case AuditAction.unban:
        return 'رفع مسدودیت';
      case AuditAction.roleChange:
        return 'تغییر نقش';
      case AuditAction.login:
        return 'ورود';
      case AuditAction.logout:
        return 'خروج';
      case AuditAction.export:
        return 'خروجی';
      case AuditAction.import:
        return 'ورودی';
      case AuditAction.bulkAction:
        return 'عملیات گروهی';
    }
  }

  /// Persian label for the entity type
  String get entityTypeLabel {
    switch (entityType) {
      case AuditEntityType.audiobook:
        return 'محتوا';
      case AuditEntityType.user:
        return 'کاربر';
      case AuditEntityType.creator:
        return 'سازنده';
      case AuditEntityType.category:
        return 'دسته‌بندی';
      case AuditEntityType.ticket:
        return 'تیکت';
      case AuditEntityType.narratorRequest:
        return 'درخواست گویندگی';
      case AuditEntityType.promotion:
        return 'تخفیف';
      case AuditEntityType.schedule:
        return 'زمان‌بندی';
      case AuditEntityType.settings:
        return 'تنظیمات';
    }
  }

  /// Human-readable description
  String get readableDescription {
    final actor = actorEmail ?? 'سیستم';
    final entity = entityTypeLabel;

    switch (action) {
      case AuditAction.create:
        return '$actor یک $entity جدید ایجاد کرد';
      case AuditAction.update:
        return '$actor $entity را ویرایش کرد';
      case AuditAction.delete:
        return '$actor $entity را حذف کرد';
      case AuditAction.approve:
        return '$actor $entity را تأیید کرد';
      case AuditAction.reject:
        return '$actor $entity را رد کرد';
      case AuditAction.feature:
        return '$actor $entity را ویژه کرد';
      case AuditAction.unfeature:
        return '$actor $entity را از ویژه حذف کرد';
      case AuditAction.ban:
        return '$actor $entity را مسدود کرد';
      case AuditAction.unban:
        return '$actor مسدودیت $entity را رفع کرد';
      case AuditAction.roleChange:
        return '$actor نقش $entity را تغییر داد';
      case AuditAction.login:
        return '$actor وارد شد';
      case AuditAction.logout:
        return '$actor خارج شد';
      case AuditAction.export:
        return '$actor خروجی گرفت';
      case AuditAction.import:
        return '$actor ورودی انجام داد';
      case AuditAction.bulkAction:
        return '$actor عملیات گروهی انجام داد';
    }
  }

  /// Formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} هفته پیش';
    } else {
      return '${(difference.inDays / 30).floor()} ماه پیش';
    }
  }

  /// Full formatted date
  String get formattedDate {
    return '${createdAt.year}/${createdAt.month}/${createdAt.day} - ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// Check if there are any changed fields to display
  bool get hasChanges => changedFields != null && changedFields!.isNotEmpty;
}

/// Filter options for audit logs
class AuditLogFilter {
  final AuditAction? action;
  final AuditEntityType? entityType;
  final String? actorId;
  final String? entityId;
  final DateTime? fromDate;
  final DateTime? toDate;

  const AuditLogFilter({
    this.action,
    this.entityType,
    this.actorId,
    this.entityId,
    this.fromDate,
    this.toDate,
  });

  AuditLogFilter copyWith({
    AuditAction? action,
    AuditEntityType? entityType,
    String? actorId,
    String? entityId,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearAction = false,
    bool clearEntityType = false,
    bool clearActorId = false,
    bool clearEntityId = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return AuditLogFilter(
      action: clearAction ? null : (action ?? this.action),
      entityType: clearEntityType ? null : (entityType ?? this.entityType),
      actorId: clearActorId ? null : (actorId ?? this.actorId),
      entityId: clearEntityId ? null : (entityId ?? this.entityId),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }

  bool get hasFilters =>
      action != null ||
      entityType != null ||
      actorId != null ||
      entityId != null ||
      fromDate != null ||
      toDate != null;
}
