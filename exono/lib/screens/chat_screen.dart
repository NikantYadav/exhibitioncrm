import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickPrompts = const [
    'Pending follow-ups',
    'Search contacts',
    'Prep next event',
  ];

  late final List<_ChatEntry> _messages = [
    const _ChatEntry(
      sender: _ChatSender.ai,
      text:
          'Good morning. I\'ve analyzed your upcoming schedule. You have a meeting with the Operations team in 2 hours. Would you like me to prepare the latest performance metrics or search your recent contacts for follow-ups?',
      time: '09:12 AM',
    ),
    const _ChatEntry(
      sender: _ChatSender.user,
      text:
          'Show me the contact details for Marcus Thorne. We met last week at the summit.',
      time: '09:14 AM',
    ),
    const _ChatEntry(
      sender: _ChatSender.ai,
      text:
          'I found Marcus Thorne in your recent interactions. You met him 6 days ago during the Neo-Tech Summit.',
      time: '09:14 AM',
      contactCard: _InlineContactCard(
        initials: 'MT',
        name: 'Marcus Thorne',
        title: 'VP of Strategic Operations',
        metLabel: 'Met 6 days ago',
      ),
    ),
    const _ChatEntry(
      sender: _ChatSender.user,
      text:
          'Great. Set a follow-up task to send him the EXONO system deck by EOD.',
      time: '09:15 AM',
    ),
    const _ChatEntry(
      sender: _ChatSender.ai,
      text:
          'Task created. "Send EXONO Deck to Marcus Thorne" scheduled for today at 5:00 PM. I will notify you 30 minutes prior.',
      time: '09:15 AM',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handlePromptTap(String prompt) {
    setState(() {
      _messageController.text = prompt;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
  }

  void _sendMessage([String? preset]) {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final timestamp = _formatTime(TimeOfDay.now());

    setState(() {
      _messages.add(
        _ChatEntry(sender: _ChatSender.user, text: text, time: timestamp),
      );
      _messageController.clear();
      _messages.add(
        _ChatEntry(
          sender: _ChatSender.ai,
          text: _buildAiReply(text),
          time: timestamp,
        ),
      );
    });

    _scrollToBottom();
  }

  String _buildAiReply(String userText) {
    final normalized = userText.toLowerCase();

    if (normalized.contains('follow')) {
      return 'I surfaced your pending follow-ups and prioritized the ones most likely to convert based on recent interaction signals.';
    }
    if (normalized.contains('contact')) {
      return 'I can search your recent contacts, filter by event context, and pull the highest-signal relationship details into the thread.';
    }
    if (normalized.contains('event') || normalized.contains('prep')) {
      return 'I prepared a concise event brief with likely attendees, open follow-ups, and the strongest talking points for the next meeting block.';
    }

    return 'Understood. I\'ve captured that request and prepared the next best action path based on your current network context.';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) => Navigator.of(context).pop(),
      ),
      body: ColoredBox(
        color: _c.background,
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

  Widget _buildTopBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EXONO AI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: _c.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _c.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _c.textPrimary,
                        height: 1.27,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushReplacementNamed('/mode-selection'),
                icon: Icon(Icons.close, color: _c.textPrimary, size: 22),
                splashRadius: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCanvas() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 124),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.sender == _ChatSender.user;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  width: message.contactCard != null && !isUser
                      ? double.infinity
                      : null,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.transparent : _c.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUser ? _c.textPrimary : _c.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isUser ? _c.textPrimary : _c.textSecondary,
                          height: 1.43,
                        ),
                      ),
                      if (message.contactCard != null) ...[
                        const SizedBox(height: 16),
                        _buildInlineContactCard(message.contactCard!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    message.time,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _c.borderStrong,
                      height: 1.27,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInlineContactCard(_InlineContactCard card) {
    return InkWell(
      onTap: () => _showUiOnlyMessage('Open contact details for ${card.name}.'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _c.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              alignment: Alignment.center,
              child: Text(
                card.initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _c.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _c.textMuted,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.history, size: 14, color: _c.borderStrong),
                      const SizedBox(width: 4),
                      Text(
                        card.metLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: _c.borderStrong,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: _c.borderStrong),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          decoration: BoxDecoration(
            color: _c.background.withValues(alpha: 0.95),
            border: Border(top: BorderSide(color: _c.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final prompt = _quickPrompts[index];
                    return OutlinedButton(
                      onPressed: () => _handlePromptTap(prompt),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _c.textMuted,
                        side: BorderSide(color: _c.border),
                        backgroundColor: _c.surfaceAlt,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(prompt),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -54,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: InkWell(
                        onTap: () =>
                            _showUiOnlyMessage('Scanner is UI-only for now.'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _c.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: _c.textPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _c.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _showUiOnlyMessage(
                            'Voice input is UI-only for now.',
                          ),
                          icon: Icon(
                            Icons.mic_none_rounded,
                            color: _c.borderStrong,
                          ),
                          splashRadius: 20,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            onSubmitted: (_) => _sendMessage(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _c.textPrimary,
                            ),
                            cursorColor: _c.textPrimary,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Ask anything...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: _c.border,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilledButton(
                            onPressed: _sendMessage,
                            style: FilledButton.styleFrom(
                              backgroundColor: _c.textPrimary,
                              foregroundColor: _c.background,
                              minimumSize: const Size(40, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.arrow_upward, size: 20),
                          ),
                        ),
                      ],
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
}

enum _ChatSender { ai, user }

class _ChatEntry {
  final _ChatSender sender;
  final String text;
  final String time;
  final _InlineContactCard? contactCard;

  const _ChatEntry({
    required this.sender,
    required this.text,
    required this.time,
    this.contactCard,
  });
}

class _InlineContactCard {
  final String initials;
  final String name;
  final String title;
  final String metLabel;

  const _InlineContactCard({
    required this.initials,
    required this.name,
    required this.title,
    required this.metLabel,
  });
}
