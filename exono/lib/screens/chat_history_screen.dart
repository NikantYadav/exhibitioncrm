import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/skeleton_loader.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().loadConversations();
    });
  }

  void _openChat(ConversationModel convo) async {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    context.read<ConversationProvider>().setActive(convo);

    await chatProvider.loadConversation(convo.id, accessToken: auth.accessToken);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ChatScreen(),
        ),
      );
    }
  }

  void _startNewChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatScreen(isNewChat: true),
      ),
    );
  }

  Future<void> _deleteConversation(ConversationModel convo) async {
    final colors = AppTheme.colorsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete chat?',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently remove this conversation.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    color: colors.destructive,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context
          .read<ConversationProvider>()
          .deleteConversation(convo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final convProvider = context.watch<ConversationProvider>();
    final conversations = convProvider.conversations;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.accent, size: 20),
        ),
        title: Text(
          'Assistant History',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => convProvider.loadConversations(),
            icon: Icon(Icons.refresh_rounded, color: colors.accent),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildNewChatButton(colors),
          Expanded(
            child: convProvider.isLoading && conversations.isEmpty
                ? _buildHistorySkeleton(colors)
                : conversations.isEmpty
                    ? _buildEmptyState(colors)
                    : _buildHistoryList(conversations, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton(ExonoColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: InkWell(
        onTap: _startNewChat,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: colors.textPrimary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: colors.background, size: 20),
              const SizedBox(width: 10),
              Text(
                'Start New Session',
                style: TextStyle(
                  color: colors.background,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ExonoColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: colors.textMuted.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No chat history yet',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to see it here.',
            style: TextStyle(
              color: colors.textMuted.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<ConversationModel> conversations, ExonoColors colors) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: conversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final convo = conversations[index];
        return _buildHistoryItem(convo, colors);
      },
    );
  }

  Widget _buildHistoryItem(ConversationModel convo, ExonoColors colors) {
    IconData icon;
    Color iconColor;
    switch (convo.kind) {
      case 'contact':
        icon = Icons.person_rounded;
        iconColor = Colors.blue;
        break;
      case 'event':
        icon = Icons.event_rounded;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.smart_toy_rounded;
        iconColor = colors.accent;
    }

    return Dismissible(
      key: ValueKey(convo.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteConversation(convo);
        // Return false — _deleteConversation handles removal via provider
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.destructive.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: colors.destructive, size: 22),
      ),
      child: InkWell(
        onTap: () => _openChat(convo),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      convo.displayTitle(),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(convo.updatedAt),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: colors.destructive.withValues(alpha: 0.6), size: 20),
                onPressed: () => _deleteConversation(convo),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Today, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Widget _buildHistorySkeleton(ExonoColors colors) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              SkeletonLoader(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      width: double.infinity,
                      height: 15,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SkeletonLoader(
                width: 20,
                height: 20,
                borderRadius: BorderRadius.circular(10),
              ),
            ],
          ),
        );
      },
    );
  }
}
