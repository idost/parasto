import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/import_export_job.dart';

/// Service for managing bulk import/export operations
class ImportExportService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // IMPORT OPERATIONS
  // ============================================================================

  /// Create a new import job
  static Future<ImportJob?> createImportJob({
    required ImportExportType type,
    required String fileName,
    required String filePath,
  }) async {
    final response = await _supabase
        .from('import_jobs')
        .insert({
          'admin_id': _supabase.auth.currentUser?.id,
          'type': _typeToString(type),
          'file_name': fileName,
          'file_path': filePath,
        })
        .select()
        .single();

    return ImportJob.fromJson(response);
  }

  /// Get import jobs
  static Future<List<ImportJob>> getImportJobs({
    ImportExportType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _supabase.from('import_jobs').select();

    if (type != null) {
      query = query.eq('type', _typeToString(type));
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map(ImportJob.fromJson).toList();
  }

  /// Get a specific import job
  static Future<ImportJob?> getImportJob(String jobId) async {
    final response = await _supabase
        .from('import_jobs')
        .select()
        .eq('id', jobId)
        .maybeSingle();

    if (response == null) return null;
    return ImportJob.fromJson(response);
  }

  /// Update import job progress
  static Future<void> updateImportProgress(
    String jobId, {
    ImportJobStatus? status,
    int? totalRows,
    int? processedRows,
    int? successfulRows,
    int? failedRows,
    List<ImportError>? errors,
  }) async {
    final updates = <String, dynamic>{};

    if (status != null) updates['status'] = status.name;
    if (totalRows != null) updates['total_rows'] = totalRows;
    if (processedRows != null) updates['processed_rows'] = processedRows;
    if (successfulRows != null) updates['successful_rows'] = successfulRows;
    if (failedRows != null) updates['failed_rows'] = failedRows;
    if (errors != null) {
      updates['error_log'] = errors.map((e) => {
        'row': e.row,
        'errors': e.errors,
        'data': e.data,
      }).toList();
    }

    await _supabase.from('import_jobs').update(updates).eq('id', jobId);
  }

  /// Start processing an import job
  static Future<void> startImport(String jobId) async {
    await _supabase.from('import_jobs').update({
      'status': 'processing',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  /// Complete an import job
  static Future<void> completeImport(
    String jobId, {
    required int successfulRows,
    required int failedRows,
    List<ImportError>? errors,
    Map<String, dynamic>? summary,
  }) async {
    await _supabase.from('import_jobs').update({
      'status': 'completed',
      'successful_rows': successfulRows,
      'failed_rows': failedRows,
      'error_log': errors?.map((e) => {
        'row': e.row,
        'errors': e.errors,
        'data': e.data,
      }).toList() ?? [],
      'result_summary': summary,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  /// Fail an import job
  static Future<void> failImport(String jobId, String errorMessage) async {
    await _supabase.from('import_jobs').update({
      'status': 'failed',
      'error_log': [{'row': 0, 'errors': [errorMessage]}],
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  /// Cancel an import job
  static Future<void> cancelImport(String jobId) async {
    await _supabase.from('import_jobs').update({
      'status': 'cancelled',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  // ============================================================================
  // EXPORT OPERATIONS
  // ============================================================================

  /// Create a new export job
  static Future<ExportJob?> createExportJob({
    required ImportExportType type,
    ExportFormat format = ExportFormat.csv,
    Map<String, dynamic>? filters,
  }) async {
    final response = await _supabase
        .from('export_jobs')
        .insert({
          'admin_id': _supabase.auth.currentUser?.id,
          'type': _typeToString(type),
          'format': format.name,
          'filters': filters ?? {},
        })
        .select()
        .single();

    return ExportJob.fromJson(response);
  }

  /// Get export jobs
  static Future<List<ExportJob>> getExportJobs({
    ImportExportType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _supabase.from('export_jobs').select();

    if (type != null) {
      query = query.eq('type', _typeToString(type));
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map(ExportJob.fromJson).toList();
  }

  /// Get a specific export job
  static Future<ExportJob?> getExportJob(String jobId) async {
    final response = await _supabase
        .from('export_jobs')
        .select()
        .eq('id', jobId)
        .maybeSingle();

    if (response == null) return null;
    return ExportJob.fromJson(response);
  }

  /// Complete an export job
  static Future<void> completeExport(
    String jobId, {
    required String filePath,
    required int fileSize,
    required int rowCount,
  }) async {
    await _supabase.from('export_jobs').update({
      'status': 'completed',
      'file_path': filePath,
      'file_size': fileSize,
      'row_count': rowCount,
      'completed_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    }).eq('id', jobId);
  }

  /// Fail an export job
  static Future<void> failExport(String jobId) async {
    await _supabase.from('export_jobs').update({
      'status': 'failed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  /// Get download URL for an export
  static Future<String?> getExportDownloadUrl(String filePath) async {
    try {
      final response = await _supabase.storage
          .from('admin-exports')
          .createSignedUrl(filePath, 3600); // 1 hour expiry
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Delete an export job
  static Future<void> deleteExportJob(String jobId) async {
    await _supabase.from('export_jobs').delete().eq('id', jobId);
  }

  // ============================================================================
  // EXPORT DATA GENERATION
  // ============================================================================

  /// Export audiobooks data
  static Future<List<Map<String, dynamic>>> exportAudiobooks({
    Map<String, dynamic>? filters,
  }) async {
    var query = _supabase.from('audiobooks').select('''
      id,
      title_fa,
      title_en,
      content_type,
      status,
      is_featured,
      price_toman,
      play_count,
      purchase_count,
      created_at,
      categories(name),
      book_metadata(narrator_name)
    ''');

    // Apply filters
    if (filters != null) {
      if (filters['status'] != null) {
        query = query.eq('status', filters['status'] as Object);
      }
      if (filters['content_type'] != null) {
        query = query.eq('content_type', filters['content_type'] as Object);
      }
      if (filters['category_id'] != null) {
        query = query.eq('category_id', filters['category_id'] as Object);
      }
    }

    final response = await query.order('created_at', ascending: false);

    return response.map((row) => {
      'id': row['id'],
      'title_fa': row['title_fa'],
      'title_en': row['title_en'],
      'content_type': _contentTypeLabel(row['content_type'] as String? ?? 'audiobook'),
      'status': row['status'],
      'category_name': row['categories']?['name'],
      'narrator_name': row['book_metadata']?['narrator_name'],
      'price_toman': row['price_toman'],
      'play_count': row['play_count'],
      'purchase_count': row['purchase_count'],
      'created_at': row['created_at'],
    }).toList();
  }

  /// Export users data
  static Future<List<Map<String, dynamic>>> exportUsers({
    Map<String, dynamic>? filters,
  }) async {
    var query = _supabase.from('profiles').select('''
      id,
      display_name,
      full_name,
      email,
      role,
      is_disabled,
      created_at
    ''');

    if (filters != null) {
      if (filters['role'] != null) {
        query = query.eq('role', filters['role'] as Object);
      }
    }

    final response = await query.order('created_at', ascending: false);

    return response.map((row) => {
      'id': row['id'],
      'display_name': row['display_name'] ?? row['full_name'],
      'email': row['email'],
      'role': row['role'],
      'is_disabled': row['is_disabled'] == true ? 'بله' : 'خیر',
      'created_at': row['created_at'],
    }).toList();
  }

  /// Export creators data
  static Future<List<Map<String, dynamic>>> exportCreators({
    Map<String, dynamic>? filters,
  }) async {
    var query = _supabase.from('creators').select('''
      id,
      display_name,
      display_name_latin,
      creator_type,
      created_at
    ''');

    if (filters != null) {
      if (filters['creator_type'] != null) {
        query = query.eq('creator_type', filters['creator_type'] as Object);
      }
    }

    final response = await query.order('created_at', ascending: false);

    // Get audiobook counts
    final counts = await _supabase
        .from('audiobook_creators')
        .select('creator_id')
        .then((data) {
      final countMap = <int, int>{};
      for (final row in data) {
        final creatorId = row['creator_id'] as int;
        countMap[creatorId] = (countMap[creatorId] ?? 0) + 1;
      }
      return countMap;
    });

    return response.map((row) => {
      'id': row['id'],
      'display_name': row['display_name'],
      'display_name_latin': row['display_name_latin'],
      'creator_type': row['creator_type'],
      'audiobook_count': counts[row['id']] ?? 0,
      'created_at': row['created_at'],
    }).toList();
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Get Farsi label for content type
  static String _contentTypeLabel(String contentType) {
    switch (contentType) {
      case 'music':
        return 'موسیقی';
      case 'podcast':
        return 'پادکست';
      case 'article':
        return 'مقاله';
      case 'ebook':
        return 'کتاب الکترونیکی';
      default:
        return 'کتاب صوتی';
    }
  }

  static String _typeToString(ImportExportType type) {
    switch (type) {
      case ImportExportType.audiobooks:
        return 'audiobooks';
      case ImportExportType.creators:
        return 'creators';
      case ImportExportType.users:
        return 'users';
      case ImportExportType.categories:
        return 'categories';
      case ImportExportType.analytics:
        return 'analytics';
      case ImportExportType.auditLogs:
        return 'audit_logs';
    }
  }
}
