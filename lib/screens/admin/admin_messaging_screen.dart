import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/admin_message.dart';
import 'package:myna/models/admin_message_presentation.dart';
import 'package:myna/providers/messaging_providers.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/empty_state.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Admin messaging hub screen
class AdminMessagingScreen extends ConsumerStatefulWidget {
  const AdminMessagingScreen({super.key});

  @override
  ConsumerState<AdminMessagingScreen> createState() =>
      _AdminMessagingScreenState();
}

class _AdminMessagingScreenState extends ConsumerState<AdminMessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            AdminScreenHeader(
              title: 'مرکز پیام‌ها',
              icon: Icons.message_rounded,
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _showComposeDialog(context),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('پیام جدید'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            // Tabs
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.send_rounded),
                    text: 'ارسال شده',
                  ),
                  Tab(
                    icon: Icon(Icons.drafts_rounded),
                    text: 'پیش‌نویس‌ها',
                  ),
                  Tab(
                    icon: Icon(Icons.description_rounded),
                    text: 'قالب‌ها',
                  ),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSentMessages(),
                  _buildDrafts(),
                  _buildTemplates(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentMessages() {
    final messagesAsync = ref.watch(sentMessagesProvider);

    return messagesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('خطا: $e', style: const TextStyle(color: AppColors.error)),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return const EmptyState(
            icon: Icons.send_rounded,
            message: 'پیامی ارسال نشده',
            subtitle: 'هنوز پیامی ارسال نکرده‌اید',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(sentMessagesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) =>
                _MessageCard(message: messages[index]),
          ),
        );
      },
    );
  }

  Widget _buildDrafts() {
    final draftsAsync = ref.watch(draftsProvider);

    return draftsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('خطا: $e', style: const TextStyle(color: AppColors.error)),
      ),
      data: (drafts) {
        if (drafts.isEmpty) {
          return const EmptyState(
            icon: Icons.drafts_rounded,
            message: 'پیش‌نویسی وجود ندارد',
            subtitle: 'پیش‌نویس‌های شما اینجا نمایش داده می‌شوند',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(draftsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            itemBuilder: (context, index) =>
                _MessageCard(message: drafts[index], isDraft: true),
          ),
        );
      },
    );
  }

  Widget _buildTemplates() {
    final templatesAsync = ref.watch(messageTemplatesProvider);

    return templatesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('خطا: $e', style: const TextStyle(color: AppColors.error)),
      ),
      data: (templates) {
        // Include default templates if database is empty
        final allTemplates = templates.isEmpty
            ? DefaultTemplates.templates
                .map((t) => MessageTemplate(
                      id: t['name'] as String,
                      name: t['name'] as String,
                      subject: t['subject'] as String,
                      body: t['body'] as String,
                      variables: List<String>.from(t['variables'] as List),
                      category: t['category'] as String,
                      createdAt: DateTime.now(),
                    ))
                .toList()
            : templates;

        if (allTemplates.isEmpty) {
          return const EmptyState(
            icon: Icons.description_rounded,
            message: 'قالبی وجود ندارد',
            subtitle: 'قالب‌های پیام اینجا نمایش داده می‌شوند',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(messageTemplatesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allTemplates.length,
            itemBuilder: (context, index) => _TemplateCard(
              template: allTemplates[index],
              onUse: () => _useTemplate(allTemplates[index]),
            ),
          ),
        );
      },
    );
  }

  void _showComposeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _ComposeDialog(),
    );
  }

  void _useTemplate(MessageTemplate template) {
    ref.read(composeStateProvider.notifier).state = ComposeState(
      subject: template.subject,
      body: template.body,
      template: template,
    );
    _showComposeDialog(context);
  }
}

/// Message card widget
class _MessageCard extends ConsumerWidget {
  final AdminMessage message;
  final bool isDraft;

