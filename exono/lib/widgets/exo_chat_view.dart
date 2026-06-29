import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/chat_attachment.dart';
import '../models/chat_mention.dart';
import '../models/contact.dart';
import '../models/event.dart';
import '../models/linked_entity.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../services/api_service.dart';
import '../utils/markdown_normalize.dart';
import '../utils/safe_area_insets.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_input.dart';
import '../widgets/boxes_loader.dart';

/// Configuration for [ExoChatView].
class ExoChatViewConfig {
  /// A mention always attached to every outgoing message and shown as a
  /// non-removable chip. Null on the normal full-screen chat.
  final ChatMention? lockedMention;

  /// Reserve the bottom nav-bar inset on the composer. True on full-screen
  /// ChatScreen; false inside ExoChatSheet which manages its own bottom inset.
  final bool reserveBottomBarInset;

  /// When set, this message is sent automatically after the view mounts
  /// (mirrors ChatScreen's initialMessage behaviour).
  final String? initialMessage;

  /// When set, AI message bubbles expose an "Add to notes" option in the
  /// text-selection toolbar. The callback receives the selected text.
  final void Function(String selectedText)? onAddSelectionToNotes;

  /// Mentions pre-seeded into the composer when the sheet opens, but removable
  /// by the user (unlike [lockedMention]). Useful for providing extra context
  /// (e.g. the current event on a company prep sheet).
  final List<ChatMention> initialMentions;

  const ExoChatViewConfig({
    this.lockedMention,
    this.reserveBottomBarInset = true,
    this.initialMessage,
    this.onAddSelectionToNotes,
    this.initialMentions = const [],
  });
}

/// Reusable chat body: message canvas + pill composer.
///
/// Reads [ChatProvider] and [ConversationProvider] from context — compatible
/// with both the app-scoped singletons (ChatScreen) and the sheet-local
/// instances (ExoChatSheet).
class ExoChatView extends StatefulWidget {
  final ExoChatViewConfig config;

  const ExoChatView({super.key, this.config = const ExoChatViewConfig()});

  @override
  State<ExoChatView> createState() => _ExoChatViewState();
}

