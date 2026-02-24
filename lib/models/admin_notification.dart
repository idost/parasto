/// Types of admin notifications
enum NotificationType {
  newContentSubmitted,
  narratorRequest,
  supportTicket,
  contentApproved,
  contentRejected,
  newUserSignup,
  purchaseCompleted,
  reviewPosted,
  systemAlert,
}

/// Represents a notification for admin users
class AdminNotification {
  final String id;
  final String adminId;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const AdminNotification({
    required this.id,
    required this.adminId,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      type: _parseType(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'type': _typeToString(type),
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  AdminNotification copyWith({
    String? id,
    String? adminId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return AdminNotification(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  static NotificationType _parseType(String type) {
    switch (type) {
      case 'new_content_submitted':
        return NotificationType.newContentSubmitted;
      case 'narrator_request':
        return NotificationType.narratorRequest;
      case 'support_ticket':
        return NotificationType.supportTicket;
      case 'content_approved':
        return NotificationType.contentApproved;
      case 'content_rejected':
        return NotificationType.contentRejected;
      case 'new_user_signup':
        return NotificationType.newUserSignup;
      case 'purchase_completed':
        return NotificationType.purchaseCompleted;
      case 'review_posted':
        return NotificationType.reviewPosted;
      case 'system_alert':
        return NotificationType.systemAlert;
      default:
        return NotificationType.systemAlert;
    }
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.newContentSubmitted:
        return 'new_content_submitted';
      case NotificationType.narratorRequest:
        return 'narrator_request';
      case NotificationType.supportTicket:
        return 'support_ticket';
      case NotificationType.contentApproved:
        return 'content_approved';
      case NotificationType.contentRejected:
        return 'content_rejected';
      case NotificationType.newUserSignup:
        return 'new_user_signup';
      case NotificationType.purchaseCompleted:
        return 'purchase_completed';
      case NotificationType.reviewPosted:
        return 'review_posted';
      case NotificationType.systemAlert:
        return 'system_alert';
    }
  }

  /// Navigation route based on type
  String? get route {
    switch (type) {
      case NotificationType.newContentSubmitted:
        final audiobookId = data['audiobook_id'];
        if (audiobookId != null) {
          return '/admin/audiobooks/$audiobookId';
        }
        return '/admin/approval-queue';
      case NotificationType.narratorRequest:
        final requestId = data['request_id'];
        if (requestId != null) {
          return '/admin/users/narrator-requests/$requestId';
        }
        return '/admin/users/narrator-requests';
      case NotificationType.supportTicket:
        final ticketId = data['ticket_id'];
        if (ticketId != null) {
          return '/admin/support/$ticketId';
        }
        return '/admin/support';
      case NotificationType.newUserSignup:
        final userId = data['user_id'];
        if (userId != null) {
          return '/admin/users/$userId';
        }
        return '/admin/users/listeners';
      case NotificationType.purchaseCompleted:
        return '/admin/analytics';
      case NotificationType.reviewPosted:
        return '/admin/reviews';
      case NotificationType.contentApproved:
      case NotificationType.contentRejected:
        final audiobookId = data['audiobook_id'];
        if (audiobookId != null) {
          return '/admin/audiobooks/$audiobookId';
        }
        return '/admin/books';
      case NotificationType.systemAlert:
        return null;
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
}

/// Notification preferences for an admin user
class NotificationPreferences {
  final String id;
  final String adminId;

  // In-app notifications
  final bool inAppNewContent;
  final bool inAppNarratorRequests;
  final bool inAppSupportTickets;
  final bool inAppNewUsers;
  final bool inAppPurchases;
  final bool inAppReviews;

  // Email notifications
  final bool emailDailySummary;
  final bool emailCriticalAlerts;
  final bool emailWeeklyReport;

  // Push notifications
  final bool pushEnabled;

  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.id,
    required this.adminId,
    this.inAppNewContent = true,
    this.inAppNarratorRequests = true,
    this.inAppSupportTickets = true,
    this.inAppNewUsers = true,
    this.inAppPurchases = true,
    this.inAppReviews = true,
    this.emailDailySummary = true,
    this.emailCriticalAlerts = true,
    this.emailWeeklyReport = false,
    this.pushEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      inAppNewContent: json['in_app_new_content'] as bool? ?? true,
      inAppNarratorRequests: json['in_app_narrator_requests'] as bool? ?? true,
      inAppSupportTickets: json['in_app_support_tickets'] as bool? ?? true,
      inAppNewUsers: json['in_app_new_users'] as bool? ?? true,
      inAppPurchases: json['in_app_purchases'] as bool? ?? true,
      inAppReviews: json['in_app_reviews'] as bool? ?? true,
      emailDailySummary: json['email_daily_summary'] as bool? ?? true,
      emailCriticalAlerts: json['email_critical_alerts'] as bool? ?? true,
      emailWeeklyReport: json['email_weekly_report'] as bool? ?? false,
      pushEnabled: json['push_enabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'in_app_new_content': inAppNewContent,
      'in_app_narrator_requests': inAppNarratorRequests,
      'in_app_support_tickets': inAppSupportTickets,
      'in_app_new_users': inAppNewUsers,
      'in_app_purchases': inAppPurchases,
      'in_app_reviews': inAppReviews,
      'email_daily_summary': emailDailySummary,
      'email_critical_alerts': emailCriticalAlerts,
      'email_weekly_report': emailWeeklyReport,
      'push_enabled': pushEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  NotificationPreferences copyWith({
    bool? inAppNewContent,
    bool? inAppNarratorRequests,
    bool? inAppSupportTickets,
    bool? inAppNewUsers,
    bool? inAppPurchases,
    bool? inAppReviews,
    bool? emailDailySummary,
    bool? emailCriticalAlerts,
    bool? emailWeeklyReport,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      id: id,
      adminId: adminId,
      inAppNewContent: inAppNewContent ?? this.inAppNewContent,
      inAppNarratorRequests: inAppNarratorRequests ?? this.inAppNarratorRequests,
      inAppSupportTickets: inAppSupportTickets ?? this.inAppSupportTickets,
      inAppNewUsers: inAppNewUsers ?? this.inAppNewUsers,
      inAppPurchases: inAppPurchases ?? this.inAppPurchases,
      inAppReviews: inAppReviews ?? this.inAppReviews,
      emailDailySummary: emailDailySummary ?? this.emailDailySummary,
      emailCriticalAlerts: emailCriticalAlerts ?? this.emailCriticalAlerts,
      emailWeeklyReport: emailWeeklyReport ?? this.emailWeeklyReport,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Create default preferences for a new admin
  factory NotificationPreferences.defaults(String adminId) {
    final now = DateTime.now();
    return NotificationPreferences(
      id: '',
      adminId: adminId,
      createdAt: now,
      updatedAt: now,
    );
  }
}
