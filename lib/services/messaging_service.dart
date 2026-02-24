import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/admin_message.dart';

/// Service for admin messaging functionality
class MessagingService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Send a direct message to a user
  static Future<AdminMessage?> sendDirectMessage({
    required String recipientId,
    required String subject,
    required String body,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    final response = await _supabase
        .from('admin_messages')
        .insert({
          'sender_id': _supabase.auth.currentUser?.id,
          'recipient_id': recipientId,
          'subject': subject,
          'body': body,
          'type': 'direct',
          'priority': priority.name,
          'status': 'sent',
          'sent_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    // Create notification for recipient
    await _supabase.from('admin_notifications').insert({
      'admin_id': recipientId,
      'type': 'system_alert',
      'title': 'پیام جدید از مدیریت',
      'body': subject,
      'data': {'message_id': response['id']},
    });

    return AdminMessage.fromJson(response);
  }

  /// Send announcement to a segment
  static Future<AdminMessage?> sendAnnouncement({
    required RecipientSegment segment,
    required String subject,
    required String body,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    final segmentName = _segmentToDbValue(segment);

    final response = await _supabase
        .from('admin_messages')
        .insert({
          'sender_id': _supabase.auth.currentUser?.id,
          'recipient_segment': segmentName,
          'subject': subject,
          'body': body,
          'type': 'announcement',
          'priority': priority.name,
          'status': 'sent',
          'sent_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return AdminMessage.fromJson(response);
  }

  /// Save message as draft
  static Future<AdminMessage?> saveDraft({
    String? recipientId,
    RecipientSegment? segment,
    required String subject,
    required String body,
    MessageType type = MessageType.direct,
  }) async {
    final response = await _supabase
        .from('admin_messages')
        .insert({
          'sender_id': _supabase.auth.currentUser?.id,
          'recipient_id': recipientId,
          'recipient_segment':
              segment != null ? _segmentToDbValue(segment) : null,
          'subject': subject,
          'body': body,
          'type': type.name,
          'status': 'draft',
        })
        .select()
        .single();

    return AdminMessage.fromJson(response);
  }

  /// Get sent messages
  static Future<List<AdminMessage>> getSentMessages({
    int limit = 20,
    int offset = 0,
    MessageType? type,
  }) async {
    var query = _supabase
        .from('admin_messages')
        .select()
        .eq('sender_id', _supabase.auth.currentUser?.id ?? '')
        .eq('status', 'sent');

    if (type != null) {
      query = query.eq('type', type.name);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map(AdminMessage.fromJson).toList();
  }

  /// Get drafts
  static Future<List<AdminMessage>> getDrafts({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase
        .from('admin_messages')
        .select()
        .eq('sender_id', _supabase.auth.currentUser?.id ?? '')
        .eq('status', 'draft')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map(AdminMessage.fromJson).toList();
  }

  /// Delete a message
  static Future<void> deleteMessage(String messageId) async {
    await _supabase.from('admin_messages').delete().eq('id', messageId);
  }

  /// Get a single message
  static Future<AdminMessage?> getMessage(String messageId) async {
    final response = await _supabase
        .from('admin_messages')
        .select()
        .eq('id', messageId)
        .maybeSingle();

    if (response == null) return null;
    return AdminMessage.fromJson(response);
  }

  // ============================================================================
  // TEMPLATE OPERATIONS
  // ============================================================================

  /// Get all templates
  static Future<List<MessageTemplate>> getTemplates({
    String? category,
  }) async {
    var query = _supabase
        .from('message_templates')
        .select();

    if (category != null) {
      query = query.eq('category', category);
    }

    final response = await query.order('name');
    return response.map(MessageTemplate.fromJson).toList();
  }

  /// Create a template
  static Future<MessageTemplate?> createTemplate({
    required String name,
    required String subject,
    required String body,
    String category = 'general',
    List<String> variables = const [],
  }) async {
    final response = await _supabase
        .from('message_templates')
        .insert({
          'name': name,
          'subject': subject,
          'body': body,
          'category': category,
          'variables': variables,
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();

    return MessageTemplate.fromJson(response);
  }

  /// Update a template
  static Future<MessageTemplate?> updateTemplate({
    required String templateId,
    String? name,
    String? subject,
    String? body,
    String? category,
    List<String>? variables,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (subject != null) updates['subject'] = subject;
    if (body != null) updates['body'] = body;
    if (category != null) updates['category'] = category;
    if (variables != null) updates['variables'] = variables;

    if (updates.isEmpty) return null;

    final response = await _supabase
        .from('message_templates')
        .update(updates)
        .eq('id', templateId)
        .select()
        .single();

    return MessageTemplate.fromJson(response);
  }

  /// Delete a template
  static Future<void> deleteTemplate(String templateId) async {
    await _supabase.from('message_templates').delete().eq('id', templateId);
  }

  // ============================================================================
  // USER SEARCH
  // ============================================================================

  /// Search users for recipient selection
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await _supabase
        .from('profiles')
        .select('id, display_name, email, role, avatar_url')
        .or('display_name.ilike.%$query%,email.ilike.%$query%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get user counts by segment
  static Future<Map<RecipientSegment, int>> getSegmentCounts() async {
    final results = await Future.wait([
      _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'narrator'),
      _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'listener'),
      _supabase
          .from('profiles')
          .select('id'),
    ]);

    return {
      RecipientSegment.allNarrators: (results[0] as List).length,
      RecipientSegment.allListeners: (results[1] as List).length,
      RecipientSegment.allUsers: (results[2] as List).length,
    };
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  static String _segmentToDbValue(RecipientSegment segment) {
    switch (segment) {
      case RecipientSegment.allNarrators:
        return 'all_narrators';
      case RecipientSegment.allListeners:
        return 'all_listeners';
      case RecipientSegment.allUsers:
        return 'all_users';
      case RecipientSegment.custom:
        return 'custom';
    }
  }
}
