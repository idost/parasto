import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/models/admin_message.dart';
import 'package:myna/services/messaging_service.dart';

/// Provider for sent messages
final sentMessagesProvider = FutureProvider<List<AdminMessage>>((ref) async {
  return MessagingService.getSentMessages();
});

/// Provider for drafts
final draftsProvider = FutureProvider<List<AdminMessage>>((ref) async {
  return MessagingService.getDrafts();
});

/// Provider for message templates
final messageTemplatesProvider =
    FutureProvider<List<MessageTemplate>>((ref) async {
  return MessagingService.getTemplates();
});

/// Provider for segment counts
final segmentCountsProvider =
    FutureProvider<Map<RecipientSegment, int>>((ref) async {
  return MessagingService.getSegmentCounts();
});

/// Provider for user search results
final userSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.length < 2) return [];
  return MessagingService.searchUsers(query);
});

/// Notifier for messaging actions
class MessagingActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MessagingActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Send a direct message
  Future<AdminMessage?> sendDirectMessage({
    required String recipientId,
    required String subject,
    required String body,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    state = const AsyncValue.loading();
    try {
      final message = await MessagingService.sendDirectMessage(
        recipientId: recipientId,
        subject: subject,
        body: body,
        priority: priority,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Send announcement
  Future<AdminMessage?> sendAnnouncement({
    required RecipientSegment segment,
    required String subject,
    required String body,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    state = const AsyncValue.loading();
    try {
      final message = await MessagingService.sendAnnouncement(
        segment: segment,
        subject: subject,
        body: body,
        priority: priority,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Save draft
  Future<AdminMessage?> saveDraft({
    String? recipientId,
    RecipientSegment? segment,
    required String subject,
    required String body,
    MessageType type = MessageType.direct,
  }) async {
    state = const AsyncValue.loading();
    try {
      final message = await MessagingService.saveDraft(
        recipientId: recipientId,
        segment: segment,
        subject: subject,
        body: body,
        type: type,
      );
      _invalidateProviders();
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    state = const AsyncValue.loading();
    try {
      await MessagingService.deleteMessage(messageId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create template
  Future<MessageTemplate?> createTemplate({
    required String name,
    required String subject,
    required String body,
    String category = 'general',
    List<String> variables = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final template = await MessagingService.createTemplate(
        name: name,
        subject: subject,
        body: body,
        category: category,
        variables: variables,
      );
      _ref.invalidate(messageTemplatesProvider);
      state = const AsyncValue.data(null);
      return template;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete template
  Future<void> deleteTemplate(String templateId) async {
    state = const AsyncValue.loading();
    try {
      await MessagingService.deleteTemplate(templateId);
      _ref.invalidate(messageTemplatesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(sentMessagesProvider);
    _ref.invalidate(draftsProvider);
  }
}

/// Provider for messaging actions
final messagingActionsProvider =
    StateNotifierProvider<MessagingActionsNotifier, AsyncValue<void>>((ref) {
  return MessagingActionsNotifier(ref);
});

/// Compose state for new message
class ComposeState {
  final String subject;
  final String body;
  final MessageType type;
  final MessagePriority priority;
  final String? recipientId;
  final RecipientSegment? segment;
  final MessageTemplate? template;

  const ComposeState({
    this.subject = '',
    this.body = '',
    this.type = MessageType.direct,
    this.priority = MessagePriority.normal,
    this.recipientId,
    this.segment,
    this.template,
  });

  ComposeState copyWith({
    String? subject,
    String? body,
    MessageType? type,
    MessagePriority? priority,
    String? recipientId,
    RecipientSegment? segment,
    MessageTemplate? template,
    bool clearRecipient = false,
    bool clearSegment = false,
    bool clearTemplate = false,
  }) {
    return ComposeState(
      subject: subject ?? this.subject,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      recipientId: clearRecipient ? null : (recipientId ?? this.recipientId),
      segment: clearSegment ? null : (segment ?? this.segment),
      template: clearTemplate ? null : (template ?? this.template),
    );
  }

  bool get isValid {
    if (subject.isEmpty || body.isEmpty) return false;
    if (type == MessageType.direct && recipientId == null) return false;
    if (type == MessageType.announcement && segment == null) return false;
    return true;
  }

  void clear() {}
}

/// Provider for compose state
final composeStateProvider = StateProvider<ComposeState>((ref) {
  return const ComposeState();
});
