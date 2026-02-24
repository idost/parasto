/// Types of data that can be imported/exported
enum ImportExportType {
  audiobooks,
  creators,
  users,
  categories,
  analytics,
  auditLogs,
}

/// Status of an import job
enum ImportJobStatus {
  pending,
  validating,
  processing,
  completed,
  failed,
  cancelled,
}

/// Status of an export job
enum ExportJobStatus {
  pending,
  processing,
  completed,
  failed,
  expired,
}

/// Export format
enum ExportFormat {
  csv,
  xlsx,
  json,
}

/// Represents an import job
class ImportJob {
  final String id;
  final String? adminId;
  final ImportExportType type;
  final String fileName;
  final String filePath;
  final ImportJobStatus status;
  final int totalRows;
  final int processedRows;
  final int successfulRows;
  final int failedRows;
  final List<ImportError> errors;
  final Map<String, dynamic>? resultSummary;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const ImportJob({
    required this.id,
    this.adminId,
    required this.type,
    required this.fileName,
    required this.filePath,
    this.status = ImportJobStatus.pending,
    this.totalRows = 0,
    this.processedRows = 0,
    this.successfulRows = 0,
    this.failedRows = 0,
    this.errors = const [],
    this.resultSummary,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory ImportJob.fromJson(Map<String, dynamic> json) {
    final errorLog = json['error_log'] as List<dynamic>? ?? [];

    return ImportJob(
      id: json['id'] as String,
      adminId: json['admin_id'] as String?,
      type: _parseType(json['type'] as String),
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      status: _parseImportStatus(json['status'] as String? ?? 'pending'),
      totalRows: json['total_rows'] as int? ?? 0,
      processedRows: json['processed_rows'] as int? ?? 0,
      successfulRows: json['successful_rows'] as int? ?? 0,
      failedRows: json['failed_rows'] as int? ?? 0,
      errors: errorLog.map((e) => ImportError.fromJson(e as Map<String, dynamic>)).toList(),
      resultSummary: json['result_summary'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Progress percentage (0-100)
  double get progress {
    if (totalRows == 0) return 0;
    return (processedRows / totalRows) * 100;
  }

  /// Check if the job is running
  bool get isRunning =>
      status == ImportJobStatus.validating || status == ImportJobStatus.processing;

  /// Check if the job is completed
  bool get isCompleted => status == ImportJobStatus.completed;

  /// Check if the job failed
  bool get isFailed => status == ImportJobStatus.failed;

  /// Duration of the job
  Duration? get duration {
    if (completedAt == null || startedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  static ImportExportType _parseType(String type) {
    switch (type) {
      case 'audiobooks':
        return ImportExportType.audiobooks;
      case 'creators':
        return ImportExportType.creators;
      case 'users':
        return ImportExportType.users;
      case 'categories':
        return ImportExportType.categories;
      case 'analytics':
        return ImportExportType.analytics;
      case 'audit_logs':
        return ImportExportType.auditLogs;
      default:
        return ImportExportType.audiobooks;
    }
  }

  static ImportJobStatus _parseImportStatus(String status) {
    switch (status) {
      case 'pending':
        return ImportJobStatus.pending;
      case 'validating':
        return ImportJobStatus.validating;
      case 'processing':
        return ImportJobStatus.processing;
      case 'completed':
        return ImportJobStatus.completed;
      case 'failed':
        return ImportJobStatus.failed;
      case 'cancelled':
        return ImportJobStatus.cancelled;
      default:
        return ImportJobStatus.pending;
    }
  }
}

/// Represents an error during import
class ImportError {
  final int row;
  final List<String> errors;
  final Map<String, dynamic>? data;

  const ImportError({
    required this.row,
    required this.errors,
    this.data,
  });

  factory ImportError.fromJson(Map<String, dynamic> json) {
    return ImportError(
      row: json['row'] as int,
      errors: (json['errors'] as List<dynamic>).map((e) => e.toString()).toList(),
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Represents an export job
class ExportJob {
  final String id;
  final String? adminId;
  final ImportExportType type;
  final ExportFormat format;
  final Map<String, dynamic> filters;
  final ExportJobStatus status;
  final String? filePath;
  final int? fileSize;
  final int? rowCount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  const ExportJob({
    required this.id,
    this.adminId,
    required this.type,
    this.format = ExportFormat.csv,
    this.filters = const {},
    this.status = ExportJobStatus.pending,
    this.filePath,
    this.fileSize,
    this.rowCount,
    required this.createdAt,
    this.completedAt,
    this.expiresAt,
  });

  factory ExportJob.fromJson(Map<String, dynamic> json) {
    return ExportJob(
      id: json['id'] as String,
      adminId: json['admin_id'] as String?,
      type: ImportJob._parseType(json['type'] as String),
      format: _parseFormat(json['format'] as String? ?? 'csv'),
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      status: _parseExportStatus(json['status'] as String? ?? 'pending'),
      filePath: json['file_path'] as String?,
      fileSize: json['file_size'] as int?,
      rowCount: json['row_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  /// Check if the job is running
  bool get isRunning => status == ExportJobStatus.processing;

  /// Check if the job is completed
  bool get isCompleted => status == ExportJobStatus.completed;

  /// Check if the download link is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// File size in human readable format
  String get fileSizeLabel {
    if (fileSize == null) return '-';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static ExportFormat _parseFormat(String format) {
    switch (format) {
      case 'csv':
        return ExportFormat.csv;
      case 'xlsx':
        return ExportFormat.xlsx;
      case 'json':
        return ExportFormat.json;
      default:
        return ExportFormat.csv;
    }
  }

  static ExportJobStatus _parseExportStatus(String status) {
    switch (status) {
      case 'pending':
        return ExportJobStatus.pending;
      case 'processing':
        return ExportJobStatus.processing;
      case 'completed':
        return ExportJobStatus.completed;
      case 'failed':
        return ExportJobStatus.failed;
      case 'expired':
        return ExportJobStatus.expired;
      default:
        return ExportJobStatus.pending;
    }
  }
}

/// Column mapping for import
class ColumnMapping {
  final String sourceColumn;
  final String targetField;
  final bool isRequired;

  const ColumnMapping({
    required this.sourceColumn,
    required this.targetField,
    this.isRequired = false,
  });
}

/// Export template definition
class ExportTemplate {
  final ImportExportType type;
  final Map<String, String> fields; // field_name -> Persian label

  const ExportTemplate({
    required this.type,
    required this.fields,
  });

  static const audiobooks = ExportTemplate(
    type: ImportExportType.audiobooks,
    fields: {
      'id': 'شناسه',
      'title_fa': 'عنوان فارسی',
      'title_en': 'عنوان انگلیسی',
      'is_music': 'نوع',
      'status': 'وضعیت',
      'category_name': 'دسته‌بندی',
      'narrator_name': 'گوینده',
      'price_toman': 'قیمت',
      'play_count': 'تعداد پخش',
      'purchase_count': 'تعداد خرید',
      'created_at': 'تاریخ ایجاد',
    },
  );

  static const users = ExportTemplate(
    type: ImportExportType.users,
    fields: {
      'id': 'شناسه',
      'display_name': 'نام',
      'email': 'ایمیل',
      'role': 'نقش',
      'is_disabled': 'غیرفعال',
      'created_at': 'تاریخ ثبت‌نام',
    },
  );

  static const creators = ExportTemplate(
    type: ImportExportType.creators,
    fields: {
      'id': 'شناسه',
      'display_name': 'نام',
      'display_name_latin': 'نام لاتین',
      'creator_type': 'نوع',
      'audiobook_count': 'تعداد محتوا',
      'created_at': 'تاریخ ایجاد',
    },
  );
}
