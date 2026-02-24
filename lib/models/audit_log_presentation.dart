import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

import 'package:myna/models/audit_log.dart';

/// UI presentation extensions for [AuditLog].
extension AuditLogPresentation on AuditLog {
  /// Color for the action
  Color get actionColor {
    switch (action) {
      case AuditAction.create:
        return AppColors.success;
      case AuditAction.delete:
        return AppColors.error;
      case AuditAction.approve:
        return AppColors.success;
      case AuditAction.reject:
        return AppColors.error;
      case AuditAction.ban:
        return AppColors.error;
      case AuditAction.unban:
        return AppColors.success;
      case AuditAction.feature:
        return AppColors.primary;
      case AuditAction.unfeature:
        return AppColors.warning;
      case AuditAction.roleChange:
        return AppColors.info;
      case AuditAction.login:
        return AppColors.info;
      case AuditAction.logout:
        return AppColors.textTertiary;
      case AuditAction.export:
        return AppColors.secondary;
      case AuditAction.import:
        return AppColors.secondary;
      case AuditAction.update:
        return AppColors.primary;
      case AuditAction.bulkAction:
        return AppColors.info;
    }
  }

  /// Icon for the action
  IconData get actionIcon {
    switch (action) {
      case AuditAction.create:
        return Icons.add_circle_rounded;
      case AuditAction.update:
        return Icons.edit_rounded;
      case AuditAction.delete:
        return Icons.delete_rounded;
      case AuditAction.approve:
        return Icons.check_circle_rounded;
      case AuditAction.reject:
        return Icons.cancel_rounded;
      case AuditAction.feature:
        return Icons.star_rounded;
      case AuditAction.unfeature:
        return Icons.star_border_rounded;
      case AuditAction.ban:
        return Icons.block_rounded;
      case AuditAction.unban:
        return Icons.check_rounded;
      case AuditAction.roleChange:
        return Icons.swap_horiz_rounded;
      case AuditAction.login:
        return Icons.login_rounded;
      case AuditAction.logout:
        return Icons.logout_rounded;
      case AuditAction.export:
        return Icons.download_rounded;
      case AuditAction.import:
        return Icons.upload_rounded;
      case AuditAction.bulkAction:
        return Icons.list_alt_rounded;
    }
  }

  /// Icon for the entity type
  IconData get entityTypeIcon {
    switch (entityType) {
      case AuditEntityType.audiobook:
        return Icons.library_music_rounded;
      case AuditEntityType.user:
        return Icons.person_rounded;
      case AuditEntityType.creator:
        return Icons.record_voice_over_rounded;
      case AuditEntityType.category:
        return Icons.category_rounded;
      case AuditEntityType.ticket:
        return Icons.support_agent_rounded;
      case AuditEntityType.narratorRequest:
        return Icons.mic_rounded;
      case AuditEntityType.promotion:
        return Icons.local_offer_rounded;
      case AuditEntityType.schedule:
        return Icons.schedule_rounded;
      case AuditEntityType.settings:
        return Icons.settings_rounded;
    }
  }
}
