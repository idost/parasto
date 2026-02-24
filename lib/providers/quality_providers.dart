import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/quality_issue.dart';
import 'package:myna/services/quality_check_service.dart';

/// Provider for quality stats summary
final qualityStatsProvider = FutureProvider<QualityStats>((ref) async {
  return QualityCheckService.getStats();
});

/// Filter state for quality issues
class QualityFilterState {
  final QualityIssueStatus? status;
  final QualitySeverity? severity;
  final QualityIssueType? type;

  const QualityFilterState({
    this.status,
    this.severity,
    this.type,
  });

  QualityFilterState copyWith({
    QualityIssueStatus? status,
    QualitySeverity? severity,
    QualityIssueType? type,
    bool clearStatus = false,
    bool clearSeverity = false,
    bool clearType = false,
  }) {
    return QualityFilterState(
      status: clearStatus ? null : (status ?? this.status),
      severity: clearSeverity ? null : (severity ?? this.severity),
      type: clearType ? null : (type ?? this.type),
    );
  }
}

/// Provider for quality filter state
final qualityFilterProvider = StateProvider<QualityFilterState>((ref) {
  return const QualityFilterState(status: QualityIssueStatus.open);
});

/// Provider for filtered quality issues
final qualityIssuesProvider = FutureProvider<List<QualityIssue>>((ref) async {
  final filter = ref.watch(qualityFilterProvider);

  // Fetch all issues - no arbitrary limit for admin view
  return QualityCheckService.getIssues(
    status: filter.status,
    severity: filter.severity,
    type: filter.type,
  );
});

/// Provider for issues of a specific audiobook
final audiobookIssuesProvider =
    FutureProvider.family<List<QualityIssue>, int>((ref, audiobookId) async {
  return QualityCheckService.getAudiobookIssues(audiobookId);
});

/// Provider for recent quality check runs
final qualityRunsProvider = FutureProvider<List<QualityCheckRun>>((ref) async {
  return QualityCheckService.getRecentRuns(limit: 10);
});

/// Provider for currently running check
final runningCheckProvider = FutureProvider<QualityCheckRun?>((ref) async {
  return QualityCheckService.getRunningCheck();
});

/// Notifier for quality check actions
class QualityActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  QualityActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Resolve an issue
  Future<void> resolveIssue(String issueId, {String? note}) async {
    state = const AsyncValue.loading();
    try {
      await QualityCheckService.resolveIssue(issueId, note: note);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Ignore an issue
  Future<void> ignoreIssue(String issueId, {String? note}) async {
    state = const AsyncValue.loading();
    try {
      await QualityCheckService.ignoreIssue(issueId, note: note);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reopen an issue
  Future<void> reopenIssue(String issueId) async {
    state = const AsyncValue.loading();
    try {
      await QualityCheckService.reopenIssue(issueId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Check a single audiobook
  Future<List<QualityIssue>> checkAudiobook(int audiobookId) async {
    state = const AsyncValue.loading();
    try {
      final issues = await QualityCheckService.checkAudiobook(audiobookId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return issues;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return [];
    }
  }

  /// Run batch check on pending content
  Future<QualityCheckRun?> runBatchCheck() async {
    state = const AsyncValue.loading();
    try {
      final run = await QualityCheckService.runBatchCheck();
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return run;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(qualityStatsProvider);
    _ref.invalidate(qualityIssuesProvider);
    _ref.invalidate(qualityRunsProvider);
    _ref.invalidate(runningCheckProvider);
  }
}

/// Provider for quality actions
final qualityActionsProvider =
    StateNotifierProvider<QualityActionsNotifier, AsyncValue<void>>((ref) {
  return QualityActionsNotifier(ref);
});
