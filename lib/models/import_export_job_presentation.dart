import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/import_export_job.dart';

/// Presentation extensions for [ImportJob] — UI-specific getters that return
/// [Color], [IconData], or reference [AppColors].
extension ImportJobPresentation on ImportJob {
  /// Status color
  Color get statusColor {
    switch (status) {
      case ImportJobStatus.pending:
        return AppColors.textTertiary;
      case ImportJobStatus.validating:
      case ImportJobStatus.processing:
        return AppColors.primary;
      case ImportJobStatus.completed:
        return AppColors.success;
      case ImportJobStatus.failed:
        return AppColors.error;
      case ImportJobStatus.cancelled:
        return AppColors.textTertiary;
    }
  }

  /// Status label (in Persian)
  String get statusLabel {
    switch (status) {
      case ImportJobStatus.pending:
        return 'در انتظار';
      case ImportJobStatus.validating:
        return 'در حال اعتبارسنجی';
      case ImportJobStatus.processing:
        return 'در حال پردازش';
      case ImportJobStatus.completed:
        return 'تکمیل شده';
      case ImportJobStatus.failed:
        return 'ناموفق';
      case ImportJobStatus.cancelled:
        return 'لغو شده';
    }
  }

  /// Type label (in Persian)
  String get typeLabel => _getTypeLabel(type);
}

/// Presentation extensions for [ExportJob] — UI-specific getters that return
/// [Color], [IconData], or reference [AppColors].
extension ExportJobPresentation on ExportJob {
  /// Status color
  Color get statusColor {
    switch (status) {
      case ExportJobStatus.pending:
        return AppColors.textTertiary;
      case ExportJobStatus.processing:
        return AppColors.primary;
      case ExportJobStatus.completed:
        return AppColors.success;
      case ExportJobStatus.failed:
        return AppColors.error;
      case ExportJobStatus.expired:
        return AppColors.warning;
    }
  }

  /// Status label (in Persian)
  String get statusLabel {
    switch (status) {
      case ExportJobStatus.pending:
        return 'در انتظار';
      case ExportJobStatus.processing:
        return 'در حال پردازش';
      case ExportJobStatus.completed:
        return 'آماده دانلود';
      case ExportJobStatus.failed:
        return 'ناموفق';
      case ExportJobStatus.expired:
        return 'منقضی شده';
    }
  }

  /// Type label (in Persian)
  String get typeLabel => _getTypeLabel(type);

  /// Format label
  String get formatLabel {
    switch (format) {
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.xlsx:
        return 'Excel';
      case ExportFormat.json:
        return 'JSON';
    }
  }
}

/// Get type label in Persian
String _getTypeLabel(ImportExportType type) {
  switch (type) {
    case ImportExportType.audiobooks:
      return 'کتاب‌های صوتی';
    case ImportExportType.creators:
      return 'سازندگان';
    case ImportExportType.users:
      return 'کاربران';
    case ImportExportType.categories:
      return 'دسته‌بندی‌ها';
    case ImportExportType.analytics:
      return 'آنالیتیکس';
    case ImportExportType.auditLogs:
      return 'گزارش فعالیت';
  }
}
