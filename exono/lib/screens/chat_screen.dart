import 'dart:async';
import 'dart:ui';
import '../services/api_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../utils/markdown_normalize.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/chat_attachment.dart';
import '../models/chat_mention.dart';
import '../models/contact.dart';
import '../models/event.dart';
import '../models/linked_entity.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_input.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/offline_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_offline_screen.dart';
import '../widgets/boxes_loader.dart';
import 'app_shell.dart' show appNavBarHidden;
import '../utils/screen_logger.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  final bool isNewChat;

  const ChatScreen({
    super.key,
    this.initialMessage,
    this.isNewChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, ScreenLogger, WidgetsBindingObserver {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _initialMessageSent = false;
  bool _isComposing = false;
  bool _isSending = false;
  bool _researchMode = false;
  // Text shown as a dimmed bubble during the first-send flow, before the
  // provider's optimistic message exists (conversation is being created).
  String? _pendingText;
  bool _pendingResearch = false;

  // Documents/photos the user picked to attach to the next message.
  final List<_PickedDoc> _pickedDocs = [];
  bool _isAttaching = false;
  bool _attachMenuOpen = false;
  bool _mentionMenuOpen = false;
  // The sliders/dots menu (Mention + Research) anchored above the bar.
  // CRM records the user @-mentioned for the next message.
  final List<ChatMention> _mentions = [];

  @override
  void initState() {
    super.initState();
    appNavBarHidden.value = true;
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from background: a turn may have finished (or suspended for
    // permission) while we were away and realtime missed it. Reconcile.
    if (state == AppLifecycleState.resumed && mounted && !widget.isNewChat) {
      context.read<ChatProvider>().resync();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // With reverse:true, scrolling toward older messages means approaching maxScrollExtent
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

  Future<void> _initConversation() async {
    final convProvider = context.read<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();

    if (widget.isNewChat) {
      chatProvider.reset(loading: false);
      convProvider.setActive(null);
    }

    await convProvider.loadConversations();

    if (widget.isNewChat) {
      if (widget.initialMessage != null && !_initialMessageSent) {
        _initialMessageSent = true;
        await _sendMessage(widget.initialMessage);
      }
      return;
    }

    try {
      ConversationModel convo;
      if (convProvider.activeConversation != null) {
        convo = convProvider.activeConversation!;
      } else {
        convo = await convProvider.getOrCreateGlobal();
      }

      await chatProvider.loadConversation(
        convo.id,
        accessToken: auth.accessToken,
      );

      _jumpToBottom();

      if (widget.initialMessage != null && !_initialMessageSent) {
        _initialMessageSent = true;
        await _sendMessage(widget.initialMessage!);
      }
    } on UnauthorizedException { rethrow; } catch (_) {}
  }



  @override
  void dispose() {
    appNavBarHidden.value = false;
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
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
    // Require actual typed text. Attachments/mentions alone do not make a valid
    // message — the user must type something (backend enforces this too).
    if (text.isEmpty) return;
    // Mentions live as chips above the composer, not inline. Encode them into the
    // text on send so the bubble renders them as chips and the backend re-parses
    // them (the `mentions` array below is what it actually resolves).
    if (preset == null && _mentions.isNotEmpty) {
      final directives = _mentions.map((m) => m.toDirective()).join(' ');
      text = '$directives $text';
    }
    // Block re-entry while a send is in flight or the assistant is still
    // responding, so the user can't queue a second message before the reply.
    final chat = context.read<ChatProvider>();
    if (_isSending ||
        _isAttaching ||
        chat.isTyping ||
        chat.pendingAction != null ||
        chat.resolvingPending) {
      return;
    }

    // Snapshot mentions + picked files for this turn before clearing the
    // composer, so they survive the async send and render optimistically.
    final mentionRefs = _mentions.map((m) => m.toRef()).toList();
    final pickedDocs = List<_PickedDoc>.from(_pickedDocs);
    final optimisticAttachments = pickedDocs
        .map((d) => ChatAttachment.local(name: d.name, bytes: d.bytes))
        .toList();

    final chatProvider = context.read<ChatProvider>();
    final convProvider = context.read<ConversationProvider>();
    final auth = context.read<AuthProvider>();

    // Clear the composer + tray immediately and show the optimistic bubble (with
    // its image/file previews) right away, so there is never a window where the
    // image lingers in the bar or a bare text message shows alone.
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _isSending = true;
      _pendingText = text;
      _pendingResearch = _researchMode;
      _attachMenuOpen = false;
      _mentions.clear();
      _pickedDocs.clear();
    });

    // Lazy-create conversation on first send
    if (chatProvider.conversationId == null) {
      try {
        final convo = await convProvider.createGlobal();
        convProvider.setActive(convo);
        await chatProvider.loadConversation(
          convo.id,
          accessToken: auth.accessToken,
        );
      } on UnauthorizedException { rethrow; } catch (e) {
        debugPrint('Failed to create conversation: $e');
        if (mounted) setState(() => _isSending = false);
        return;
      }
    }

    // Insert the optimistic bubble now (carries the local image bytes) so the
    // user sees their message+image as one bubble during the upload window.
    final optimisticId = chatProvider.beginOptimisticSend(
      text,
      researchMode: _researchMode,
      attachments: optimisticAttachments,
    );
    _scrollToBottom();

    // Upload any picked documents first: create the user message, upload each
    // file to it, collect attachment_ids. The assistant turn then adopts this
    // message and is told about the attachments so it can call parse_document.
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
        // Force title to reflect the updated conversation
        if (convProvider.activeConversation?.id == model.id) {
          convProvider.setActive(model);
        }
      }
      // Send failures surface inline on the message bubble ("Failed to send /
      // Retry"), modern chat-app style — no toast or full-screen takeover.
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

  // Popup menu, anchored snug above the toolbar buttons (bottom-left).
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

  // Compact mention category popup (Contacts / Events / Companies). Choosing one
  // opens the search sheet pre-set to that kind.
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

  // Shared popup card: compact, single-line rows, sized to its content, flat
  // (no drop shadow). Anchored left so it sits just above the toolbar buttons.
  Widget _buildPopupMenu(List<_PopupItem> items) {
    // Same in both themes: pin to the light palette so it matches the bar.
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
    // Light menu in both themes, so always use the light palette's text color.
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

  // Open the search sheet for a chosen mention kind. On pick, insert the mention
  // directive at the cursor and track it so the next send carries the {type,id}
  // ref to the backend.
  Future<void> _openMentionSearch(_MentionKind kind) async {
    final mention = await showAppSheet<ChatMention>(
      context: context,
      builder: (ctx) => _MentionPickerSheet(initialKind: kind),
    );
    if (mention == null || !mounted) return;
    _insertMention(mention);
  }

  // Mentions are tracked as chips shown above the composer (not inline text).
  // They are encoded into the message text only on send (see _sendMessage).
  void _insertMention(ChatMention mention) {
    // Avoid duplicate refs for the same record.
    if (!_mentions.any((m) => m.id == mention.id && m.type == mention.type)) {
      setState(() => _mentions.add(mention));
    }
    _inputFocusNode.requestFocus();
  }

  void _removeMention(ChatMention mention) {
    setState(() => _mentions
        .removeWhere((m) => m.id == mention.id && m.type == mention.type));
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'csv', 'jpg', 'jpeg', 'png', 'webp'],
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
      if (mounted) showAppToast(context, 'Could not pick files');
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      final image = shot ?? await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      _addPickedDocs([_PickedDoc(name: image.name, bytes: bytes)]);
    } catch (e) {
      if (mounted) showAppToast(context, 'Could not add photo');
    }
  }

  // Cap at 5 attachments per message (matches the backend attachment_ids limit).
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

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<OfflineProvider>().isOnline;
    if (!isOnline) return const AppOfflineScreen(title: 'AI Chat');

    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildChatCanvas()),
                _buildInputSection(),
              ],
            ),
            // Tap-away scrim that dismisses any open composer popup.
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
            // Attach popup, floated just above the leading + button.
            if (_attachMenuOpen)
              Positioned(
                left: 12,
                bottom: bottomBarInset(context, extra: 10) + 52,
                child: _buildAttachMenu(),
              ),
            // Mention popup, floated just above the + button.
            if (_mentionMenuOpen)
              Positioned(
                left: 12,
                bottom: bottomBarInset(context, extra: 10) + 52,
                child: _buildMentionMenu(),
              ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _c.background.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: context.theme.colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Back
          AppHeaderActionButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
          const SizedBox(width: 10),
          // Title — reactive to conversation + chat updates
          Expanded(
            child: Consumer2<ConversationProvider, ChatProvider>(
              builder: (context, conv, chat, _) {
                final firstUserMsg = chat.messages
                    .where((m) => m.isUser && !m.id.startsWith('optimistic_'))
                    .firstOrNull
                    ?.text;
                final title = conv.activeConversation
                        ?.displayTitle(firstMessageSnippet: firstUserMsg) ??
                    (firstUserMsg != null
                        ? ConversationModel(
                            id: '', updatedAt: DateTime.now())
                          .displayTitle(firstMessageSnippet: firstUserMsg)
                        : 'Exono Assistant');
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.theme.typography.sm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.theme.colors.foreground,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'AI Assistant',
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat canvas ───────────────────────────────────────────────────────────

  Widget _buildChatCanvas() {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        // Full-screen loader only when loading EMPTY history for the first time,
        // but not when we're about to show the first sent message.
        if (chat.isLoadingHistory && chat.messages.isEmpty && !_isSending) {
          return const Center(child: BoxesLoader(size: 28));
        }

        // Full error state (with Retry) only for a history-load failure on an
        // empty conversation where there is no message and no pending/failed send
        // to carry an inline retry. Send failures always surface inline on the
        // bubble (modern chat-app style), never as a full-screen takeover.
        if (chat.error != null &&
            chat.messages.isEmpty &&
            chat.failedMessageId == null &&
            _pendingText == null) {
          return _buildErrorState(chat.error!);
        }

        // Empty state — only when truly idle with no messages
        if (chat.messages.isEmpty &&
            !_isSending &&
            !chat.isLoadingHistory &&
            chat.failedMessageId == null &&
            _pendingText == null) {
          return _buildEmptyState();
        }

        // First-send flow / failed first send: provider has no surviving message
        // bubble (conversation being created, or the send failed before the
        // optimistic bubble persisted). Show the user's message as a bubble so
        // they never see an empty/error screen — it carries the inline retry.
        if (chat.messages.isEmpty && (_pendingText != null || chat.failedMessageId != null)) {
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

        // Blank canvas while creating conversation + loading (fallback)
        if (chat.messages.isEmpty) {
          return const SizedBox.shrink();
        }

        // Scroll after every rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final current = _scrollController.offset;
            // Auto-scroll only if user is near bottom (within 200px); with
            // reverse:true "bottom" is offset 0.
            if (current < 200) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });

        // Bottom slot (index 0) is either the permission card or the typing
        // indicator — never both (the card replaces typing while awaiting input).
        final hasPending = chat.pendingAction != null;
        final hasBottomSlot = hasPending || chat.isTyping;

        // itemCount: bottom slot + messages + optional load-more spinner
        final itemCount =
            (hasBottomSlot ? 1 : 0) +
            chat.messages.length +
            (chat.hasMore ? 1 : 0);

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // index 0 = newest (bottom), last index = oldest (top)
            if (hasBottomSlot && index == 0) {
              if (hasPending) {
                return _buildPermissionCard(chat, chat.pendingAction!);
              }
              return _buildTypingIndicator();
            }
            final msgOffset = hasBottomSlot ? 1 : 0;
            final msgIndex = index - msgOffset;
            // Last slot: load-more spinner
            if (msgIndex == chat.messages.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
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
            // AI orb
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
              'Exono Assistant',
              style: context.theme.typography.xl2.copyWith(
                fontWeight: FontWeight.w800,
                color: context.theme.colors.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your AI-powered CRM companion.\nAsk about contacts, events, or anything.',
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
              child: Icon(Icons.wifi_off_rounded,
                  size: 32, color: _c.destructive),
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
                // A failed send retries the message; otherwise re-init the convo.
                if (chat.failedMessageId != null) {
                  chat.retryFailedMessage();
                } else {
                  _initConversation();
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
            // Sender label
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
            // Attachments (images + file chips) shown above the bubble text.
            if (message.attachments.isNotEmpty) ...[
              _buildBubbleAttachments(message.attachments, isUser),
              if (message.text.trim().isNotEmpty) const SizedBox(height: 8),
            ],
            // Bubble
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
                    : MarkdownBody(
                        data: normalizeMarkdownTables(message.text),
                        extensionSet: md.ExtensionSet.gitHubFlavored,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context)).copyWith(
                          p: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w400,
                            color: _c.textSecondary,
                            height: 1.55,
                          ),
                          code: context.theme.typography.sm.copyWith(
                            fontFamily: 'monospace',
                            color: _c.accent,
                            backgroundColor:
                                _c.accentSoft.withValues(alpha: 0.5),
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
                          tableCellsPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        selectable: true,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            // Timestamp + status
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
            if (!isUser && message.linkedEntities.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildLinkedEntityCards(message.linkedEntities),
            ],
          ],
        ),
      ),
    );
  }

  // User message text with @mentions rendered as inline accent chips instead of
  // raw "@[contact:uuid:Name]" directives.
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
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
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

  // Attachment previews inside a message bubble: image thumbnails (tap to view
  // full-screen) and file chips. Renders from a signed URL (history) or local
  // bytes (just-sent optimistic).
  Widget _buildBubbleAttachments(List<ChatAttachment> attachments, bool isUser) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
      children: attachments.map((a) {
        if (a.isImage && (a.url != null || a.bytes != null)) {
          final image = a.bytes != null
              ? Image.memory(a.bytes!, width: 160, height: 160, fit: BoxFit.cover)
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

  // Full-screen image viewer (pinch-zoom) for a tapped attachment.
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
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
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

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Permission card ───────────────────────────────────────────────────────
  // Shown inline at the bottom of the stream when the assistant wants to perform
  // a write and is waiting for the user's explicit approval.

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
              border: Border.all(color: _c.accent.withValues(alpha: 0.5), width: 1.5),
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
                // Plain-language description of the change, straight from the
                // backend's describeWrite summary — reads like a sentence, not a
                // tool name. Covers every tool (current and future) uniformly.
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
                                      color: context.theme.colors.mutedForeground,
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
                        onPressed: busy ? null : () => chat.resolvePending(approve: false),
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
                        onPressed: busy ? null : () => chat.resolvePending(approve: true),
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

  // Preview EVERY field the agent is actually writing, so the user always sees
  // exactly what will change. Resolver/internal keys (which record to target,
  // not a value being written) are hidden — the summary already names the target.
  static const Map<String, String> _fieldLabels = {
    'first_name': 'First name',
    'last_name': 'Last name',
    'email': 'Email',
    'phone': 'Phone',
    'job_title': 'Job title',
    'linkedin_url': 'LinkedIn',
    'company_name': 'Company',
    'notes': 'Notes',
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

  // Keys that select the target record rather than set a value — never shown.
  static const Set<String> _internalArgKeys = {
    'contact_id', 'contact_name', 'event_id', 'event_name', 'company_id',
  };

  // A natural-language description of the proposed change for the card.
  // Prefers the backend's describeWrite summary (a real sentence). Falls back to
  // a humanized tool name only if the summary is missing/empty, so the user never
  // sees a raw "ADD_TARGET_COMPANY_TO_EVENT"-style label.
  String _permissionSummary(PendingAction a) {
    final s = a.summary.trim();
    if (s.isNotEmpty) return s;
    return 'The assistant wants to ${_humanizeKey(a.toolName).toLowerCase()}.';
  }

  // Tools whose summary line already fully describes the change — no value grid
  // needed (showing "Company: Siemens" under "Add Siemens as a target…" is noise).
  static const Set<String> _summaryOnlyTools = {
    'add_target_contact_to_event',
    'add_target_company_to_event',
    'remove_target_contact_from_event',
    'remove_target_company_from_event',
    'set_event_goal',
    'add_target_note',
    'set_follow_up_status',
    'set_follow_up_priority',
  };

  List<(String, String)> _permissionFields(PendingAction action) {
    if (_summaryOnlyTools.contains(action.toolName)) return const [];
    final out = <(String, String)>[];
    action.toolArgs.forEach((key, value) {
      if (_internalArgKeys.contains(key)) return;
      if (value == null) return;
      // scanned_details arrives as a list of {key, value} pairs; render each as a
      // readable "Key: value" line. Other object values render the same way; the
      // rest fall back to their string form.
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

  // Fallback label for any arg key not in the map (e.g. a future tool field):
  // "some_new_field" -> "Some new field".
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

  // A single picked-attachment chip: image picks show a thumbnail, others show a
  // file chip. Both carry a remove (x) badge.
  Widget _buildTrayItem(_PickedDoc doc, int index) {
    final isImage = ChatAttachment.kindFor(name: doc.name) == 'image';
    final remove = GestureDetector(
      onTap: _isAttaching ? null : () => setState(() => _pickedDocs.removeAt(index)),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colors.background,
          shape: BoxShape.circle,
          border: Border.all(color: context.theme.colors.border),
        ),
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.close_rounded, size: 12, color: context.theme.colors.mutedForeground),
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
            bottomBarInset(context, extra: 10),
          ),
          decoration: BoxDecoration(
            color: _c.background.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: context.theme.colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Picked-attachment tray
              if (_pickedDocs.isNotEmpty) _buildAttachmentTray(),
              // Single-row pill composer: [ + ] [text] [@] [search] [clip] [-> ]
              _buildPillComposer(),
            ],
          ),
        ),
      ),
    );
  }

  // Single-row pill composer (Grok-style): a circular + on the left, the text
  // field, then quick-action icons (@ mention, search/research, attach) and a
  // circular send button. All inside one rounded pill in the system theme.
  Widget _buildPillComposer() {
    final disabled = _isSending || _isAttaching;
    // Same in both themes: pin to the light palette (light pill, dark text,
    // blue accent buttons) regardless of the active theme.
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
          // Mention chips row (above the text field).
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
          // Row 1: text field, full width.
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
                  // Pill is the background; defeat the global filled input theme.
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Message Exono…',
                  hintStyle: context.theme.typography.sm.copyWith(color: onPillMuted),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: + (attach popup), research indicator, spacer, send.
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
              // Research mode indicator pill (tap to turn off).
              if (_researchMode) ...[
                const SizedBox(width: 6),
                _buildResearchPill(light),
              ],
              const Spacer(),
              // Circular send
              Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  final isBusy = chat.isTyping ||
                      _isSending ||
                      chat.pendingAction != null ||
                      chat.resolvingPending;
                  // Require actual typed text — files/mentions alone are not
                  // enough to send.
                  final canSend = _isComposing && !isBusy;
                  // Always solid blue bg + white icon (both themes). When it
                  // can't send, dim the whole button.
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
                        decoration: BoxDecoration(color: sendBg, shape: BoxShape.circle),
                        child: Icon(
                          isBusy ? Icons.block_rounded : Icons.arrow_forward_rounded,
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

  // The "Research" indicator pill shown in the button row when research mode is
  // on. Tapping it turns research mode off.
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

  // A mention chip shown above the composer text. Tapping the × removes it.
  Widget _buildMentionChip(ChatMention m, ExonoColors light) {
    final icon = switch (m.type) {
      'contact' => Icons.person_rounded,
      'event' => Icons.event_rounded,
      'company' => Icons.business_rounded,
      _ => Icons.alternate_email_rounded,
    };
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
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeMention(m),
            child: Icon(Icons.close_rounded, size: 15, color: light.textMuted),
          ),
        ],
      ),
    );
  }

  // A round icon button inside the pill.
  //  - [filledCircle]: the leading + always sits in a subtle circle.
  //  - [filledWhenActive]: a toggle (research) that, when on, fills with a solid
  //    circle + contrasting icon so on/off is unmistakable (not just a tint).
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
    // Same in both themes: solid circle → blue bg + white icon.
    final fillColor = solid ? AppTheme.lightColors.accent : Colors.transparent;
    final Color iconColor;
    if (solid) {
      iconColor = Colors.white; // contrast on filled circle
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
        child: Icon(icon, size: filledCircle ? 22 : 20, color: iconColor),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: child);
    return child;
  }

}

