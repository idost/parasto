import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/quality_issue.dart';

/// UI presentation helpers for [QualityIssue]
extension QualityIssuePresentation on QualityIssue {
  /// Icon for the issue type
  IconData get icon {
    switch (type) {
      case QualityIssueType.audioFormat:
      case QualityIssueType.audioBitrate:
      case QualityIssueType.audioDuration:
        return Icons.audio_file_rounded;
      case QualityIssueType.missingCover:
      case QualityIssueType.lowQualityCover:
      case QualityIssueType.coverDimensions:
        return Icons.image_rounded;
      case QualityIssueType.missingMetadata:
        return Icons.info_outline_rounded;
      case QualityIssueType.duplicateContent:
      case QualityIssueType.duplicateTitle:
        return Icons.copy_rounded;
      case QualityIssueType.profanityDetected:
        return Icons.report_rounded;
      case QualityIssueType.copyrightFlag:
        return Icons.copyright_rounded;
    }
  }

  /// Color based on severity
  Color get color {
    switch (severity) {
      case QualitySeverity.info:
        return AppColors.info;
      case QualitySeverity.warning:
        return AppColors.warning;
      case QualitySeverity.error:
        return AppColors.error;
      case QualitySeverity.critical:
        return const Color(0xFFDC2626); // Darker red
    }
  }

  /// Status color
  Color get statusColor {
    switch (status) {
      case QualityIssueStatus.open:
        return AppColors.warning;
      case QualityIssueStatus.resolved:
        return AppColors.success;
      case QualityIssueStatus.ignored:
        return AppColors.textTertiary;
    }
  }
}
