import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

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
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    }
  }

  void _startNewChat() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => const ChatScreen(isNewChat: true)),
    );
  }

  Future<void> _deleteConversation(ConversationModel convo) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete chat?',
      message: 'This will permanently remove this conversation.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed == true && mounted) {
      await context.read<ConversationProvider>().deleteConversation(convo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final convProvider = context.watch<ConversationProvider>();
    final conversations = convProvider.conversations;

    return ColoredBox(
      color: context.theme.colors.background,
      child: Column(
        children: [
          AppHeader(
            actionIcon: Icons.refresh_rounded,
            actionTooltip: 'Refresh',
            onActionPressed: () => convProvider.loadConversations(),
          ),
          Expanded(
            child: convProvider.isLoading && conversations.isEmpty
                ? _skeleton()
                : conversations.isEmpty
                    ? _emptyState()
                    : _list(conversations),
          ),
        ],
      ),
    );
  }

  Widget _list(List<ConversationModel> conversations) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _newChatButton(),
        const SizedBox(height: 24),
        const AppSectionLabel('Recent Chats'),
        const SizedBox(height: 10),
        ...conversations.map((convo) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _chatItem(convo),
        )),
      ],
    );
  }

  Widget _newChatButton() {
    return GestureDetector(
      onTap: _startNewChat,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_c.accent, _c.accentStrong],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'NEW CHAT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatItem(ConversationModel convo) {
    final (icon, iconBg) = _iconForKind(convo.kind);

    return Dismissible(
      key: ValueKey(convo.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteConversation(convo);
        return false;
      },
      background: AppCard(
        padding: const EdgeInsets.only(right: 20),
        radius: 16,
        borderColor: _c.destructive.withValues(alpha: 0.3),
        child: Align(
          alignment: Alignment.centerRight,
          child: Icon(Icons.delete_outline_rounded, color: _c.destructive, size: 20),
        ),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: 16,
        child: GestureDetector(
          onTap: () => _openChat(convo),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _c.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      convo.displayTitle(),
                      style: TextStyle(
                        color: _c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(convo.updatedAt),
                      style: TextStyle(
                        color: _c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteConversation(convo),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      color: _c.destructive.withValues(alpha: 0.5), size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconForKind(String kind) {
    switch (kind) {
      case 'contact':
        return (Icons.person_outline_rounded, _c.accentSoft);
      case 'event':
        return (Icons.calendar_today_outlined, _c.accentSoft);
      default:
        return (Icons.auto_awesome_outlined, _c.accentSoft);
    }
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _newChatButton(),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _c.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.auto_awesome_outlined, color: _c.accent, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'No chats yet',
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start a new chat to ask about contacts,\nevents, or anything in your CRM.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _c.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SkeletonLoader(width: double.infinity, height: 52, borderRadius: BorderRadius.circular(999)),
        const SizedBox(height: 24),
        SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(3)),
        const SizedBox(height: 10),
        for (int i = 0; i < 6; i++) ...[
          _skeletonItem(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _skeletonItem() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Row(
        children: [
          SkeletonLoader(width: 42, height: 42, borderRadius: BorderRadius.circular(12)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                SkeletonLoader(width: 80, height: 11, borderRadius: BorderRadius.circular(3)),
              ],
            ),
          ),
        ],
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
}
