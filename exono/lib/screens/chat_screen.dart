import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/offline_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/app_offline_screen.dart';
import '../widgets/exo_chat_view.dart';
import 'app_shell.dart' show navBarHide, navBarShow;
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
    with ScreenLogger, WidgetsBindingObserver {
  ExonoColors get _c => AppTheme.colorsOf(context);

  @override
  void initState() {
    super.initState();
    navBarHide();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !widget.isNewChat) {
      context.read<ChatProvider>().resync();
    }
  }

  @override
  void dispose() {
    navBarShow();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initConversation() async {
    final convProvider = context.read<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();

    if (widget.isNewChat) {
      chatProvider.reset(loading: false);
      convProvider.setActive(null);
      // initialMessage auto-send is handled by ExoChatView via config.
      return;
    }

    await convProvider.loadConversations();

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
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
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
          AppHeaderActionButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
          const SizedBox(width: 10),
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
                        ? ConversationModel(id: '', updatedAt: DateTime.now())
                            .displayTitle(firstMessageSnippet: firstUserMsg)
                        : 'Exo');
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
            Expanded(
              child: ExoChatView(
                config: ExoChatViewConfig(
                  initialMessage: widget.initialMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