// ── Animated typing dot ───────────────────────────────────────────────────

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
      case 'contact': return 'Contact';
      case 'event': return 'Event';
      case 'email_draft': return 'Draft';
      default: return 'Item';
    }
  }

  bool get _tappable => entity.type == 'contact' || entity.type == 'event';

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
          border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
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
              Icon(Icons.chevron_right_rounded, size: 16, color: colors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

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

/// One row in a composer popup menu (attach / tools).
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

/// A document/photo the user picked to attach to the next chat message,
/// held in memory until the message is sent and uploaded.
class _PickedDoc {
  final String name;
  final Uint8List bytes;
  const _PickedDoc({required this.name, required this.bytes});
}

// ── Mention picker sheet ──────────────────────────────────────────────────────
// Search across contacts, events, and companies. Returns the picked
// [ChatMention] via Navigator.pop. Local search state lives in the sheet.

// The mention kind is chosen up-front via a compact popup; the sheet then opens
// straight into the search step for that kind.
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

  // Loaded results for the selected type.
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
          // Server-side search so we never pull the whole contact list.
          final contacts = await ApiService.getContacts(query: q.isEmpty ? null : q);
          if (!mounted) return;
          setState(() => _contacts = contacts.take(30).toList());
        case _MentionKind.event:
          final events = await ApiService.getEvents(query: q.isEmpty ? null : q);
          if (!mounted) return;
          setState(() => _events = events.take(30).toList());
        case _MentionKind.company:
          final companies = await ApiService.getCompanies(query: q.isEmpty ? null : q);
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
            // Drag handle
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

  // Search within the chosen type (the type is picked via a popup before the
  // sheet opens).
  Widget _buildSearchStep() {
    final c = AppTheme.colorsOf(context);
    final kind = _kind;
    final hint = switch (kind) {
      _MentionKind.contact => 'Search contacts',
      _MentionKind.event => 'Search events',
      _MentionKind.company => 'Search companies',
    };
    final results = switch (kind) {
      _MentionKind.contact => _contacts.map((ct) => _contactRow(ct, c)).toList(),
      _MentionKind.event => _events.map((e) => _eventRow(e, c)).toList(),
      _MentionKind.company => _companies.map((co) => _companyRow(co, c)).toList(),
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
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
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
      leading: AppAvatar(initials: _initials(ct.firstName, ct.lastName), size: 36),
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
      onTap: () => _pick(ChatMention(type: 'event', id: e.id, displayName: e.name)),
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
