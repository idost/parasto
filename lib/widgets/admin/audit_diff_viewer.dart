import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/audit_service.dart';

/// Widget to display the diff between old and new values in an audit log
class AuditDiffViewer extends StatelessWidget {
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final List<String>? changedFields;

  const AuditDiffViewer({
    this.oldValues,
    this.newValues,
    this.changedFields,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (changedFields == null || changedFields!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            SizedBox(width: 8),
            Text(
              'بدون تغییر',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: changedFields!.map((field) {
        final oldValue = oldValues?[field];
        final newValue = newValues?[field];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field name
              Text(
                AuditService.getFieldLabel(field),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Old and new values
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Old value
                  Expanded(
                    child: _buildValueBox(
                      label: 'قبل',
                      value: oldValue,
                      color: AppColors.error,
                      isOld: true,
                    ),
                  ),

                  // Arrow
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),

                  // New value
                  Expanded(
                    child: _buildValueBox(
                      label: 'بعد',
                      value: newValue,
                      color: AppColors.success,
                      isOld: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValueBox({
    required String label,
    required dynamic value,
    required Color color,
    required bool isOld,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            AuditService.formatValue(value),
            style: TextStyle(
              color: isOld ? color : AppColors.textPrimary,
              fontSize: 13,
              decoration: isOld ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A simpler inline diff viewer for compact displays
class AuditDiffViewerInline extends StatelessWidget {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  const AuditDiffViewerInline({
    required this.field,
    this.oldValue,
    this.newValue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${AuditService.getFieldLabel(field)}: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Flexible(
          child: Text(
            AuditService.formatValue(oldValue),
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: AppColors.textTertiary,
          ),
        ),
        Flexible(
          child: Text(
            AuditService.formatValue(newValue),
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Full detail view of an audit log with all changes
class AuditLogDetailView extends StatelessWidget {
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final List<String>? changedFields;
  final String? description;
  final DateTime createdAt;
  final String? actorEmail;
  final String? entityId;

  const AuditLogDetailView({
    this.oldValues,
    this.newValues,
    this.changedFields,
    this.description,
    required this.createdAt,
    this.actorEmail,
    this.entityId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description if available
          if (description != null && description!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Metadata
          _buildMetadataRow(
            icon: Icons.person_outline_rounded,
            label: 'کاربر',
            value: actorEmail ?? 'سیستم',
          ),
          const SizedBox(height: 8),
          _buildMetadataRow(
            icon: Icons.access_time_rounded,
            label: 'زمان',
            value: _formatDateTime(createdAt),
          ),
          if (entityId != null) ...[
            const SizedBox(height: 8),
            _buildMetadataRow(
              icon: Icons.tag_rounded,
              label: 'شناسه',
              value: entityId!,
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 16),

          // Changes header
          const Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'تغییرات',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Diff viewer
          AuditDiffViewer(
            oldValues: oldValues,
            newValues: newValues,
            changedFields: changedFields,
          ),

          // Raw data section (for debugging/advanced view)
          if (oldValues != null || newValues != null) ...[
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'داده‌های خام',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              children: [
                if (oldValues != null)
                  _buildRawDataSection('قبل', oldValues!),
                if (newValues != null)
                  _buildRawDataSection('بعد', newValues!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRawDataSection(String title, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.toString(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
