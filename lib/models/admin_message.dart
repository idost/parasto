/// Message type enum
enum MessageType {
  direct,
  announcement,
  system,
}

/// Message priority enum
enum MessagePriority {
  low,
  normal,
  high,
  urgent,
}

/// Message status enum
enum MessageStatus {
  draft,
  scheduled,
  sent,
  failed,
}

/// Recipient segment for bulk messages
enum RecipientSegment {
  allNarrators,
  allListeners,
  allUsers,
  custom,
}

/// Admin message model
class AdminMessage {
  final String id;
  final String? senderId;
  final String? senderEmail;
  final String? recipientId;
  final RecipientSegment? recipientSegment;
  final String subject;
  final String body;
  final String? bodyHtml;
  final MessageType type;
  final MessagePriority priority;
  final MessageStatus status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const AdminMessage({
    required this.id,
    this.senderId,
    this.senderEmail,
    this.recipientId,
    this.recipientSegment,
    required this.subject,
    required this.body,
    this.bodyHtml,
    this.type = MessageType.direct,
    this.priority = MessagePriority.normal,
    this.status = MessageStatus.sent,
    this.scheduledAt,
    this.sentAt,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String?,
      senderEmail: json['sender_email'] as String?,
      recipientId: json['recipient_id'] as String?,
      recipientSegment: _parseSegment(json['recipient_segment'] as String?),
      subject: json['subject'] as String,
      body: json['body'] as String,
      bodyHtml: json['body_html'] as String?,
      type: _parseType(json['type'] as String?),
      priority: _parsePriority(json['priority'] as String?),
      status: _parseStatus(json['status'] as String?),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'recipient_segment': recipientSegment?.name,
      'subject': subject,
      'body': body,
      'body_html': bodyHtml,
      'type': type.name,
      'priority': priority.name,
      'status': status.name,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ============================================================================
  // DISPLAY HELPERS
  // ============================================================================

  /// Priority label
  String get priorityLabel {
    switch (priority) {
      case MessagePriority.low:
        return 'کم';
      case MessagePriority.normal:
        return 'عادی';
      case MessagePriority.high:
        return 'بالا';
      case MessagePriority.urgent:
        return 'فوری';
    }
  }

  /// Type label
  String get typeLabel {
    switch (type) {
      case MessageType.direct:
        return 'پیام مستقیم';
      case MessageType.announcement:
        return 'اطلاعیه';
      case MessageType.system:
        return 'سیستمی';
    }
  }

  /// Status label
  String get statusLabel {
    switch (status) {
      case MessageStatus.draft:
        return 'پیش‌نویس';
      case MessageStatus.scheduled:
        return 'زمان‌بندی شده';
      case MessageStatus.sent:
        return 'ارسال شده';
      case MessageStatus.failed:
        return 'ناموفق';
    }
  }

  /// Segment label
  String get segmentLabel {
    if (recipientSegment == null) return 'کاربر مشخص';
    switch (recipientSegment!) {
      case RecipientSegment.allNarrators:
        return 'همه گویندگان';
      case RecipientSegment.allListeners:
        return 'همه شنوندگان';
      case RecipientSegment.allUsers:
        return 'همه کاربران';
      case RecipientSegment.custom:
        return 'سفارشی';
    }
  }

  // ============================================================================
  // PARSERS
  // ============================================================================

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'direct':
        return MessageType.direct;
      case 'announcement':
        return MessageType.announcement;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.direct;
    }
  }

  static MessagePriority _parsePriority(String? priority) {
    switch (priority) {
      case 'low':
        return MessagePriority.low;
      case 'normal':
        return MessagePriority.normal;
      case 'high':
        return MessagePriority.high;
      case 'urgent':
        return MessagePriority.urgent;
      default:
        return MessagePriority.normal;
    }
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'draft':
        return MessageStatus.draft;
      case 'scheduled':
        return MessageStatus.scheduled;
      case 'sent':
        return MessageStatus.sent;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  static RecipientSegment? _parseSegment(String? segment) {
    if (segment == null) return null;
    switch (segment) {
      case 'allNarrators':
      case 'all_narrators':
        return RecipientSegment.allNarrators;
      case 'allListeners':
      case 'all_listeners':
        return RecipientSegment.allListeners;
      case 'allUsers':
      case 'all_users':
        return RecipientSegment.allUsers;
      case 'custom':
        return RecipientSegment.custom;
      default:
        return null;
    }
  }
}

/// Message template model
class MessageTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final String? bodyHtml;
  final List<String> variables;
  final String category;
  final String? createdBy;
  final DateTime createdAt;

  const MessageTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.bodyHtml,
    this.variables = const [],
    this.category = 'general',
    this.createdBy,
    required this.createdAt,
  });

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      subject: json['subject'] as String,
      body: json['body'] as String,
      bodyHtml: json['body_html'] as String?,
      variables: (json['variables'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String? ?? 'general',
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'body': body,
      'body_html': bodyHtml,
      'variables': variables,
      'category': category,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Apply template with variables
  String applyVariables(Map<String, String> values) {
    var result = body;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// Apply template subject with variables
  String applySubjectVariables(Map<String, String> values) {
    var result = subject;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// Category label
  String get categoryLabel {
    switch (category) {
      case 'narrator':
        return 'گوینده';
      case 'content':
        return 'محتوا';
      case 'payment':
        return 'مالی';
      case 'support':
        return 'پشتیبانی';
      default:
        return 'عمومی';
    }
  }
}

/// Default templates
class DefaultTemplates {
  static const List<Map<String, dynamic>> templates = [
    {
      'name': 'خوش‌آمدگویی گوینده جدید',
      'category': 'narrator',
      'subject': 'به پاراستو خوش آمدید!',
      'body': '''سلام {{name}} عزیز،

از پیوستن شما به خانواده گویندگان پاراستو خوشحالیم!

برای شروع کار، می‌توانید:
۱. پروفایل خود را تکمیل کنید
۲. اولین کتاب صوتی خود را آپلود کنید
۳. با تیم پشتیبانی در ارتباط باشید

با آرزوی موفقیت،
تیم پاراستو''',
      'variables': ['name'],
    },
    {
      'name': 'رد محتوا',
      'category': 'content',
      'subject': 'محتوای شما نیاز به بازبینی دارد',
      'body': '''{{name}} عزیز،

محتوای «{{content_title}}» پس از بررسی، نیاز به اصلاحات دارد.

دلیل: {{rejection_reason}}

لطفاً پس از اصلاح، مجدداً ارسال کنید.

با تشکر،
تیم بررسی محتوا''',
      'variables': ['name', 'content_title', 'rejection_reason'],
    },
    {
      'name': 'تأیید محتوا',
      'category': 'content',
      'subject': 'محتوای شما تأیید شد!',
      'body': '''{{name}} عزیز،

خبر خوب! محتوای «{{content_title}}» با موفقیت تأیید و منتشر شد.

می‌توانید از طریق لینک زیر آن را مشاهده کنید:
{{content_link}}

با تشکر،
تیم پاراستو''',
      'variables': ['name', 'content_title', 'content_link'],
    },
    {
      'name': 'اطلاع‌رسانی پرداخت',
      'category': 'payment',
      'subject': 'پرداخت جدید',
      'body': '''{{name}} عزیز،

مبلغ {{amount}} تومان بابت فروش محتوای «{{content_title}}» به حساب شما واریز شد.

موجودی فعلی: {{balance}} تومان

با تشکر،
تیم مالی پاراستو''',
      'variables': ['name', 'amount', 'content_title', 'balance'],
    },
  ];
}
