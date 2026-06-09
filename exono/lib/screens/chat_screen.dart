import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/skeleton_loader.dart';

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
    with TickerProviderStateMixin {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _initialMessageSent = false;
  bool _isComposing = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
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
      chatProvider.reset();
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
    } catch (_) {}
  }


  Future<void> _startNewChat() async {
    context.read<ConversationProvider>().setActive(null);
    context.read<ChatProvider>().reset();
    _messageController.clear();
    setState(() => _isComposing = false);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() {
      _isComposing = false;
      _isSending = true;
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
      } catch (e) {
        debugPrint('Failed to create conversation: $e');
        if (mounted) setState(() => _isSending = false);
        return;
      }
    }

    // Scroll eagerly so user sees their message appear
    _scrollToBottom();

    try {
      final updatedConvo = await chatProvider.sendMessage(text);

      if (updatedConvo != null) {
        final model = ConversationModel.fromJson(updatedConvo);
        convProvider.upsertConversation(model);
        // Force title to reflect the updated conversation
        if (convProvider.activeConversation?.id == model.id) {
          convProvider.setActive(model);
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }

    _scrollToBottom();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: DecoratedBox(
        decoration: AppTheme.appBackground(context),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildChatCanvas()),
              _buildInputSection(),
            ],
          ),
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
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Back
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _c.accent, size: 19),
            tooltip: 'Back',
          ),
          // AI avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_c.accent, _c.accentStrong],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 16, color: _c.background),
          ),
          const SizedBox(width: 10),
          // Title — reactive to conversation + chat updates
          Expanded(
            child: Consumer2<ConversationProvider, ChatProvider>(
              builder: (context, conv, chat, _) {
                // Derive first user message for snippet fallback
                final firstUserMsg = chat.messages
                    .where((m) => m.isUser && !m.id.startsWith('optimistic_'))
                    .firstOrNull
                    ?.text;
                final title = conv.activeConversation
                        ?.displayTitle(firstMessageSnippet: firstUserMsg) ??
                    (firstUserMsg != null
                        ? ConversationModel(
                            id: '', kind: 'global', updatedAt: DateTime.now())
                          .displayTitle(firstMessageSnippet: firstUserMsg)
                        : 'Exono Assistant');
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, chat, child) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: chat.isTyping
                            ? Text(
                                'typing…',
                                key: const ValueKey('typing'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _c.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : Text(
                                'AI Assistant',
                                key: const ValueKey('idle'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _c.textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // New chat
          IconButton(
            onPressed: _startNewChat,
            icon: Icon(Icons.edit_rounded, color: _c.accent, size: 20),
            tooltip: 'New Chat',
          ),
        ],
      ),
    );
  }

  // ── Chat canvas ───────────────────────────────────────────────────────────

  Widget _buildChatCanvas() {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        // Full-screen loader only when loading EMPTY history for the first time
        if (chat.isLoadingHistory && chat.messages.isEmpty) {
          return _buildChatSkeleton();
        }

        // Error with no messages
        if (chat.error != null && chat.messages.isEmpty) {
          return _buildErrorState(chat.error!);
        }

        // Empty state
        if (chat.messages.isEmpty && !_isSending) {
          return _buildEmptyState();
        }

        // Scroll after every rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final max = _scrollController.position.maxScrollExtent;
            final current = _scrollController.offset;
            // Auto-scroll only if user is near bottom (within 200px)
            if (max - current < 200) {
              _scrollController.animateTo(
                max,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });

        final itemCount =
            chat.messages.length + (chat.isTyping ? 1 : 0);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == chat.messages.length) {
              return _buildTypingIndicator();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildMessageBubble(chat.messages[index]),
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
            // Glowing AI orb
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _c.accent.withValues(alpha: 0.25),
                    _c.accentGlow.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_c.accent, _c.accentStrong],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _c.accentGlow.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 24, color: _c.background),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Exono Assistant',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _c.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your AI-powered CRM companion.\nAsk about contacts, events, or anything.',
              style: TextStyle(
                fontSize: 14,
                color: _c.textMuted,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestion('📋  Summarise contacts'),
                _buildSuggestion('📅  Upcoming events'),
                _buildSuggestion('✉️  Draft follow-up email'),
                _buildSuggestion('📊  Recent activity'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestion(String label) {
    return GestureDetector(
      onTap: _isSending ? null : () => _sendMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: _c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(fontSize: 12, color: _c.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _initConversation,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message bubbles ───────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isOptimistic = message.id.startsWith('optimistic_');

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
                        gradient: LinearGradient(
                          colors: [_c.accent, _c.accentStrong],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome_rounded,
                          size: 9, color: _c.background),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Assistant',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _c.textMuted),
                    ),
                  ] else ...[
                    Text(
                      'You',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _c.textMuted),
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
                  gradient: isUser
                      ? LinearGradient(
                          colors: [_c.accent, _c.accentStrong],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [_c.surface, _c.surfaceAlt],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: _c.border),
                ),
                child: isUser
                    ? Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      )
                    : MarkdownBody(
                        data: message.text,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context)).copyWith(
                          p: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _c.textSecondary,
                            height: 1.55,
                          ),
                          code: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: _c.accent,
                            backgroundColor:
                                _c.accentSoft.withValues(alpha: 0.5),
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: _c.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _c.border),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: _c.accentSoft.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border(
                                left: BorderSide(
                                    color: _c.accent, width: 3)),
                          ),
                        ),
                        selectable: true,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            // Timestamp + status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _c.textMuted,
                    ),
                  ),
                  if (isUser && isOptimistic) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.schedule_rounded,
                        size: 10, color: _c.textMuted),
                  ] else if (isUser && !isOptimistic) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all_rounded,
                        size: 11, color: _c.accent),
                  ],
                ],
              ),
            ),
          ],
        ),
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
                      gradient: LinearGradient(
                        colors: [_c.accent, _c.accentStrong],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 9, color: _c.background),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Assistant',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _c.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_c.surface, _c.surfaceAlt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: _c.border),
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

  // ── Input section ─────────────────────────────────────────────────────────

  // ── Skeleton loading ──────────────────────────────────────────────────────

  Widget _buildChatSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isUser = index % 2 == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender label skeleton
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                  child: SkeletonLoader(
                    width: 60,
                    height: 11,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Message bubble skeleton
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  child: SkeletonLoader(
                    width: MediaQuery.of(context).size.width * (isUser ? 0.6 : 0.75),
                    height: isUser ? 48 : (index % 3 == 0 ? 80 : 64),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Timestamp skeleton
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SkeletonLoader(
                    width: 50,
                    height: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: _c.background.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: _c.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error snack
              Consumer<ChatProvider>(
                builder: (context, chat, child) {
                  if (chat.error == null || chat.messages.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _c.destructive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _c.destructive.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 14, color: _c.destructive),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Failed to send. Tap ↑ to retry.',
                            style: TextStyle(
                                fontSize: 12, color: _c.destructive),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Input row
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: _c.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  border: Border.all(color: _c.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _inputFocusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) {
                          if (HardwareKeyboard.instance.isShiftPressed) return;
                          _sendMessage();
                        },
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _c.textPrimary,
                          height: 1.5,
                        ),
                        cursorColor: _c.accent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Message Exono…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: _c.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 13),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Consumer<ChatProvider>(
                        builder: (context, chat, child) {
                          final canSend =
                              _isComposing && !chat.isTyping;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: Material(
                              color: canSend
                                  ? _c.accent
                                  : _c.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: canSend ? () => _sendMessage() : null,
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: canSend
                                        ? Colors.white
                                        : _c.textMuted,
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
                style: TextStyle(fontSize: 10, color: _c.textMuted),
              ),
            ],
          ),
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
