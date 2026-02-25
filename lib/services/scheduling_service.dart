import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/scheduled_feature.dart';

/// Service for managing content scheduling
class SchedulingService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // SCHEDULED FEATURES
  // ============================================================================

  /// Create a new scheduled feature
  static Future<ScheduledFeature?> scheduleFeature({
    required int audiobookId,
    required DateTime startDate,
    DateTime? endDate,
    FeatureType featureType = FeatureType.featured,
    int priority = 0,
    String? notes,
  }) async {
    // Check for existing active/scheduled feature of same type
    final existing = await _supabase
        .from('scheduled_features')
        .select('id')
        .eq('audiobook_id', audiobookId)
        .eq('feature_type', _featureTypeToString(featureType))
        .inFilter('status', ['scheduled', 'active'])
        .maybeSingle();

    if (existing != null) {
      throw Exception('این محتوا در حال حاضر زمان‌بندی فعال دارد');
    }

    final response = await _supabase
        .from('scheduled_features')
        .insert({
          'audiobook_id': audiobookId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'feature_type': _featureTypeToString(featureType),
          'priority': priority,
          'notes': notes,
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select('*, audiobooks(id, title_fa, cover_url, content_type)')
        .single();

    return ScheduledFeature.fromJson(response);
  }

  /// Get all scheduled features
  static Future<List<ScheduledFeature>> getScheduledFeatures({
    ScheduleStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    FeatureType? featureType,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _supabase
        .from('scheduled_features')
        .select('*, audiobooks(id, title_fa, cover_url, content_type)');

    if (status != null) {
      query = query.eq('status', status.name);
    }
    if (fromDate != null) {
      query = query.gte('start_date', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('start_date', toDate.toIso8601String());
    }
    if (featureType != null) {
      query = query.eq('feature_type', _featureTypeToString(featureType));
    }

    final response = await query
        .order('start_date')
        .range(offset, offset + limit - 1);

    return response.map(ScheduledFeature.fromJson).toList();
  }

  /// Get schedules for a specific audiobook
  static Future<List<ScheduledFeature>> getAudiobookSchedules(int audiobookId) async {
    final response = await _supabase
        .from('scheduled_features')
        .select('*, audiobooks(id, title_fa, cover_url, content_type)')
        .eq('audiobook_id', audiobookId)
        .order('start_date', ascending: false);

    return response.map(ScheduledFeature.fromJson).toList();
  }

  /// Get active and upcoming schedules
  static Future<List<ScheduledFeature>> getActiveAndUpcoming({int limit = 20}) async {
    final response = await _supabase
        .from('scheduled_features')
        .select('*, audiobooks(id, title_fa, cover_url, content_type)')
        .inFilter('status', ['scheduled', 'active'])
        .order('start_date')
        .limit(limit);

    return response.map(ScheduledFeature.fromJson).toList();
  }

  /// Update a scheduled feature
  static Future<ScheduledFeature?> updateSchedule(
    String scheduleId, {
    DateTime? startDate,
    DateTime? endDate,
    FeatureType? featureType,
    int? priority,
    String? notes,
    bool clearEndDate = false,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (startDate != null) updates['start_date'] = startDate.toIso8601String();
    if (endDate != null) updates['end_date'] = endDate.toIso8601String();
    if (clearEndDate) updates['end_date'] = null;
    if (featureType != null) updates['feature_type'] = _featureTypeToString(featureType);
    if (priority != null) updates['priority'] = priority;
    if (notes != null) updates['notes'] = notes;

    final response = await _supabase
        .from('scheduled_features')
        .update(updates)
        .eq('id', scheduleId)
        .select('*, audiobooks(id, title_fa, cover_url, content_type)')
        .single();

    return ScheduledFeature.fromJson(response);
  }

  /// Cancel a scheduled feature
  static Future<void> cancelSchedule(String scheduleId) async {
    await _supabase
        .from('scheduled_features')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', scheduleId);
  }

  /// Delete a scheduled feature
  static Future<void> deleteSchedule(String scheduleId) async {
    await _supabase.from('scheduled_features').delete().eq('id', scheduleId);
  }

  /// Bulk schedule multiple audiobooks
  static Future<int> bulkSchedule({
    required List<int> audiobookIds,
    required DateTime startDate,
    DateTime? endDate,
    FeatureType featureType = FeatureType.featured,
  }) async {
    final inserts = audiobookIds.map((id) => {
      'audiobook_id': id,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'feature_type': _featureTypeToString(featureType),
      'created_by': _supabase.auth.currentUser?.id,
    }).toList();

    await _supabase.from('scheduled_features').insert(inserts);
    return inserts.length;
  }

  // ============================================================================
  // SCHEDULED PROMOTIONS
  // ============================================================================

  /// Create a new scheduled promotion
  static Future<ScheduledPromotion?> createPromotion({
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
    final response = await _supabase
        .from('scheduled_promotions')
        .insert({
          'audiobook_id': audiobookId,
          'category_id': categoryId,
          'creator_id': creatorId,
          'scope': scope,
          'discount_type': discountType,
          'discount_value': discountValue,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'title_fa': titleFa,
          'title_en': titleEn,
          'description': description,
          'banner_url': bannerUrl,
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();

    return ScheduledPromotion.fromJson(response);
  }

  /// Get all promotions
  static Future<List<ScheduledPromotion>> getPromotions({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _supabase.from('scheduled_promotions').select();

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query
        .order('start_date', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map(ScheduledPromotion.fromJson).toList();
  }

  /// Get active promotions
  static Future<List<ScheduledPromotion>> getActivePromotions() async {
    final response = await _supabase
        .from('scheduled_promotions')
        .select()
        .eq('status', 'active')
        .order('start_date');

    return response.map(ScheduledPromotion.fromJson).toList();
  }

  /// Cancel a promotion
  static Future<void> cancelPromotion(String promotionId) async {
    await _supabase
        .from('scheduled_promotions')
        .update({'status': 'cancelled'})
        .eq('id', promotionId);
  }

  /// Delete a promotion
  static Future<void> deletePromotion(String promotionId) async {
    await _supabase.from('scheduled_promotions').delete().eq('id', promotionId);
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  static String _featureTypeToString(FeatureType type) {
    switch (type) {
      case FeatureType.featured:
        return 'featured';
      case FeatureType.banner:
        return 'banner';
      case FeatureType.hero:
        return 'hero';
      case FeatureType.categoryHighlight:
        return 'category_highlight';
    }
  }
}
