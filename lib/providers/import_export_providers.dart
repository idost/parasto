import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/import_export_job.dart';
import 'package:myna/services/import_export_service.dart';

/// Provider for import jobs list
final importJobsProvider = FutureProvider<List<ImportJob>>((ref) async {
  return ImportExportService.getImportJobs();
});

/// Provider for export jobs list
final exportJobsProvider = FutureProvider<List<ExportJob>>((ref) async {
  return ImportExportService.getExportJobs();
});

/// Provider for a specific import job
final importJobProvider =
    FutureProvider.family<ImportJob?, String>((ref, jobId) async {
  return ImportExportService.getImportJob(jobId);
});

/// Provider for a specific export job
final exportJobProvider =
    FutureProvider.family<ExportJob?, String>((ref, jobId) async {
  return ImportExportService.getExportJob(jobId);
});

/// Notifier for import/export actions
class ImportExportActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ImportExportActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Create an import job
  Future<ImportJob?> createImportJob({
    required ImportExportType type,
    required String fileName,
    required String filePath,
  }) async {
    state = const AsyncValue.loading();
    try {
      final job = await ImportExportService.createImportJob(
        type: type,
        fileName: fileName,
        filePath: filePath,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return job;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Create an export job
  Future<ExportJob?> createExportJob({
    required ImportExportType type,
    ExportFormat format = ExportFormat.csv,
    Map<String, dynamic>? filters,
  }) async {
    state = const AsyncValue.loading();
    try {
      final job = await ImportExportService.createExportJob(
        type: type,
        format: format,
        filters: filters,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return job;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Cancel an import job
  Future<void> cancelImport(String jobId) async {
    state = const AsyncValue.loading();
    try {
      await ImportExportService.cancelImport(jobId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete an export job
  Future<void> deleteExport(String jobId) async {
    state = const AsyncValue.loading();
    try {
      await ImportExportService.deleteExportJob(jobId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Get download URL for an export
  Future<String?> getDownloadUrl(String filePath) async {
    return ImportExportService.getExportDownloadUrl(filePath);
  }

  void _invalidateProviders() {
    _ref.invalidate(importJobsProvider);
    _ref.invalidate(exportJobsProvider);
  }
}

/// Provider for import/export actions
final importExportActionsProvider =
    StateNotifierProvider<ImportExportActionsNotifier, AsyncValue<void>>((ref) {
  return ImportExportActionsNotifier(ref);
});
