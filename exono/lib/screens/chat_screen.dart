import 'dart:ui';
import '../services/api_service.dart';

import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/linked_entity.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/offline_provider.dart';
import '../widgets/app_button.dart';
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
    final text = (preset ?? _messageController.text).trim();
    // Block re-entry while a send is in flight or the assistant is still
    // responding, so the user can't queue a second message before the reply.
    final chat = context.read<ChatProvider>();
    if (text.isEmpty ||
        _isSending ||
        chat.isTyping ||
        chat.pendingAction != null ||
        chat.resolvingPending) {
      return;
    }

    _messageController.clear();
    setState(() {
      _isComposing = false;
      _isSending = true;
      _pendingText = text;
      _pendingResearch = _researchMode;
    });

    final chatProvider = context.read<ChatProvider>();
    final convProvider = context.read<ConversationProvider>();
    final auth = context.read<AuthProvider>();

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

    // Scroll eagerly so user sees their message appear
    _scrollToBottom();

    try {
      final updatedConvo = await chatProvider.sendMessage(
        text,
        researchMode: _researchMode,
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
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildChatCanvas()),
            _buildInputSection(),
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
            // Bubble
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
                    ? Text(
                        message.text,
                        style: context.theme.typography.sm.copyWith(
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      )
                    : MarkdownBody(
                        data: message.text,
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
                // Target: which entity the write acts on (verb + type badge + name).
                Builder(builder: (context) {
                  final t = _permissionTarget(action);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        t.verb,
                        style: context.theme.typography.sm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _c.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.entity.toUpperCase(),
                          style: context.theme.typography.xs.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _c.accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (t.name != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.typography.sm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.theme.colors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
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

  // The action verb + which entity this write targets, for the card's target row.
  // e.g. ('Create', 'Contact', null) or ('Update', 'Contact', 'ai testing contact').
  ({String verb, String entity, String? name}) _permissionTarget(PendingAction a) {
    final args = a.toolArgs;
    String? nameArg(String k) {
      final v = args[k];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    }

    switch (a.toolName) {
      case 'create_contact':
        {
          final full = [nameArg('first_name'), nameArg('last_name')]
              .whereType<String>()
              .join(' ')
              .trim();
          return (verb: 'Create', entity: 'Contact', name: full.isEmpty ? null : full);
        }
      case 'update_contact':
        return (verb: 'Update', entity: 'Contact', name: nameArg('contact_name'));
      case 'create_event':
        return (verb: 'Create', entity: 'Event', name: nameArg('name'));
      case 'update_event':
        return (verb: 'Update', entity: 'Event', name: nameArg('event_name') ?? nameArg('name'));
      case 'draft_email':
        return (verb: 'Draft', entity: 'Email', name: nameArg('subject'));
      case 'log_interaction':
        return (verb: 'Log', entity: 'Interaction', name: nameArg('contact_name'));
      case 'set_follow_up_status':
        return (verb: 'Set', entity: 'Follow-up', name: nameArg('contact_name'));
      case 'set_follow_up_priority':
        return (verb: 'Set', entity: 'Priority', name: nameArg('contact_name'));
      default:
        return (verb: 'Action', entity: a.toolName.replaceAll('_', ' '), name: null);
    }
  }

  List<(String, String)> _permissionFields(PendingAction action) {
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

  Widget _buildInputSection() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            bottomBarInset(context, extra: 16),
          ),
          decoration: BoxDecoration(
            color: _c.background.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: context.theme.colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Research mode toggle
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    AppButton(
                      prefixIcon: Icon(
                        Icons.travel_explore_rounded,
                        size: 14,
                        color: _researchMode
                            ? Colors.white
                            : _c.accent,
                      ),
                      label: 'RESEARCH',
                      size: ButtonSize.sm,
                      variant: _researchMode
                          ? ButtonVariant.primary
                          : ButtonVariant.outline,
                      onPressed: () {
                        setState(() => _researchMode = !_researchMode);
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Input row
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: _c.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  border: Border.all(color: context.theme.colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
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
                          color: context.theme.colors.foreground,
                          height: 1.5,
                        ),
                        cursorColor: _c.accent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Message Exono…',
                          hintStyle: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 13),
                        ),
                      ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Consumer<ChatProvider>(
                        builder: (context, chat, child) {
                          final isBusy = chat.isTyping ||
                              _isSending ||
                              chat.pendingAction != null ||
                              chat.resolvingPending;
                          final canSend = _isComposing && !isBusy;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: GestureDetector(
                              onTap: canSend ? () => _sendMessage() : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ColoredBox(
                                  color: canSend
                                      ? _c.accent
                                      : _c.surfaceElevated,
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(
                                      isBusy
                                          ? Icons.block_rounded
                                          : Icons.arrow_upward_rounded,
                                      size: 18,
                                      color: canSend
                                          ? Colors.white
                                          : context.theme.colors.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI may make mistakes. Verify important info.',
                style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
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
