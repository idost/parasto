import 'package:flutter/material.dart';
import 'package:myna/models/audit_log.dart';
import 'package:myna/models/audit_log_presentation.dart';
import 'package:myna/theme/app_theme.dart';

/// Widget to display a single audit log entry
class AuditLogItem extends StatelessWidget {
  final AuditLog log;
  final VoidCallback? onTap;
  final bool showDetails;

  const AuditLogItem({
    required this.log,
    this.onTap,
    this.showDetails = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Action icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: log.actionColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      log.actionIcon,
                      color: log.actionColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action and entity info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Action badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: log.actionColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.actionLabel,
                                style: TextStyle(
                                  color: log.actionColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Entity type
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  log.entityTypeIcon,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  log.entityTypeLabel,
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Description
                        Text(
                          log.readableDescription,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Time
                  Text(
                    log.timeAgo,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              // Actor info
              if (log.actorEmail != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.actorEmail!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (log.actorRole != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getRoleLabel(log.actorRole!),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Changed fields preview (if showing details)
              if (showDetails && log.hasChanges) ...[
                const SizedBox(height: 12),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 12),
                _buildChangedFieldsPreview(),
              ],

              // Entity ID
              if (showDetails) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'شناسه: ',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      log.entityId,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangedFieldsPreview() {
    final fields = log.changedFields ?? [];
    final displayFields = fields.take(3).toList();
    final remaining = fields.length - 3;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        const Text(
          'تغییرات:',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
        ...displayFields.map((field) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _getFieldLabel(field),
            style: const TextStyle(
              color: AppColors.info,
              fontSize: 10,
            ),
          ),
        )),
        if (remaining > 0)
          Text(
            '+$remaining دیگر',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدیر';
      case 'narrator':
        return 'گوینده';
      case 'listener':
        return 'شنونده';
      default:
        return role;
    }
  }

  String _getFieldLabel(String field) {
    final labels = {
      'title_fa': 'عنوان',
      'title_en': 'عنوان انگلیسی',
      'description_fa': 'توضیحات',
      'status': 'وضعیت',
      'is_featured': 'ویژه',
      'is_free': 'رایگان',
      'price_toman': 'قیمت',
      'category_id': 'دسته‌بندی',
      'role': 'نقش',
      'is_disabled': 'غیرفعال',
      'display_name': 'نام',
    };
    return labels[field] ?? field;
  }
}

/// Compact version of audit log item for lists
class AuditLogItemCompact extends StatelessWidget {
  final AuditLog log;
  final VoidCallback? onTap;

  const AuditLogItemCompact({
    required this.log,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Action icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: log.actionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                log.actionIcon,
                color: log.actionColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),

            // Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.readableDescription,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.timeAgo,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Entity type icon
            Icon(
              log.entityTypeIcon,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
