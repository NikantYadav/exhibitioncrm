import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/offline_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_offline_screen.dart';
import '../widgets/skeleton_loader.dart';
import 'chat_screen.dart';
import 'app_shell.dart' show appNavBarHidden;
import '../utils/screen_logger.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().loadConversations();
    });
  }

  void _openChat(ConversationModel convo) {
    if (_navigating) return;
    _navigating = true;
    context.read<ChatProvider>().reset();
    context.read<ConversationProvider>().setActive(convo);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    ).whenComplete(() {
      _navigating = false;
      // Restore the nav bar on return — the chat screen hides it on entry and
      // its dispose can race the pop, leaving it hidden on this screen.
      appNavBarHidden.value = false;
    });
  }

  void _startNewChat() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => const ChatScreen(isNewChat: true)),
    ).whenComplete(() => appNavBarHidden.value = false);
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
    if (!context.watch<OfflineProvider>().isOnline) {
      return const AppOfflineScreen(title: 'Chat History');
    }
    final convProvider = context.watch<ConversationProvider>();
    final conversations = convProvider.conversations;

    return ColoredBox(
      color: context.theme.colors.background,
      child: Column(
        children: [
          const AppHeader(),
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
    return AppButton(
      label: 'NEW CHAT',
      onPressed: _startNewChat,
      variant: ButtonVariant.primary,
      prefixIcon: const Icon(Icons.add_rounded, size: 20),
      fullWidth: true,
    );
  }

  Widget _chatItem(ConversationModel convo) {
    final (icon, iconBg) = (Icons.auto_awesome_outlined, _c.accentSoft);

    return Dismissible(
      key: ValueKey(convo.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteConversation(convo);
        return false;
      },
      background: Container(
        decoration: BoxDecoration(
          color: _c.destructive.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _c.destructive.withValues(alpha: 0.28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: _c.destructive, size: 20),
            const SizedBox(width: 8),
            Text(
              'DELETE',
              style: context.theme.typography.xs.copyWith(
                color: _c.destructive,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _openChat(convo),
        behavior: HitTestBehavior.opaque,
        child: AppCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
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
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.foreground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(convo.updatedAt),
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
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
                  style: context.theme.typography.lg.copyWith(
                    color: context.theme.colors.foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start a new chat to ask about contacts,\nevents, or anything in your CRM.',
                  textAlign: TextAlign.center,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
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
