import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/quality_issue.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for content quality checks and issue management
class QualityCheckService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // QUALITY ISSUES CRUD
  // ============================================================================

  /// Get all quality issues with filtering
  static Future<List<QualityIssue>> getIssues({
    QualityIssueStatus? status,
    QualitySeverity? severity,
    QualityIssueType? type,
    int? audiobookId,
    int? limit,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('content_quality_issues').select();

      if (status != null) {
        query = query.eq('status', status.name);
      }
      if (severity != null) {
        query = query.eq('severity', severity.name);
      }
      if (type != null) {
        query = query.eq('type', _typeToString(type));
      }
      if (audiobookId != null) {
        query = query.eq('audiobook_id', audiobookId);
      }

      // Apply ordering
      final orderedQuery = query.order('created_at', ascending: false);

      // Apply limit/offset if specified, otherwise fetch all
      final List<dynamic> response;
      if (limit != null) {
        response = await orderedQuery.range(offset, offset + limit - 1);
      } else {
        response = await orderedQuery;
      }

      return response.map((json) => QualityIssue.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.e('Error fetching quality issues', error: e);
      return [];
    }
  }

  /// Get issues for a specific audiobook
  static Future<List<QualityIssue>> getAudiobookIssues(int audiobookId) async {
    try {
      final response = await _supabase
          .from('content_quality_issues')
          .select()
          .eq('audiobook_id', audiobookId)
          .order('severity', ascending: true)
          .order('created_at', ascending: false);

      return response.map(QualityIssue.fromJson).toList();
    } catch (e) {
      AppLogger.e('Error fetching audiobook issues', error: e);
      return [];
    }
  }

  /// Get quality stats summary
  static Future<QualityStats> getStats() async {
    try {
      final response = await _supabase
          .from('content_quality_issues')
          .select('status, severity, type');

      int total = 0;
      int open = 0;
      int resolved = 0;
      int ignored = 0;
      final bySeverity = <QualitySeverity, int>{};
      final byType = <QualityIssueType, int>{};

      for (final row in response) {
        total++;

        final status = row['status'] as String?;
        if (status == 'open') {
          open++;
        } else if (status == 'resolved') {
          resolved++;
        } else if (status == 'ignored') {
          ignored++;
        }

        final severity = _parseSeverity(row['severity'] as String);
        bySeverity[severity] = (bySeverity[severity] ?? 0) + 1;

        final type = _parseType(row['type'] as String);
        byType[type] = (byType[type] ?? 0) + 1;
      }

      return QualityStats(
        totalIssues: total,
        openIssues: open,
        resolvedIssues: resolved,
        ignoredIssues: ignored,
        bySeverity: bySeverity,
        byType: byType,
      );
    } catch (e) {
      AppLogger.e('Error fetching quality stats', error: e);
      return QualityStats.empty();
    }
  }

  /// Resolve an issue
  static Future<void> resolveIssue(String issueId, {String? note}) async {
    try {
      await _supabase.from('content_quality_issues').update({
        'status': 'resolved',
        'resolved_by': _supabase.auth.currentUser?.id,
        'resolved_at': DateTime.now().toIso8601String(),
        'resolution_note': note,
      }).eq('id', issueId);
    } catch (e) {
      AppLogger.e('Error resolving issue', error: e);
      rethrow;
    }
  }

  /// Ignore an issue
  static Future<void> ignoreIssue(String issueId, {String? note}) async {
    try {
      await _supabase.from('content_quality_issues').update({
        'status': 'ignored',
        'resolved_by': _supabase.auth.currentUser?.id,
        'resolved_at': DateTime.now().toIso8601String(),
        'resolution_note': note,
      }).eq('id', issueId);
    } catch (e) {
      AppLogger.e('Error ignoring issue', error: e);
      rethrow;
    }
  }

  /// Reopen an issue
  static Future<void> reopenIssue(String issueId) async {
    try {
      await _supabase.from('content_quality_issues').update({
        'status': 'open',
        'resolved_by': null,
        'resolved_at': null,
        'resolution_note': null,
      }).eq('id', issueId);
    } catch (e) {
      AppLogger.e('Error reopening issue', error: e);
      rethrow;
    }
  }

  // ============================================================================
  // QUALITY CHECKS
  // ============================================================================

  /// Run quality checks on a single audiobook
  static Future<List<QualityIssue>> checkAudiobook(int audiobookId) async {
    try {
      final issues = <Map<String, dynamic>>[];

      // Fetch audiobook data
      final audiobook = await _supabase
          .from('audiobooks')
          .select('*, book_metadata(*), music_metadata(*)')
          .eq('id', audiobookId)
          .single();

      // 1. Check cover image
      if (audiobook['cover_url'] == null ||
          (audiobook['cover_url'] as String).isEmpty) {
        issues.add({
          'audiobook_id': audiobookId,
          'type': 'missing_cover',
          'severity': 'error',
          'message': 'تصویر جلد وجود ندارد',
          'details': <String, dynamic>{},
        });
      }

      // 2. Check required metadata
      final missingFields = <String>[];

      if (audiobook['title_fa'] == null ||
          (audiobook['title_fa'] as String).isEmpty) {
        missingFields.add('عنوان فارسی');
      }
      if (audiobook['category_id'] == null) {
        missingFields.add('دسته‌بندی');
      }

      // Check narrator for books
      if (audiobook['is_music'] != true) {
        final bookMeta = audiobook['book_metadata'];
        if (bookMeta == null ||
            bookMeta['narrator_name'] == null ||
            (bookMeta['narrator_name'] as String).isEmpty) {
          missingFields.add('نام گوینده');
        }
      }

      if (missingFields.isNotEmpty) {
        issues.add({
          'audiobook_id': audiobookId,
          'type': 'missing_metadata',
          'severity': 'warning',
          'message': 'اطلاعات ناقص: ${missingFields.join('، ')}',
          'details': {'missing_fields': missingFields},
        });
      }

      // 3. Check for duplicate titles
      final titleFa = audiobook['title_fa'] as String?;
      if (titleFa != null && titleFa.isNotEmpty) {
        final duplicates = await _supabase
            .from('audiobooks')
            .select('id, title_fa')
            .eq('title_fa', titleFa)
            .neq('id', audiobookId);

        if (duplicates.isNotEmpty) {
          issues.add({
            'audiobook_id': audiobookId,
            'type': 'duplicate_title',
            'severity': 'warning',
            'message': 'عنوان تکراری با ${duplicates.length} محتوای دیگر',
            'details': {
              'duplicate_ids': duplicates.map((e) => e['id']).toList(),
            },
          });
        }
      }

      // 4. Check audio duration (flag very short or very long)
      final duration = audiobook['total_duration_seconds'] as int?;
      if (duration != null) {
        if (duration < 60) {
          issues.add({
            'audiobook_id': audiobookId,
            'type': 'audio_duration',
            'severity': 'info',
            'message': 'مدت زمان خیلی کوتاه (کمتر از ۱ دقیقه)',
            'details': {'duration_seconds': duration},
          });
        } else if (duration > 36000) {
          // 10 hours
          issues.add({
            'audiobook_id': audiobookId,
            'type': 'audio_duration',
            'severity': 'info',
            'message': 'مدت زمان خیلی طولانی (بیش از ۱۰ ساعت)',
            'details': {'duration_seconds': duration},
          });
        }
      }

      // Save issues to database
      if (issues.isNotEmpty) {
        // First, remove old open issues for this audiobook
        await _supabase
            .from('content_quality_issues')
            .delete()
            .eq('audiobook_id', audiobookId)
            .eq('status', 'open');

        // Insert new issues
        await _supabase.from('content_quality_issues').insert(issues);
      }

      // Fetch and return the created issues
      return getAudiobookIssues(audiobookId);
    } catch (e) {
      AppLogger.e('Error checking audiobook', error: e);
      return [];
    }
  }

  /// Run quality checks on all pending content
  static Future<QualityCheckRun?> runBatchCheck() async {
    try {
      // Create run record
      final run = await _supabase
          .from('quality_check_runs')
          .insert({
            'scope': 'batch',
            'triggered_by': _supabase.auth.currentUser?.id,
            'status': 'running',
          })
          .select()
          .single();

      final runId = run['id'] as String;

      // Get pending audiobooks
      final audiobooks = await _supabase
          .from('audiobooks')
          .select('id')
          .eq('status', 'pending');

      await _supabase.from('quality_check_runs').update({
        'total_items': audiobooks.length,
      }).eq('id', runId);

      // Process each audiobook
      int issuesFound = 0;
      for (int i = 0; i < audiobooks.length; i++) {
        try {
          final issues = await checkAudiobook(audiobooks[i]['id'] as int);
          issuesFound += issues.where((e) => e.status == QualityIssueStatus.open).length;

          // Update progress
          await _supabase.from('quality_check_runs').update({
            'checked_items': i + 1,
            'issues_found': issuesFound,
          }).eq('id', runId);
        } catch (e) {
          AppLogger.e('Error checking audiobook ${audiobooks[i]['id']}', error: e);
        }
      }

      // Complete
      await _supabase.from('quality_check_runs').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', runId);

      // Return the run
      final completedRun = await _supabase
          .from('quality_check_runs')
          .select()
          .eq('id', runId)
          .single();

      return QualityCheckRun.fromJson(completedRun);
    } catch (e) {
      AppLogger.e('Error running batch check', error: e);
      return null;
    }
  }

  /// Get recent quality check runs
  static Future<List<QualityCheckRun>> getRecentRuns({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('quality_check_runs')
          .select()
          .order('started_at', ascending: false)
          .limit(limit);

      return response.map(QualityCheckRun.fromJson).toList();
    } catch (e) {
      AppLogger.e('Error fetching quality runs', error: e);
      return [];
    }
  }

  /// Get running check (if any)
  static Future<QualityCheckRun?> getRunningCheck() async {
    try {
      final response = await _supabase
          .from('quality_check_runs')
          .select()
          .eq('status', 'running')
          .maybeSingle();

      if (response == null) return null;
      return QualityCheckRun.fromJson(response);
    } catch (e) {
      AppLogger.e('Error fetching running check', error: e);
      return null;
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  static String _typeToString(QualityIssueType type) {
    switch (type) {
      case QualityIssueType.audioFormat:
        return 'audio_format';
      case QualityIssueType.audioBitrate:
        return 'audio_bitrate';
      case QualityIssueType.audioDuration:
        return 'audio_duration';
      case QualityIssueType.missingCover:
        return 'missing_cover';
      case QualityIssueType.lowQualityCover:
        return 'low_quality_cover';
      case QualityIssueType.coverDimensions:
        return 'cover_dimensions';
      case QualityIssueType.missingMetadata:
        return 'missing_metadata';
      case QualityIssueType.duplicateContent:
        return 'duplicate_content';
      case QualityIssueType.duplicateTitle:
        return 'duplicate_title';
      case QualityIssueType.profanityDetected:
        return 'profanity_detected';
      case QualityIssueType.copyrightFlag:
        return 'copyright_flag';
    }
  }

  static QualityIssueType _parseType(String type) {
    switch (type) {
      case 'audio_format':
        return QualityIssueType.audioFormat;
      case 'audio_bitrate':
        return QualityIssueType.audioBitrate;
      case 'audio_duration':
        return QualityIssueType.audioDuration;
      case 'missing_cover':
        return QualityIssueType.missingCover;
      case 'low_quality_cover':
        return QualityIssueType.lowQualityCover;
      case 'cover_dimensions':
        return QualityIssueType.coverDimensions;
      case 'missing_metadata':
        return QualityIssueType.missingMetadata;
      case 'duplicate_content':
        return QualityIssueType.duplicateContent;
      case 'duplicate_title':
        return QualityIssueType.duplicateTitle;
      case 'profanity_detected':
        return QualityIssueType.profanityDetected;
      case 'copyright_flag':
        return QualityIssueType.copyrightFlag;
      default:
        return QualityIssueType.missingMetadata;
    }
  }

  static QualitySeverity _parseSeverity(String severity) {
    switch (severity) {
      case 'info':
        return QualitySeverity.info;
      case 'warning':
        return QualitySeverity.warning;
      case 'error':
        return QualitySeverity.error;
      case 'critical':
        return QualitySeverity.critical;
      default:
        return QualitySeverity.warning;
    }
  }
}
