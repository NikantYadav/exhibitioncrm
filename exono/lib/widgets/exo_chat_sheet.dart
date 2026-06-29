import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/chat_mention.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/exo_chat_view.dart';
import '../screens/app_shell.dart' show navBarHide, navBarShow;

/// Holds the live providers for an entity's Exo conversation so it survives
/// the sheet being closed and reopened. Keyed by `type:id`.
class _ExoSession {
  final ChatProvider chat = ChatProvider();
  final ConversationProvider conv = ConversationProvider();
  _ExoSession() {
    chat.reset(loading: false);
  }
  void dispose() {
    chat.dispose();
    conv.dispose();
  }
}

/// Cache of per-entity sessions. Reopening the same entity reuses its chat;
/// only the "new chat" button (or a different entity) starts a fresh one.
final Map<String, _ExoSession> _exoSessions = {};

String _sessionKey(ChatMention e) => '${e.type}:${e.id}';

/// Disposes and clears all cached Exo conversations. Call on logout so a
/// different user never resumes the previous user's chats and realtime
/// channels do not leak.
void clearExoSessions() {
  for (final s in _exoSessions.values) {
    s.dispose();
  }
  _exoSessions.clear();
}

/// Opens the Exo chat sheet scoped to [entity].
///
/// The entity is locked into the chat as a non-removable mention. The
/// conversation persists across closes — reopening the same entity resumes the
/// same chat. A fresh chat is started only via the header's "new chat" button.
/// Deliberately uses raw [showModalBottomSheet] rather than [showAppSheet]
/// because it needs a draggable handle, custom max-extent, and its own local
/// provider scope.
Future<void> showExoSheet(
  BuildContext context, {
  required ChatMention entity,
  void Function(String)? onAddSelectionToNotes,
  List<ChatMention> initialMentions = const [],
}) {
  final session =
      _exoSessions.putIfAbsent(_sessionKey(entity), () => _ExoSession());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    useRootNavigator: true,
    builder: (_) => _ExoSheetScaffold(
      entity: entity,
      session: session,
      onAddSelectionToNotes: onAddSelectionToNotes,
      initialMentions: initialMentions,
    ),
  );
}

class _ExoSheetScaffold extends StatefulWidget {
  final ChatMention entity;
  final _ExoSession session;
  final void Function(String)? onAddSelectionToNotes;
  final List<ChatMention> initialMentions;
  const _ExoSheetScaffold({
    required this.entity,
    required this.session,
    this.onAddSelectionToNotes,
    this.initialMentions = const [],
  });

  @override
  State<_ExoSheetScaffold> createState() => _ExoSheetScaffoldState();
}

class _ExoSheetScaffoldState extends State<_ExoSheetScaffold> {
  // Provider instances are owned by the cached session, not by this widget, so
  // the conversation survives the sheet closing and reopening. They are still
  // isolated from the app-scoped singletons (the main ChatScreen).
  ChatProvider get _chat => widget.session.chat;
  ConversationProvider get _conv => widget.session.conv;

  // Bumped to force ExoChatView to rebuild from scratch on "new chat".
  int _chatViewKey = 0;
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  static const double _minSize = 0.5;
  static const double _initialSize = 0.94;
  static const double _maxSize = 0.94;

  @override
  void initState() {
    super.initState();
    navBarHide(this);
  }

  @override
  void dispose() {
    navBarShow(this);
    // Providers belong to the cached session; do NOT dispose them here.
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _startNewChat() {
    _chat.reset(loading: false);
    setState(() => _chatViewKey++);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_sheetCtrl.isAttached) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (screenHeight <= 0) return;
    final delta = -d.primaryDelta! / screenHeight;
    final next = (_sheetCtrl.size + delta).clamp(_minSize, _maxSize);
    _sheetCtrl.jumpTo(next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_sheetCtrl.isAttached) return;
    final velocity = d.primaryVelocity ?? 0;
    final current = _sheetCtrl.size;
    // Hard swipe down from the collapsed anchor dismisses the sheet.
    if (velocity > 700 && current <= _minSize + 0.02) {
      Navigator.of(context).pop();
      return;
    }
    double target;
    if (velocity < -300) {
      target = _maxSize; // swipe up → full
    } else if (velocity > 300) {
      target = _minSize; // swipe down → collapse
    } else {
      // Snap to nearest of the two anchors.
      target = (current - _minSize).abs() < (_maxSize - current).abs()
          ? _minSize
          : _maxSize;
    }
    _sheetCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    // The sheet owns its keyboard inset. showModalBottomSheet with
    // isScrollControlled:true does NOT auto-resize for the keyboard, so we lift
    // the ENTIRE sheet (its whole coordinate space) above the keyboard with a
    // bottom Padding around the DraggableScrollableSheet. Padding INSIDE the
    // fixed-height builder would instead push content past the box and overflow.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConversationProvider>.value(value: _conv),
        ChangeNotifierProvider<ChatProvider>.value(value: _chat),
      ],
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: DraggableScrollableSheet(
          controller: _sheetCtrl,
          initialChildSize: _initialSize,
          minChildSize: _minSize,
          maxChildSize: _maxSize,
          expand: false,
          builder: (ctx, _) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: ColoredBox(
                color: c.background,
                child: Column(
                  children: [
                    // Drag handle + entity header — drag gestures live here.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: _ExoSheetHeader(
                        entity: widget.entity,
                        onNewChat: _startNewChat,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: ExoChatView(
                        key: ValueKey(_chatViewKey),
                        config: ExoChatViewConfig(
                          lockedMention: widget.entity,
                          reserveBottomBarInset: false,
                          onAddSelectionToNotes: widget.onAddSelectionToNotes,
                          initialMentions: widget.initialMentions,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExoSheetHeader extends StatelessWidget {
  final ChatMention entity;
  final VoidCallback onNewChat;
  final VoidCallback onClose;

  const _ExoSheetHeader({
    required this.entity,
    required this.onNewChat,
    required this.onClose,
  });

  IconData get _icon {
    switch (entity.type) {
      case 'contact':
        return Icons.person_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'company':
        return Icons.business_rounded;
      default:
        return Icons.alternate_email_rounded;
    }
  }

  String get _typeLabel {
    switch (entity.type) {
      case 'contact':
        return 'Contact';
      case 'event':
        return 'Event';
      case 'company':
        return 'Company';
      default:
        return 'Item';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    // System-blue header background with white content, in both light and dark.
    const onAccent = Colors.white;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: c.accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: onAccent.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Entity header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: onAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: onAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Exo',
                          style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onAccent,
                            height: 1.2,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icon,
                                size: 12,
                                color: onAccent.withValues(alpha: 0.85)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$_typeLabel: ${entity.displayName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.theme.typography.xs.copyWith(
                                  color: onAccent.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined,
                        size: 19, color: onAccent),
                    tooltip: 'New chat',
                    onPressed: onNewChat,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: onAccent),
                    onPressed: onClose,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
