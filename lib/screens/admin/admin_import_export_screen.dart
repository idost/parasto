import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/import_export_job.dart';
import 'package:myna/models/import_export_job_presentation.dart';
import 'package:myna/providers/import_export_providers.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/widgets/admin/error_state.dart';
import 'package:myna/widgets/admin/loading_state.dart';

/// Admin screen for bulk import/export operations
class AdminImportExportScreen extends ConsumerStatefulWidget {
  const AdminImportExportScreen({super.key});

  @override
  ConsumerState<AdminImportExportScreen> createState() => _AdminImportExportScreenState();
}

class _AdminImportExportScreenState extends ConsumerState<AdminImportExportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            _buildQuickActions(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ExportJobsList(),
                  _ImportJobsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.import_export_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ورود و خروج داده',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'خروجی گرفتن و ورود گروهی داده‌ها',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.download_rounded,
              title: 'خروجی جدید',
              subtitle: 'دانلود داده‌ها به صورت CSV یا Excel',
              color: AppColors.success,
              onTap: () => _showExportDialog(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionCard(
              icon: Icons.upload_rounded,
              title: 'ورود داده',
              subtitle: 'بارگذاری فایل CSV برای ورود گروهی',
              color: AppColors.primary,
              onTap: () => _showImportDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'خروجی‌ها'),
          Tab(text: 'ورودی‌ها'),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => const _ExportDialog(),
    );
  }

  void _showImportDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => const _ImportDialog(),
    );
  }
}

/// Export jobs list
class _ExportJobsList extends ConsumerWidget {
  const _ExportJobsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(exportJobsProvider);

    return jobs.when(
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.download_rounded,
            message: 'هیچ خروجی ثبت نشده',
            subtitle: 'برای شروع، از دکمه "خروجی جدید" استفاده کنید',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final job = list[index];
            return _ExportJobCard(job: job);
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: 'خطا در بارگذاری',
        onRetry: () => ref.invalidate(exportJobsProvider),
      ),
    );
  }
}

/// Import jobs list
class _ImportJobsList extends ConsumerWidget {
  const _ImportJobsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(importJobsProvider);

    return jobs.when(
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.upload_rounded,
            message: 'هیچ ورودی ثبت نشده',
            subtitle: 'برای شروع، از دکمه "ورود داده" استفاده کنید',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final job = list[index];
            return _ImportJobCard(job: job);
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: 'خطا در بارگذاری',
        onRetry: () => ref.invalidate(importJobsProvider),
      ),
    );
  }
}

/// Export job card
class _ExportJobCard extends ConsumerWidget {
  final ExportJob job;

  const _ExportJobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: job.statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description_rounded,
                color: job.statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        job.typeLabel,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          job.formatLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: job.statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          job.statusLabel,
                          style: TextStyle(
                            color: job.statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (job.rowCount != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${job.rowCount} ردیف',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (job.fileSize != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          job.fileSizeLabel,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (job.isCompleted && !job.isExpired && job.filePath != null)
              ElevatedButton.icon(
                onPressed: () => _downloadExport(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('دانلود'),
              )
            else if (job.isRunning)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (job.isExpired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'منقضی شده',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadExport(BuildContext context, WidgetRef ref) async {
    final url = await ref.read(importExportActionsProvider.notifier)
        .getDownloadUrl(job.filePath!);

    if (url != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('دانلود آغاز شد'),
          backgroundColor: AppColors.success,
        ),
      );
      // In a real app, you would open the URL or use a download manager
    }
  }
}

/// Import job card
class _ImportJobCard extends ConsumerWidget {
  final ImportJob job;

  const _ImportJobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: job.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    color: job.statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.fileName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            job.typeLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: job.statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              job.statusLabel,
                              style: TextStyle(
                                color: job.statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (job.isRunning)
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded),
                    color: AppColors.error,
                    onPressed: () {
                      ref.read(importExportActionsProvider.notifier)
                          .cancelImport(job.id);
                    },
                    tooltip: 'لغو',
                  ),
              ],
            ),
            if (job.isRunning || job.isCompleted) ...[
              const SizedBox(height: 12),
              _buildProgressSection(),
            ],
            if (job.errors.isNotEmpty && job.failedRows > 0) ...[
              const SizedBox(height: 12),
              _buildErrorsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${job.processedRows} از ${job.totalRows} ردیف',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              '${job.progress.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: job.progress / 100,
          backgroundColor: AppColors.surfaceLight,
          color: job.statusColor,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatChip('موفق', job.successfulRows, AppColors.success),
            const SizedBox(width: 8),
            _buildStatChip('ناموفق', job.failedRows, AppColors.error),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            count > 0 ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsSection() {
    final displayErrors = job.errors.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
              SizedBox(width: 6),
              Text(
                'خطاها',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...displayErrors.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'ردیف ${error.row}: ${error.errors.join(', ')}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          )),
          if (job.errors.length > 3)
            Text(
              'و ${job.errors.length - 3} خطای دیگر...',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

/// Export dialog
class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog();

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  ImportExportType _selectedType = ImportExportType.audiobooks;
  ExportFormat _selectedFormat = ExportFormat.csv;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: AppColors.success),
            SizedBox(width: 12),
            Text(
              'خروجی جدید',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selection
              const Text(
                'نوع داده',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ImportExportType>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                items: [
                  ImportExportType.audiobooks,
                  ImportExportType.creators,
                  ImportExportType.users,
                ].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Format selection
              const Text(
                'فرمت فایل',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ExportFormat.values.map((format) {
                  final isSelected = _selectedFormat == format;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: ChoiceChip(
                      label: Text(_getFormatLabel(format)),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedFormat = format);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _createExport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('ایجاد خروجی'),
          ),
        ],
      ),
    );
  }

  Future<void> _createExport() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(importExportActionsProvider.notifier).createExportJob(
        type: _selectedType,
        format: _selectedFormat,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خروجی در حال آماده‌سازی است'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  String _getFormatLabel(ExportFormat format) {
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

/// Import dialog
class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  ImportExportType _selectedType = ImportExportType.audiobooks;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'ورود داده',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selection
              const Text(
                'نوع داده',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ImportExportType>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                items: [
                  ImportExportType.audiobooks,
                  ImportExportType.creators,
                ].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // File drop zone
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'فایل CSV را اینجا رها کنید',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'یا کلیک کنید برای انتخاب فایل',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'فایل باید شامل ستون‌های مورد نیاز باشد. برای دانلود نمونه، از خروجی استفاده کنید.',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );
  }

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
}
