import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/scheduled_feature.dart';
import 'package:myna/services/scheduling_service.dart';

/// Filter state for scheduled features
class ScheduleFilterState {
  final ScheduleStatus? status;
  final FeatureType? featureType;
  final DateTime? fromDate;
  final DateTime? toDate;

  const ScheduleFilterState({
    this.status,
    this.featureType,
    this.fromDate,
    this.toDate,
  });

  ScheduleFilterState copyWith({
    ScheduleStatus? status,
    FeatureType? featureType,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearStatus = false,
    bool clearFeatureType = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return ScheduleFilterState(
      status: clearStatus ? null : (status ?? this.status),
      featureType: clearFeatureType ? null : (featureType ?? this.featureType),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }
}

/// Provider for schedule filter state
final scheduleFilterProvider = StateProvider<ScheduleFilterState>((ref) {
  return const ScheduleFilterState();
});

/// Provider for filtered scheduled features
final scheduledFeaturesProvider = FutureProvider<List<ScheduledFeature>>((ref) async {
  final filter = ref.watch(scheduleFilterProvider);

  return SchedulingService.getScheduledFeatures(
    status: filter.status,
    featureType: filter.featureType,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

/// Provider for active and upcoming schedules
final activeAndUpcomingSchedulesProvider = FutureProvider<List<ScheduledFeature>>((ref) async {
  return SchedulingService.getActiveAndUpcoming();
});

/// Provider for audiobook schedules
final audiobookSchedulesProvider =
    FutureProvider.family<List<ScheduledFeature>, int>((ref, audiobookId) async {
  return SchedulingService.getAudiobookSchedules(audiobookId);
});

/// Provider for promotions
final promotionsProvider = FutureProvider<List<ScheduledPromotion>>((ref) async {
  return SchedulingService.getPromotions();
});

/// Provider for active promotions
final activePromotionsProvider = FutureProvider<List<ScheduledPromotion>>((ref) async {
  return SchedulingService.getActivePromotions();
});

/// Notifier for scheduling actions
class SchedulingActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SchedulingActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Create a new scheduled feature
  Future<ScheduledFeature?> createSchedule({
    required int audiobookId,
    required DateTime startDate,
    DateTime? endDate,
    FeatureType featureType = FeatureType.featured,
    int priority = 0,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final schedule = await SchedulingService.scheduleFeature(
        audiobookId: audiobookId,
        startDate: startDate,
        endDate: endDate,
        featureType: featureType,
        priority: priority,
        notes: notes,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return schedule;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update an existing schedule
  Future<ScheduledFeature?> updateSchedule(
    String scheduleId, {
    DateTime? startDate,
    DateTime? endDate,
    FeatureType? featureType,
    int? priority,
    String? notes,
    bool clearEndDate = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final schedule = await SchedulingService.updateSchedule(
        scheduleId,
        startDate: startDate,
        endDate: endDate,
        featureType: featureType,
        priority: priority,
        notes: notes,
        clearEndDate: clearEndDate,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return schedule;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Cancel a schedule
  Future<void> cancelSchedule(String scheduleId) async {
    state = const AsyncValue.loading();
    try {
      await SchedulingService.cancelSchedule(scheduleId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a schedule
  Future<void> deleteSchedule(String scheduleId) async {
    state = const AsyncValue.loading();
    try {
      await SchedulingService.deleteSchedule(scheduleId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Bulk schedule multiple audiobooks
  Future<int> bulkSchedule({
    required List<int> audiobookIds,
    required DateTime startDate,
    DateTime? endDate,
    FeatureType featureType = FeatureType.featured,
  }) async {
    state = const AsyncValue.loading();
    try {
      final count = await SchedulingService.bulkSchedule(
        audiobookIds: audiobookIds,
        startDate: startDate,
        endDate: endDate,
        featureType: featureType,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }

  /// Create a promotion
  Future<ScheduledPromotion?> createPromotion({
    int? audiobookId,
    int? categoryId,
    int? creatorId,
    required String scope,
    required String discountType,
    required double discountValue,
    required DateTime startDate,
    required DateTime endDate,
    required String titleFa,
    String? titleEn,
    String? description,
    String? bannerUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final promotion = await SchedulingService.createPromotion(
        audiobookId: audiobookId,
        categoryId: categoryId,
        creatorId: creatorId,
        scope: scope,
        discountType: discountType,
        discountValue: discountValue,
        startDate: startDate,
        endDate: endDate,
        titleFa: titleFa,
        titleEn: titleEn,
        description: description,
        bannerUrl: bannerUrl,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return promotion;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Cancel a promotion
  Future<void> cancelPromotion(String promotionId) async {
    state = const AsyncValue.loading();
    try {
      await SchedulingService.cancelPromotion(promotionId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(scheduledFeaturesProvider);
    _ref.invalidate(activeAndUpcomingSchedulesProvider);
    _ref.invalidate(promotionsProvider);
    _ref.invalidate(activePromotionsProvider);
  }
}

/// Provider for scheduling actions
final schedulingActionsProvider =
    StateNotifierProvider<SchedulingActionsNotifier, AsyncValue<void>>((ref) {
  return SchedulingActionsNotifier(ref);
});