class _ExoChatViewState extends State<ExoChatView> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _initialMessageSent = false;
  bool _isComposing = false;
  bool _isSending = false;
  bool _researchMode = false;
  String? _pendingText;
  bool _pendingResearch = false;

  // Tracks text selected inside any assistant bubble for "Add to notes".
  String _selectedBubbleText = '';
  String? _selectedBubbleMessageId;

  final List<_PickedDoc> _pickedDocs = [];
  bool _isAttaching = false;
  bool _attachMenuOpen = false;
  bool _mentionMenuOpen = false;
  final List<ChatMention> _mentions = [];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    // Seed the locked mention so it is always present in the chip bar.
    if (widget.config.lockedMention != null) {
      _mentions.add(widget.config.lockedMention!);
    }
    // Seed any initial (removable) mentions — e.g. the event on a prep sheet.
    for (final m in widget.config.initialMentions) {
      if (!_mentions.any((x) => x.id == m.id && x.type == m.type)) {
        _mentions.add(m);
      }
    }
    if (widget.config.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSendInitial());
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _maybeSendInitial() async {
    if (_initialMessageSent || widget.config.initialMessage == null) return;
    _initialMessageSent = true;
    await _sendMessage(widget.config.initialMessage);
  }

  bool _isLocked(ChatMention m) {
    final locked = widget.config.lockedMention;
    return locked != null && m.id == locked.id && m.type == locked.type;
  }

  // Linked-entity cards minus the locked entity (it's already the sheet's
  // subject, so a card pointing back at it is redundant).
  List<LinkedEntity> _visibleLinkedEntities(List<LinkedEntity> entities) {
    final locked = widget.config.lockedMention;
    if (locked == null) return entities;
    return entities
        .where((e) => !(e.type == locked.type && e.id == locked.id))
        .toList();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final nearTop = _scrollController.position.extentAfter < 300;
    if (nearTop) {
      context.read<ChatProvider>().loadMore();
    }
  }

  void _onTextChanged() {
    final composing = _messageController.text.trim().isNotEmpty;
    if (composing != _isComposing) {
      setState(() => _isComposing = composing);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    var text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;

    if (preset == null && _mentions.isNotEmpty) {
      final directives = _mentions.map((m) => m.toDirective()).join(' ');
      text = '$directives $text';
    }

    final chat = context.read<ChatProvider>();
    if (_isSending ||
        _isAttaching ||
        chat.isTyping ||
        chat.pendingAction != null ||
        chat.resolvingPending) {
      return;
    }

    // Derive mention refs from the FINAL outgoing text, not just the chip list:
    // a directive can reach the text via a preset/initialMessage or locked
    // mention without ever being in `_mentions`, and if the backend's structured
    // `mentions` array is empty it can't inject the record's details — the model
    // then has to re-query from scratch. Union both sources, dedup by type+id.
    final refSeen = <String>{};
    final mentionRefs = <Map<String, dynamic>>[];
    for (final m in [..._mentions, ...ChatMention.parseAll(text)]) {
      if (refSeen.add('${m.type}:${m.id}')) mentionRefs.add(m.toRef());
    }
    final pickedDocs = List<_PickedDoc>.from(_pickedDocs);
    final optimisticAttachments = pickedDocs
        .map((d) => ChatAttachment.local(name: d.name, bytes: d.bytes))
        .toList();

    final chatProvider = context.read<ChatProvider>();
    final convProvider = context.read<ConversationProvider>();
    final auth = context.read<AuthProvider>();

    _messageController.clear();
    setState(() {
      _isComposing = false;
      _isSending = true;
      _pendingText = text;
      _pendingResearch = _researchMode;
      _attachMenuOpen = false;
      // Keep locked mention; remove only user-added mentions.
      _mentions.removeWhere((m) => !_isLocked(m));
      _pickedDocs.clear();
    });

    // Lazy-create conversation on first send.
    if (chatProvider.conversationId == null) {
      try {
        final convo = await convProvider.createGlobal();
        convProvider.setActive(convo);
        await chatProvider.loadConversation(
          convo.id,
          accessToken: auth.accessToken,
        );
      } on UnauthorizedException {
        rethrow;
      } catch (e) {
        debugPrint('Failed to create conversation: $e');
        if (mounted) setState(() => _isSending = false);
        return;
      }
    }

    final optimisticId = chatProvider.beginOptimisticSend(
      text,
      researchMode: _researchMode,
      attachments: optimisticAttachments,
    );
    _scrollToBottom();

    String? userMessageId;
    List<String>? attachmentIds;
    if (pickedDocs.isNotEmpty) {
      setState(() => _isAttaching = true);
      try {
        final msg = await ApiService.createUserMessage(
          conversationId: chatProvider.conversationId!,
          content: text,
        );
        userMessageId = msg['id'] as String;
        final ids = <String>[];
        for (final doc in pickedDocs) {
          final att = await ApiService.uploadChatAttachment(
            conversationId: chatProvider.conversationId!,
            messageId: userMessageId,
            fileBytes: doc.bytes,
            fileName: doc.name,
          );
          ids.add(att['id'] as String);
        }
        attachmentIds = ids;
      } on UnauthorizedException {
        rethrow;
      } catch (e) {
        debugPrint('Attachment upload failed: $e');
        if (mounted) {
          setState(() {
            _isSending = false;
            _isAttaching = false;
          });
        }
        return;
      } finally {
        if (mounted) setState(() => _isAttaching = false);
      }
    }

    try {
      final updatedConvo = await chatProvider.sendMessage(
        text,
        researchMode: _researchMode,
        userMessageId: userMessageId,
        attachmentIds: attachmentIds,
        mentions: mentionRefs,
        optimisticAttachments: optimisticAttachments,
        optimisticId: optimisticId,
      );

      if (updatedConvo != null) {
        final model = ConversationModel.fromJson(updatedConvo);
        convProvider.upsertConversation(model);
        if (convProvider.activeConversation?.id == model.id) {
          convProvider.setActive(model);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _researchMode = false;
          _pendingText = null;
        });
      }
    }

    _scrollToBottom();
  }

  void _openAttachMenu() {
    if (_isSending || _isAttaching) return;
    setState(() => _attachMenuOpen = !_attachMenuOpen);
  }

  Widget _buildAttachMenu() {
    return _buildPopupMenu([
      _PopupItem(
        icon: Icons.image_outlined,
        title: 'Files',
        onTap: () {
          setState(() => _attachMenuOpen = false);
          _pickFiles();
        },
      ),
      _PopupItem(
        icon: Icons.photo_camera_outlined,
        title: 'Photo',
        onTap: () {
          setState(() => _attachMenuOpen = false);
          _pickPhoto();
        },
      ),
      // Mention is hidden when the chat is already scoped to a locked entity
      // (e.g. the Exo sheet opened from a contact/event/company).
      if (widget.config.lockedMention == null)
        _PopupItem(
          icon: Icons.alternate_email_rounded,
          title: 'Mention',
          onTap: () {
            setState(() {
              _attachMenuOpen = false;
              _mentionMenuOpen = true;
            });
          },
        ),
      _PopupItem(
        icon: Icons.search_rounded,
        title: 'Research',
        trailing: Icon(
          _researchMode ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 18,
          color: _researchMode
              ? AppTheme.lightColors.accent
              : AppTheme.lightColors.textMuted,
        ),
        onTap: () {
          setState(() {
            _researchMode = !_researchMode;
            _attachMenuOpen = false;
          });
        },
      ),
    ]);
  }

  Widget _buildMentionMenu() {
    return _buildPopupMenu([
      _PopupItem(
        icon: Icons.person_rounded,
        title: 'Contacts',
        onTap: () {
          setState(() => _mentionMenuOpen = false);
          _openMentionSearch(_MentionKind.contact);
        },
      ),
      _PopupItem(
        icon: Icons.event_rounded,
        title: 'Events',
        onTap: () {
          setState(() => _mentionMenuOpen = false);
          _openMentionSearch(_MentionKind.event);
        },
      ),
      _PopupItem(
        icon: Icons.business_rounded,
        title: 'Companies',
        onTap: () {
          setState(() => _mentionMenuOpen = false);
          _openMentionSearch(_MentionKind.company);
        },
      ),
    ]);
  }

  Widget _buildPopupMenu(List<_PopupItem> items) {
    const light = AppTheme.lightColors;
    return IntrinsicWidth(
      child: Container(
        decoration: BoxDecoration(
          color: light.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: light.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final it in items) _buildPopupRow(it)],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupRow(_PopupItem item) {
    final onMenu = AppTheme.lightColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 18, color: onMenu),
              const SizedBox(width: 10),
              Text(
                item.title,
                style: context.theme.typography.sm.copyWith(
                  color: onMenu,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (item.trailing != null) ...[
                const SizedBox(width: 12),
                item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMentionSearch(_MentionKind kind) async {
    final mention = await showAppSheet<ChatMention>(
      context: context,
      builder: (ctx) => _MentionPickerSheet(initialKind: kind),
    );
    if (mention == null || !mounted) return;
    _insertMention(mention);
  }

  void _insertMention(ChatMention mention) {
    if (!_mentions.any((m) => m.id == mention.id && m.type == mention.type)) {
      setState(() => _mentions.add(mention));
    }
    _inputFocusNode.requestFocus();
  }

  void _removeMention(ChatMention mention) {
    // Locked mention cannot be removed.
    if (_isLocked(mention)) return;
    setState(() =>
        _mentions.removeWhere((m) => m.id == mention.id && m.type == mention.type));
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
          'csv', 'jpg', 'jpeg', 'png', 'webp'
        ],
      );
      if (result == null) return;
      final docs = <_PickedDoc>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        docs.add(_PickedDoc(name: f.name, bytes: bytes));
      }
      if (docs.isNotEmpty) _addPickedDocs(docs);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('unknown_path')
            ? 'File not accessible — try downloading it first'
            : 'Could not pick files';
        showAppToast(context, msg);
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final shot =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      final image =
          shot ?? await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      _addPickedDocs([_PickedDoc(name: image.name, bytes: bytes)]);
    } catch (e) {
      if (mounted) showAppToast(context, 'Could not add photo');
    }
  }

  void _addPickedDocs(List<_PickedDoc> docs) {
    setState(() {
      for (final d in docs) {
        if (_pickedDocs.length >= 5) break;
        _pickedDocs.add(d);
      }
    });
  }

  String _formatTime(DateTime dt) {
    dt = dt.toLocal();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPopupOffset = widget.config.reserveBottomBarInset
        ? bottomBarInset(context, extra: 10) + 52
        : 10.0 + 52;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: _buildChatCanvas()),
            _buildInputSection(),
          ],
        ),
        if (_attachMenuOpen || _mentionMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _attachMenuOpen = false;
                _mentionMenuOpen = false;
              }),
            ),
          ),
        if (_attachMenuOpen)
          Positioned(
            left: 12,
            bottom: bottomPopupOffset,
            child: _buildAttachMenu(),
          ),
        if (_mentionMenuOpen)
          Positioned(
            left: 12,
            bottom: bottomPopupOffset,
            child: _buildMentionMenu(),
          ),
      ],
    );
  }

  // ── Chat canvas ───────────────────────────────────────────────────────────

  Widget _buildChatCanvas() {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        if (chat.isLoadingHistory && chat.messages.isEmpty && !_isSending) {
          return const Center(child: BoxesLoader(size: 28));
        }

        if (chat.error != null &&
            chat.messages.isEmpty &&
            chat.failedMessageId == null &&
            _pendingText == null) {
          return _buildErrorState(chat.error!);
        }

        if (chat.messages.isEmpty &&
            !_isSending &&
            !chat.isLoadingHistory &&
            chat.failedMessageId == null &&
            _pendingText == null) {
          return _buildEmptyState();
        }

        if (chat.messages.isEmpty &&
            (_pendingText != null || chat.failedMessageId != null)) {
          final bubbleText = _pendingText ?? chat.failedText ?? '';
          return ListView(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildMessageBubble(
                  ChatMessage(
                    id: chat.failedMessageId ?? 'pending_local',
                    text: bubbleText,
                    isUser: true,
                    timestamp: DateTime.now(),
                    researchMode: _pendingResearch,
                  ),
                ),
              ),
            ],
          );
        }

        if (chat.messages.isEmpty) {
          return const SizedBox.shrink();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final current = _scrollController.offset;
            if (current < 200) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });

        final hasPending = chat.pendingAction != null;
        final hasBottomSlot = hasPending || chat.isTyping;
        final itemCount = (hasBottomSlot ? 1 : 0) +
            chat.messages.length +
            (chat.hasMore ? 1 : 0);

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (hasBottomSlot && index == 0) {
              if (hasPending) {
                return _buildPermissionCard(chat, chat.pendingAction!);
              }
              return _buildTypingIndicator();
            }
            final msgOffset = hasBottomSlot ? 1 : 0;
            final msgIndex = index - msgOffset;
            if (msgIndex == chat.messages.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: FCircularProgress(),
                  ),
                ),
              );
            }
            final msg = chat.messages[chat.messages.length - 1 - msgIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildMessageBubble(msg),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _c.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 24, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Exo',
              style: context.theme.typography.xl2.copyWith(
                fontWeight: FontWeight.w800,
                color: context.theme.colors.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your AI-powered companion.\nAsk about contacts, events, or anything.',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _c.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 32, color: _c.destructive),
            ),
            const SizedBox(height: 16),
            Text(
              'Connection failed',
              style: context.theme.typography.lg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.theme.colors.foreground),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: context.theme.typography.xs.copyWith(
                  color: context.theme.colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Retry',
              onPressed: () {
                final chat = context.read<ChatProvider>();
                if (chat.failedMessageId != null) {
                  chat.retryFailedMessage();
                }
              },
              variant: ButtonVariant.outline,
            ),
          ],
        ),
      ),
    );
  }

  // ── Message bubbles ───────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isOptimistic = message.id.startsWith('optimistic_') ||
        message.id == 'pending_local';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _c.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome_rounded,
                          size: 9, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Assistant',
                      style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.theme.colors.mutedForeground),
                    ),
                  ] else ...[
                    Text(
                      'You',
                      style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.theme.colors.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
            if (message.attachments.isNotEmpty) ...[
              _buildBubbleAttachments(message.attachments, isUser),
              if (message.text.trim().isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.text.trim().isNotEmpty)
              AnimatedOpacity(
                opacity: isOptimistic ? 0.75 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? _c.accent : _c.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: context.theme.colors.border),
                  ),
                  child: isUser
                      ? _buildUserText(message.text)
                      : _buildAssistantMarkdown(message.text, message.id),
                ),
              ),
            if (!isUser &&
                widget.config.onAddSelectionToNotes != null &&
                _selectedBubbleMessageId == message.id &&
                _selectedBubbleText.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  final sel = _selectedBubbleText;
                  setState(() {
                    _selectedBubbleText = '';
                    _selectedBubbleMessageId = null;
                  });
                  widget.config.onAddSelectionToNotes!(sel);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _c.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_add_outlined, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'Add to notes',
                        style: context.theme.typography.xs.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Consumer<ChatProvider>(
              builder: (context, chat, _) {
                final isFailed = chat.failedMessageId == message.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFailed) ...[
                        Icon(Icons.error_outline_rounded,
                            size: 12, color: _c.destructive),
                        const SizedBox(width: 4),
                        Text(
                          'Failed to send',
                          style: context.theme.typography.xs.copyWith(
                            fontWeight: FontWeight.w500,
                            color: _c.destructive,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => chat.retryFailedMessage(),
                          child: Text(
                            'Retry',
                            style: context.theme.typography.xs.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _c.accent,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          _formatTime(message.timestamp),
                          style: context.theme.typography.xs.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                        if (message.researchMode) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Research',
                            style: context.theme.typography.xs.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _c.accent,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
            if (!isUser) ...[
              Builder(builder: (context) {
                // Hide the card for the locked entity — the sheet is already
                // scoped to it, so a card pointing back at the same record is
                // noise (e.g. the Alexandr Wang contact card in his own sheet).
                final cards = _visibleLinkedEntities(message.linkedEntities);
                if (cards.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildLinkedEntityCards(cards),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserText(String text) {
    final baseStyle = context.theme.typography.sm.copyWith(
      fontWeight: FontWeight.w400,
      color: Colors.white,
      height: 1.5,
    );
    final matches = ChatMention.directive.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(
            TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
      }
      final name = m.group(3)!.trim();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '@$name',
              style: baseStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildAssistantMarkdown(String text, String messageId) {
    final addToNotes = widget.config.onAddSelectionToNotes;
    final body = MarkdownBody(
      data: normalizeMarkdownTables(text),
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: context.theme.typography.sm.copyWith(
          fontWeight: FontWeight.w400,
          color: _c.textSecondary,
          height: 1.55,
        ),
        code: context.theme.typography.sm.copyWith(
          fontFamily: 'monospace',
          color: _c.accent,
          backgroundColor: _c.accentSoft.withValues(alpha: 0.5),
        ),
        codeblockDecoration: BoxDecoration(
          color: _c.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.theme.colors.border),
        ),
        blockquoteDecoration: BoxDecoration(
          color: _c.accentSoft.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        tableHead: context.theme.typography.sm.copyWith(
          color: context.theme.colors.foreground,
          fontWeight: FontWeight.w700,
        ),
        tableBody: context.theme.typography.sm.copyWith(
          color: _c.textSecondary,
          height: 1.5,
        ),
        tableBorder: TableBorder.all(
          color: context.theme.colors.border,
          width: 1,
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      selectable: addToNotes == null,
    );

    if (addToNotes == null) return body;

    // SelectionArea fires onSelectionChanged on all platforms (including web
    // where the browser's native context menu can't be overridden). We surface
    // the selection as an "Add to notes" chip below the bubble instead, which
    // appears whenever text is selected and disappears after tapping.
    return SelectionArea(
      onSelectionChanged: (content) {
        final sel = content?.plainText.trim() ?? '';
        if (sel != _selectedBubbleText || messageId != _selectedBubbleMessageId) {
          setState(() {
            _selectedBubbleText = sel;
            _selectedBubbleMessageId = sel.isNotEmpty ? messageId : null;
          });
        }
      },
      child: body,
    );
  }

  Widget _buildBubbleAttachments(
      List<ChatAttachment> attachments, bool isUser) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
      children: attachments.map((a) {
        if (a.isImage && (a.url != null || a.bytes != null)) {
          final image = a.bytes != null
              ? Image.memory(a.bytes!,
                  width: 160, height: 160, fit: BoxFit.cover)
              : Image.network(
                  a.url!,
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : SizedBox(
                          width: 160,
                          height: 160,
                          child: Center(child: FCircularProgress()),
                        ),
                  errorBuilder: (ctx, e, st) => _fileChip(a.name),
                );
          return GestureDetector(
            onTap: a.url != null ? () => _openImageViewer(a.url!) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image,
            ),
          );
        }
        return _fileChip(a.name);
      }).toList(),
    );
  }

  Widget _fileChip(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 16, color: _c.accent),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedEntityCards(List<LinkedEntity> entities) {
    if (entities.length == 1) {
      return _LinkedEntityCard(entity: entities[0], colors: _c);
    }
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: entities.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            _LinkedEntityCard(entity: entities[index], colors: _c),
      ),
    );
  }

  Widget _buildTypingLabel() {
    // 'Uploading…' is a real signal (an attachment is in flight to the server,
    // which also extracts it before responding). Otherwise show the in-flight
    // dots. No timed/approximated phases.
    if (_isAttaching) {
      return Text(
        'Uploading…',
        style: context.theme.typography.sm
            .copyWith(color: context.theme.colors.mutedForeground),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _c.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 9, color: Colors.white),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Assistant',
                    style: context.theme.typography.xs.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.theme.colors.mutedForeground),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: context.theme.colors.border),
              ),
              child: _buildTypingLabel(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Permission card ───────────────────────────────────────────────────────

  Widget _buildPermissionCard(ChatProvider chat, PendingAction action) {
    final fields = _permissionFields(action);
    final busy = chat.resolvingPending;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _c.accent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: _c.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Permission needed',
                      style: context.theme.typography.xs.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _c.accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _permissionSummary(action),
                  style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colors.foreground,
                    height: 1.4,
                  ),
                ),
                if (fields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.theme.colors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.theme.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final f in fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    f.$1,
                                    style: context.theme.typography.xs.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          context.theme.colors.mutedForeground,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    f.$2,
                                    style: context.theme.typography.xs.copyWith(
                                      color: context.theme.colors.foreground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Deny',
                        variant: ButtonVariant.outline,
                        size: ButtonSize.sm,
                        fullWidth: true,
                        onPressed: busy
                            ? null
                            : () => chat.resolvePending(approve: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Approve',
                        variant: ButtonVariant.primary,
                        size: ButtonSize.sm,
                        fullWidth: true,
                        isLoading: busy,
                        onPressed: busy
                            ? null
                            : () => chat.resolvePending(approve: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const Map<String, String> _fieldLabels = {
    'first_name': 'First name',
    'last_name': 'Last name',
    'email': 'Email',
    'phone': 'Phone',
    'job_title': 'Job title',
    'linkedin_url': 'LinkedIn',
    'company_name': 'Company',
    'name': 'Name',
    'location': 'Location',
    'start_date': 'Start',
    'end_date': 'End',
    'start_time': 'Start time',
    'end_time': 'End time',
    'event_type': 'Type',
    'subject': 'Subject',
    'body': 'Body',
    'follow_up_status': 'Follow-up',
    'last_contacted_at': 'Last contacted',
    'scanned_details': 'Card details',
    'interaction_type': 'Type',
    'interaction_date': 'Date',
    'summary': 'Summary',
    'status': 'Status',
    'is_priority': 'Priority',
  };

  static const Set<String> _internalArgKeys = {
    'contact_id',
    'contact_name',
    'event_id',
    'event_name',
    'company_id',
  };

  String _permissionSummary(PendingAction a) {
    final s = a.summary.trim();
    if (s.isNotEmpty) return s;
    return 'The assistant wants to ${_humanizeKey(a.toolName).toLowerCase()}.';
  }

  static const Set<String> _summaryOnlyTools = {
    'add_target_contact_to_event',
    'add_target_company_to_event',
    'remove_target_contact_from_event',
    'remove_target_company_from_event',
    'set_event_goal',
    'add_target_note',
    'set_follow_up_status',
    'set_follow_up_priority',
    'bulk_import_contacts',
    'bulk_add_target_companies_to_event',
    'bulk_add_target_contacts_to_event',
  };

  List<(String, String)> _permissionFields(PendingAction action) {
    if (_summaryOnlyTools.contains(action.toolName)) return const [];
    final out = <(String, String)>[];
    action.toolArgs.forEach((key, value) {
      if (_internalArgKeys.contains(key)) return;
      if (value == null) return;
      String s;
      if (value is List) {
        s = value
            .whereType<Map>()
            .map((m) => (
                  _humanizeKey('${m['key'] ?? ''}'),
                  '${m['value'] ?? ''}'.trim(),
                ))
            .where((p) => p.$1.isNotEmpty && p.$2.isNotEmpty)
            .map((p) => '${p.$1}: ${p.$2}')
            .join('\n');
      } else if (value is Map) {
        s = value.entries
            .where((e) => '${e.value}'.trim().isNotEmpty)
            .map((e) => '${_humanizeKey('${e.key}')}: ${e.value}')
            .join('\n');
      } else {
        s = value.toString().trim();
      }
      if (s.isEmpty) return;
      if (s.length > 200) s = '${s.substring(0, 200)}…';
      final label = _fieldLabels[key] ?? _humanizeKey(key);
      out.add((label, s));
    });
    return out;
  }

  String _humanizeKey(String key) {
    final words = key.split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return key;
    final first = words.first;
    return [
      first[0].toUpperCase() + first.substring(1),
      ...words.skip(1),
    ].join(' ');
  }

  // ── Input section ─────────────────────────────────────────────────────────

  Widget _buildAttachmentTray() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _pickedDocs.length; i++)
              _buildTrayItem(_pickedDocs[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildTrayItem(_PickedDoc doc, int index) {
    return _withUploadOverlay(_buildTrayItemInner(doc, index));
  }

  // Dim the tray item and show a spinner while the attachment is uploading, so
  // the user sees the file is still being sent and that send is gated on it.
  Widget _withUploadOverlay(Widget child) {
    if (!_isAttaching) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(opacity: 0.5, child: child),
        Positioned.fill(
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_c.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrayItemInner(_PickedDoc doc, int index) {
    final isImage = ChatAttachment.kindFor(name: doc.name) == 'image';
    final remove = GestureDetector(
      onTap:
          _isAttaching ? null : () => setState(() => _pickedDocs.removeAt(index)),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colors.background,
          shape: BoxShape.circle,
          border: Border.all(color: context.theme.colors.border),
        ),
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.close_rounded,
            size: 12, color: context.theme.colors.mutedForeground),
      ),
    );

    if (isImage) {
      return SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                doc.bytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(top: -6, right: -6, child: remove),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 14, color: _c.accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              doc.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 4),
          remove,
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            widget.config.reserveBottomBarInset
                ? bottomBarInset(context, extra: 10)
                : 10,
          ),
          decoration: BoxDecoration(
            color: _c.background.withValues(alpha: 0.92),
            border:
                Border(top: BorderSide(color: context.theme.colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pickedDocs.isNotEmpty) _buildAttachmentTray(),
              _buildPillComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillComposer() {
    final disabled = _isSending || _isAttaching;
    const light = AppTheme.lightColors;
    final onPill = light.textPrimary;
    final onPillMuted = light.textMuted;
    return Container(
      decoration: BoxDecoration(
        color: light.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: light.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mentions.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _mentions) _buildMentionChip(m, light),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _sendMessage,
              },
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: context.theme.typography.sm.copyWith(
                  fontWeight: FontWeight.w400,
                  color: onPill,
                  height: 1.4,
                ),
                cursorColor: light.accent,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Message Exo...',
                  hintStyle:
                      context.theme.typography.sm.copyWith(color: onPillMuted),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _pillIcon(
                icon: Icons.add_rounded,
                onTap: disabled ? null : _openAttachMenu,
                active: _attachMenuOpen,
                filledCircle: true,
                onPill: onPill,
                onPillMuted: onPillMuted,
              ),
              if (_researchMode) ...[
                const SizedBox(width: 6),
                _buildResearchPill(light),
              ],
              const Spacer(),
              Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  final isBusy = chat.isTyping ||
                      _isSending ||
                      _isAttaching ||
                      chat.pendingAction != null ||
                      chat.resolvingPending;
                  final canSend = _isComposing && !isBusy;
                  final sendBg = light.accent;
                  const sendFg = Colors.white;
                  return GestureDetector(
                    onTap: canSend ? () => _sendMessage() : null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: canSend ? 1 : 0.45,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: sendBg, shape: BoxShape.circle),
                        // While the attachment is uploading, show a spinner so the
                        // user sees the file must finish before the message sends.
                        child: _isAttaching
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(sendFg),
                                ),
                              )
                            : Icon(
                                isBusy
                                    ? Icons.block_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 20,
                                color: sendFg,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResearchPill(ExonoColors light) {
    return GestureDetector(
      onTap: () => setState(() => _researchMode = false),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: light.accent,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Research',
              style: context.theme.typography.sm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionChip(ChatMention m, ExonoColors light) {
    final icon = switch (m.type) {
      'contact' => Icons.person_rounded,
      'event' => Icons.event_rounded,
      'company' => Icons.business_rounded,
      _ => Icons.alternate_email_rounded,
    };
    final locked = _isLocked(m);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
      decoration: BoxDecoration(
        color: light.accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: light.accentGlow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: light.accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              m.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.sm.copyWith(
                color: light.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Locked mention: no remove button; show a lock icon instead.
          if (locked) ...[
            const SizedBox(width: 4),
            Icon(Icons.lock_outline_rounded, size: 12, color: light.textMuted),
          ] else ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _removeMention(m),
              child:
                  Icon(Icons.close_rounded, size: 15, color: light.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pillIcon({
    required IconData icon,
    required Color onPill,
    required Color onPillMuted,
    VoidCallback? onTap,
    bool active = false,
    bool filledCircle = false,
    bool filledWhenActive = false,
    String? tooltip,
  }) {
    final solid = filledCircle || (filledWhenActive && active);
    final fillColor =
        solid ? AppTheme.lightColors.accent : Colors.transparent;
    final Color iconColor;
    if (solid) {
      iconColor = Colors.white;
    } else if (onTap == null) {
      iconColor = onPillMuted.withValues(alpha: 0.5);
    } else {
      iconColor = active ? onPill : onPillMuted;
    }
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: fillColor, shape: BoxShape.circle),
        child: Icon(icon,
            size: filledCircle ? 22 : 20, color: iconColor),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: child);
    return child;
  }
}

// ── Linked entity card ────────────────────────────────────────────────────

class _LinkedEntityCard extends StatelessWidget {
  final LinkedEntity entity;
  final ExonoColors colors;

  const _LinkedEntityCard({required this.entity, required this.colors});

  IconData get _icon {
    switch (entity.type) {
      case 'contact':
        return Icons.person_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'email_draft':
        return Icons.mail_outline_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  String get _typeLabel {
    switch (entity.type) {
      case 'contact':
        return 'Contact';
      case 'event':
        return 'Event';
      case 'email_draft':
        return 'Draft';
      default:
        return 'Item';
    }
  }

  bool get _tappable =>
      entity.type == 'contact' || entity.type == 'event';

  void _onTap(BuildContext context) {
    switch (entity.type) {
      case 'contact':
        context.push('/contacts/${entity.id}');
        break;
      case 'event':
        context.push('/events/${entity.id}');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tappable ? () => _onTap(context) : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: colors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, size: 16, color: colors.accent),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel.toUpperCase(),
                    style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entity.displayName,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entity.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      entity.subtitle!,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (_tappable) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: colors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Animated typing dot ───────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Popup menu helpers ────────────────────────────────────────────────────

class _PopupItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PopupItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });
}

// ── Picked document ───────────────────────────────────────────────────────

class _PickedDoc {
  final String name;
  final Uint8List bytes;
  const _PickedDoc({required this.name, required this.bytes});
}

// ── Mention picker sheet ──────────────────────────────────────────────────

enum _MentionKind { contact, event, company }

class _MentionPickerSheet extends StatefulWidget {
  final _MentionKind initialKind;
  const _MentionPickerSheet({required this.initialKind});

  @override
  State<_MentionPickerSheet> createState() => _MentionPickerSheetState();
}

class _MentionPickerSheetState extends State<_MentionPickerSheet> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  late _MentionKind _kind;
  bool _loading = false;
  String _query = '';

  List<Contact> _contacts = [];
  List<Event> _events = [];
  List<Map<String, dynamic>> _companies = [];

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
      _load();
    });
  }

  Future<void> _load() async {
    final kind = _kind;
    setState(() => _loading = true);
    try {
      final q = _query.trim();
      switch (kind) {
        case _MentionKind.contact:
          final contacts =
              await ApiService.getContacts(query: q.isEmpty ? null : q);
          if (!mounted) return;
          setState(() => _contacts = contacts.take(30).toList());
        case _MentionKind.event:
          final events =
              await ApiService.getEvents(query: q.isEmpty ? null : q);
          if (!mounted) return;
          setState(() => _events = events.take(30).toList());
        case _MentionKind.company:
          final companies =
              await ApiService.getCompanies(query: q.isEmpty ? null : q);
          if (!mounted) return;
          setState(() => _companies = companies.take(30).toList());
      }
    } catch (_) {
      // leave results as-is
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(ChatMention mention) => Navigator.of(context).pop(mention);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: context.theme.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: _buildSearchStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchStep() {
    final c = AppTheme.colorsOf(context);
    final kind = _kind;
    final hint = switch (kind) {
      _MentionKind.contact => 'Search contacts',
      _MentionKind.event => 'Search events',
      _MentionKind.company => 'Search companies',
    };
    final results = switch (kind) {
      _MentionKind.contact =>
        _contacts.map((ct) => _contactRow(ct, c)).toList(),
      _MentionKind.event => _events.map((e) => _eventRow(e, c)).toList(),
      _MentionKind.company =>
        _companies.map((co) => _companyRow(co, c)).toList(),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: context.theme.colors.foreground,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: AppInput(
                  controller: _search,
                  hint: hint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  onChanged: _onQueryChanged,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading && results.isEmpty
              ? Center(child: FCircularProgress())
              : results.isEmpty
                  ? Center(
                      child: Text(
                        'No matches',
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      children: results,
                    ),
        ),
      ],
    );
  }

  Widget _row({
    required Widget leading,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String first, String? last) {
    final f = first.isNotEmpty ? first[0] : '';
    final l = (last != null && last.isNotEmpty) ? last[0] : '';
    final res = '$f$l'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }

  Widget _contactRow(Contact ct, ExonoColors c) {
    final name = '${ct.firstName} ${ct.lastName ?? ''}'.trim();
    return _row(
      leading: AppAvatar(
          initials: _initials(ct.firstName, ct.lastName), size: 36),
      title: name.isEmpty ? 'Contact' : name,
      subtitle: ct.jobTitle,
      onTap: () => _pick(ChatMention(
        type: 'contact',
        id: ct.id,
        displayName: name.isEmpty ? 'Contact' : name,
      )),
    );
  }

  Widget _iconTile(IconData icon, ExonoColors c) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: c.accent),
    );
  }

  Widget _eventRow(Event e, ExonoColors c) {
    return _row(
      leading: _iconTile(Icons.event_rounded, c),
      title: e.name,
      subtitle: e.location,
      onTap: () =>
          _pick(ChatMention(type: 'event', id: e.id, displayName: e.name)),
    );
  }

  Widget _companyRow(Map<String, dynamic> co, ExonoColors c) {
    final name = (co['name'] as String?) ?? 'Company';
    return _row(
      leading: _iconTile(Icons.business_rounded, c),
      title: name,
      subtitle: co['industry'] as String?,
      onTap: () => _pick(ChatMention(
        type: 'company',
        id: co['id'] as String,
        displayName: name,
      )),
    );
  }
}
