import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../widgets/message_link_chips.dart';
import '../widgets/skeleton_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showThreadPicker = false;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final auth = context.read<AuthProvider>();
    final convProvider = context.read<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();

    try {
      await convProvider.loadConversations();
      final convo = await convProvider.getOrCreateGlobal();
      await chatProvider.loadConversation(
        convo.id,
        accessToken: auth.accessToken,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat: $e'),
              backgroundColor: AppTheme.destructive),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onScroll() {
    // Load more when scrolled near the top
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 80) {
      context.read<ChatProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    final provider = context.read<ChatProvider>();
    provider.sendMessage(text).then((_) {
      _scrollToBottom();
      final err = provider.error;
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $err'),
              backgroundColor: AppTheme.destructive),
        );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _switchConversation(ConversationModel convo) async {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    context.read<ConversationProvider>().setActive(convo);
    setState(() => _showThreadPicker = false);
    await chatProvider.loadConversation(convo.id, accessToken: auth.accessToken);
    _scrollToBottom();
  }

  Future<void> _doSearch(String q) async {
    final convId = context.read<ChatProvider>().conversationId;
    if (convId == null || q.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await ApiService.searchMessages(convId, q.trim());
      setState(() => _searchResults = results);
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final colors = AppTheme.colorsOf(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildChatHeader(isMobile),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 24,
                        ),
                        child: Column(
                          children: [
                            _buildSkeletonMessage(isMobile, isUser: false),
                            const SizedBox(height: 16),
                            _buildSkeletonMessage(isMobile, isUser: true),
                            const SizedBox(height: 16),
                            _buildSkeletonMessage(isMobile, isUser: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildInputArea(isMobile),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildChatHeader(isMobile),
            if (_showSearch) _buildSearchBar(isMobile),
            if (_showSearch && _searchResults.isNotEmpty)
              _buildSearchResults(isMobile),
            Expanded(child: _buildMessageList(isMobile)),
            _buildInputArea(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader(bool isMobile) {
    final convProvider = context.watch<ConversationProvider>();
    final active = convProvider.activeConversation;
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
              color: AppTheme.stone200.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Thread picker button
          InkWell(
            onTap: () => setState(() => _showThreadPicker = !_showThreadPicker),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _showThreadPicker
                    ? AppTheme.stone900
                    : AppTheme.stone100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.stone200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_rounded,
                      size: 14,
                      color: _showThreadPicker
                          ? Colors.white
                          : colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    active?.displayTitle() ?? 'Global Assistant',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _showThreadPicker
                          ? Colors.white
                          : AppTheme.stone700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showThreadPicker
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 14,
                    color: _showThreadPicker
                        ? Colors.white
                        : AppTheme.stone400,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Search toggle
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              size: 20,
              color: colors.accent,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThreadPicker(bool isMobile) {
    final convProvider = context.watch<ConversationProvider>();
    final conversations = convProvider.conversations;
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
              color: AppTheme.stone200.withValues(alpha: 0.4), width: 1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text('Conversations',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.stone400,
                        letterSpacing: 1.2)),
                const Spacer(),
                if (convProvider.isLoading)
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.stone400)),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: conversations.map((c) {
                final isActive =
                    convProvider.activeConversation?.id == c.id;
                return _buildThreadItem(c, isActive);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadItem(ConversationModel convo, bool isActive) {
    final colors = AppTheme.colorsOf(context);
    IconData icon;
    switch (convo.kind) {
      case 'contact':
        icon = Icons.person_rounded;
        break;
      case 'event':
        icon = Icons.event_rounded;
        break;
      default:
        icon = Icons.smart_toy_rounded;
    }
    return InkWell(
      onTap: () => _switchConversation(convo),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.stone900.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: isActive ? colors.accent : AppTheme.stone400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                convo.displayTitle(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppTheme.stone900 : AppTheme.stone600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Icon(Icons.check_rounded, size: 14, color: colors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 8),
      color: AppTheme.stone50,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle:
                    TextStyle(color: AppTheme.stone400, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.stone200),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onSubmitted: _doSearch,
            ),
          ),
          const SizedBox(width: 8),
          if (_isSearching)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isMobile) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      color: Colors.white,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: _searchResults.length,
        itemBuilder: (context, i) {
          final m = _searchResults[i];
          final isUser = m['sender_type'] == 'user';
          return ListTile(
            dense: true,
            leading: Icon(
              isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
              size: 16,
              color: colors.accent,
            ),
            title: Text(
              (m['content'] ?? '') as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppTheme.stone700),
            ),
            onTap: () {
              setState(() {
                _showSearch = false;
                _searchResults = [];
                _searchController.clear();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageList(bool isMobile) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final messages = chat.messages;
        return Stack(
          children: [
            // Thread picker overlay
            if (_showThreadPicker)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildThreadPicker(isMobile),
              ),
            ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 8 : 12,
              ),
              itemCount: messages.length + (chat.isTyping ? 1 : 0) +
                  (chat.isLoadingHistory ? 1 : 0),
              itemBuilder: (context, index) {
                // Loading indicator at top
                if (chat.isLoadingHistory && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                final msgIndex =
                    chat.isLoadingHistory ? index - 1 : index;
                if (msgIndex == messages.length && chat.isTyping) {
                  return _buildTypingIndicator(isMobile);
                }
                if (msgIndex < 0 || msgIndex >= messages.length) {
                  return const SizedBox.shrink();
                }
                return _buildMessageBubble(messages[msgIndex], isMobile);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea(bool isMobile) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                  color: AppTheme.stone200.withValues(alpha: 0.4), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.stone50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.stone200, width: 1),
                  ),
                  child: TextField(
                    controller: _messageController,
                    enabled: !chat.isTyping,
                    decoration: InputDecoration(
                      hintText: chat.isTyping
                          ? 'Assistant is thinking...'
                          : 'Ask me anything...',
                      hintStyle: TextStyle(
                          color: AppTheme.stone400, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 12,
                      ),
                    ),
                    style: TextStyle(color: AppTheme.stone900, fontSize: 14),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: chat.isTyping ? null : _sendMessage,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isMobile ? 44 : 48,
                  height: isMobile ? 44 : 48,
                  decoration: BoxDecoration(
                    color: chat.isTyping
                        ? AppTheme.stone300
                        : AppTheme.stone900,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: chat.isTyping
                        ? []
                        : [
                            BoxShadow(
                                color: AppTheme.stone900
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                          ],
                  ),
                  child: chat.isTyping
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white)))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMobile) {
    final auth = context.read<AuthProvider>();
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                _buildAvatar(
                    icon: Icons.smart_toy_rounded,
                    color: AppTheme.stone900,
                    size: isMobile ? 32 : 36),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser ? AppTheme.stone900 : Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
                    border: message.isUser
                        ? null
                        : Border.all(
                            color: AppTheme.stone200.withValues(alpha: 0.4),
                            width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: message.isUser
                              ? Colors.white
                              : AppTheme.stone900,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: message.isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.stone400,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(
                    initials: auth.initials,
                    color: AppTheme.primary,
                    size: isMobile ? 32 : 36),
              ],
            ],
          ),
          // Message link chips (created records)
          if (!message.isUser && message.links.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                  left: (isMobile ? 32 : 36) + 8, top: 6),
              child: MessageLinkChips(links: message.links),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
      {IconData? icon,
      String? initials,
      required Color color,
      required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.5)
            : Text(
                initials ?? 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.33,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(
              icon: Icons.smart_toy_rounded,
              color: AppTheme.stone900,
              size: isMobile ? 32 : 36),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
              border: Border.all(
                  color: AppTheme.stone200.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        final opacity = (animValue * 2).clamp(0.3, 1.0);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.stone400.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSkeletonMessage(bool isMobile, {required bool isUser}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            SkeletonLoader(
              width: isMobile ? 32 : 36,
              height: isMobile ? 32 : 36,
              borderRadius: BorderRadius.circular((isMobile ? 32 : 36) * 0.28),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.stone900 : Colors.white,
                borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
                border: isUser
                    ? null
                    : Border.all(
                        color: AppTheme.stone200.withValues(alpha: 0.4),
                        width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    width: isUser ? 120 : 200,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      width: 160,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            SkeletonLoader(
              width: isMobile ? 32 : 36,
              height: isMobile ? 32 : 36,
              borderRadius: BorderRadius.circular((isMobile ? 32 : 36) * 0.28),
            ),
          ],
        ],
      ),
    );
  }
}