  const _MessageCard({
    required this.message,
    this.isDraft = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: () => _showMessageDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: message.priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      message.typeIcon,
                      color: message.priorityColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.subject,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: message.statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                message.statusLabel,
                                style: TextStyle(
                                  color: message.statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              message.segmentLabel,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  if (isDraft)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onSelected: (action) =>
                          _handleAction(context, ref, action),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('ویرایش'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('حذف'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Body preview
              const SizedBox(height: 12),
              Text(
                message.body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Footer
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(message.createdAt),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: message.priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  message.typeIcon,
                  color: message.priorityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.subject,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Meta info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildMetaRow('نوع', message.typeLabel),
                      _buildMetaRow('اولویت', message.priorityLabel),
                      _buildMetaRow('گیرنده', message.segmentLabel),
                      _buildMetaRow('تاریخ', _formatDate(message.createdAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Body
                Text(
                  message.body,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'delete':
        ref.read(messagingActionsProvider.notifier).deleteMessage(message.id);
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// Template card widget
class _TemplateCard extends StatelessWidget {
  final MessageTemplate template;
  final VoidCallback onUse;

  const _TemplateCard({
    required this.template,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: onUse,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      template.categoryIcon,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            template.categoryLabel,
                            style: const TextStyle(
                              color: AppColors.info,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onUse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('استفاده'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                template.subject,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (template.variables.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: template.variables
                      .map((v) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '{{$v}}',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compose dialog
class _ComposeDialog extends ConsumerStatefulWidget {
  const _ComposeDialog();

  @override
  ConsumerState<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<_ComposeDialog> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();

  MessageType _type = MessageType.direct;
  MessagePriority _priority = MessagePriority.normal;
  RecipientSegment? _segment;
  String? _recipientId;
  String? _recipientName;

  @override
  void initState() {
    super.initState();
    // Load from compose state if available
    final state = ref.read(composeStateProvider);
    _subjectController.text = state.subject;
    _bodyController.text = state.body;
    _type = state.type;
    _priority = state.priority;
    _segment = state.segment;
    _recipientId = state.recipientId;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segmentCounts = ref.watch(segmentCountsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'نوشتن پیام',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message type
                      const Text(
                        'نوع پیام',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _TypeChip(
                            label: 'مستقیم',
                            icon: Icons.person_rounded,
                            isSelected: _type == MessageType.direct,
                            onTap: () =>
                                setState(() => _type = MessageType.direct),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: 'اطلاعیه',
                            icon: Icons.campaign_rounded,
                            isSelected: _type == MessageType.announcement,
                            onTap: () => setState(
                                () => _type = MessageType.announcement),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Recipient selection
                      if (_type == MessageType.direct) ...[
                        const Text(
                          'گیرنده',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_recipientId != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _recipientName ?? _recipientId!,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18),
                                  onPressed: () => setState(() {
                                    _recipientId = null;
                                    _recipientName = null;
                                  }),
                                ),
                              ],
                            ),
                          )
                        else
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'جستجوی کاربر...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceLight,
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        // Search results
                        if (_searchController.text.length >= 2)
                          _buildSearchResults(),
                      ] else ...[
                        // Segment selection
                        const Text(
                          'گیرندگان',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        segmentCounts.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (counts) => Column(
                            children: [
                              _SegmentOption(
                                segment: RecipientSegment.allNarrators,
                                count: counts[RecipientSegment.allNarrators] ??
                                    0,
                                isSelected:
                                    _segment == RecipientSegment.allNarrators,
                                onTap: () => setState(() =>
                                    _segment = RecipientSegment.allNarrators),
                              ),
                              _SegmentOption(
                                segment: RecipientSegment.allListeners,
                                count: counts[RecipientSegment.allListeners] ??
                                    0,
                                isSelected:
                                    _segment == RecipientSegment.allListeners,
                                onTap: () => setState(() =>
                                    _segment = RecipientSegment.allListeners),
                              ),
                              _SegmentOption(
                                segment: RecipientSegment.allUsers,
                                count:
                                    counts[RecipientSegment.allUsers] ?? 0,
                                isSelected:
                                    _segment == RecipientSegment.allUsers,
                                onTap: () => setState(
                                    () => _segment = RecipientSegment.allUsers),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Priority
                      const Text(
                        'اولویت',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: MessagePriority.values.map((p) {
                          final isSelected = _priority == p;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: ChoiceChip(
                              label: Text(_getPriorityLabel(p)),
                              selected: isSelected,
                              onSelected: (_) =>
                                  setState(() => _priority = p),
                              selectedColor:
                                  _getPriorityColor(p).withValues(alpha: 0.2),
                              avatar: Icon(
                                _getPriorityIcon(p),
                                size: 16,
                                color: isSelected
                                    ? _getPriorityColor(p)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Subject
                      const Text(
                        'موضوع',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          hintText: 'موضوع پیام',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Body
                      const Text(
                        'متن پیام',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bodyController,
                        decoration: InputDecoration(
                          hintText: 'متن پیام...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                        ),
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saveDraft,
                      child: const Text('ذخیره پیش‌نویس'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('انصراف'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _canSend() ? _send : null,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('ارسال'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = ref.watch(userSearchProvider(_searchController.text));

    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'] as String)
                      : null,
                  child: user['avatar_url'] == null
                      ? const Icon(Icons.person_rounded)
                      : null,
                ),
                title: Text(user['display_name'] as String? ?? 'کاربر'),
                subtitle: Text(user['email'] as String? ?? ''),
                onTap: () {
                  setState(() {
                    _recipientId = user['id'] as String;
                    _recipientName = user['display_name'] as String?;
                    _searchController.clear();
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  bool _canSend() {
    if (_subjectController.text.isEmpty) return false;
    if (_bodyController.text.isEmpty) return false;
    if (_type == MessageType.direct && _recipientId == null) return false;
    if (_type == MessageType.announcement && _segment == null) return false;
    return true;
  }

  void _send() async {
    if (_type == MessageType.direct) {
      await ref.read(messagingActionsProvider.notifier).sendDirectMessage(
            recipientId: _recipientId!,
            subject: _subjectController.text,
            body: _bodyController.text,
            priority: _priority,
          );
    } else {
      await ref.read(messagingActionsProvider.notifier).sendAnnouncement(
            segment: _segment!,
            subject: _subjectController.text,
            body: _bodyController.text,
            priority: _priority,
          );
    }

    // Clear compose state
    ref.read(composeStateProvider.notifier).state = const ComposeState();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پیام با موفقیت ارسال شد'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _saveDraft() async {
    await ref.read(messagingActionsProvider.notifier).saveDraft(
          recipientId: _recipientId,
          segment: _segment,
          subject: _subjectController.text,
          body: _bodyController.text,
          type: _type,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پیش‌نویس ذخیره شد'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  String _getPriorityLabel(MessagePriority p) {
    switch (p) {
      case MessagePriority.low:
        return 'کم';
      case MessagePriority.normal:
        return 'عادی';
      case MessagePriority.high:
        return 'بالا';
      case MessagePriority.urgent:
        return 'فوری';
    }
  }

  Color _getPriorityColor(MessagePriority p) {
    switch (p) {
      case MessagePriority.low:
        return AppColors.textTertiary;
      case MessagePriority.normal:
        return AppColors.info;
      case MessagePriority.high:
        return AppColors.warning;
      case MessagePriority.urgent:
        return AppColors.error;
    }
  }

  IconData _getPriorityIcon(MessagePriority p) {
    switch (p) {
      case MessagePriority.low:
        return Icons.arrow_downward_rounded;
      case MessagePriority.normal:
        return Icons.remove_rounded;
      case MessagePriority.high:
        return Icons.arrow_upward_rounded;
      case MessagePriority.urgent:
        return Icons.priority_high_rounded;
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  final RecipientSegment segment;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentOption({
    required this.segment,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getSegmentIcon(),
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getSegmentLabel(),
                style: TextStyle(
                  color:
                      isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${FarsiUtils.toFarsiDigits(count)} نفر',
                style: const TextStyle(
                  color: AppColors.info,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSegmentIcon() {
    switch (segment) {
      case RecipientSegment.allNarrators:
        return Icons.record_voice_over_rounded;
      case RecipientSegment.allListeners:
        return Icons.headphones_rounded;
      case RecipientSegment.allUsers:
        return Icons.people_rounded;
      case RecipientSegment.custom:
        return Icons.tune_rounded;
    }
  }

  String _getSegmentLabel() {
    switch (segment) {
      case RecipientSegment.allNarrators:
        return 'همه گویندگان';
      case RecipientSegment.allListeners:
        return 'همه شنوندگان';
      case RecipientSegment.allUsers:
        return 'همه کاربران';
      case RecipientSegment.custom:
        return 'سفارشی';
    }
  }
}
