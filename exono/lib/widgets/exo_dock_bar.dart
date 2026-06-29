import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../models/chat_mention.dart';
import '../utils/safe_area_insets.dart';
import 'exo_chat_sheet.dart';

/// Collapsed "Ask Exo" bar that floats pinned at the bottom of detail screens.
///
/// Tap or drag up to open the [ExoChatSheet] scoped to [entity].
/// Place inside a [Stack] with [Positioned(left:0, right:0, bottom:0)].
class ExoDockBar extends StatelessWidget {
  final ChatMention entity;

  /// When set, AI message bubbles in the Exo sheet expose an "Add to notes"
  /// text-selection action that calls this with the selected text.
  final void Function(String selectedText)? onAddSelectionToNotes;

  /// Mentions pre-seeded into the composer when the sheet opens (removable).
  final List<ChatMention> initialMentions;

  const ExoDockBar({
    super.key,
    required this.entity,
    this.onAddSelectionToNotes,
    this.initialMentions = const [],
  });

  void _open(BuildContext context) {
    showExoSheet(
      context,
      entity: entity,
      onAddSelectionToNotes: onAddSelectionToNotes,
      initialMentions: initialMentions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    // Light mode: system-blue bar with white content.
    // Dark mode: white bar with system-blue content.
    final barColor = c.isDark ? Colors.white : c.accent;
    final fgColor = c.isDark ? c.accent : Colors.white;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, bottomBarInset(context, extra: 12)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        onVerticalDragEnd: (d) {
          // Upward flick opens the sheet.
          if ((d.primaryVelocity ?? 0) < 0) _open(context);
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.keyboard_arrow_up_rounded, color: fgColor, size: 22),
              const SizedBox(width: 8),
              Icon(Icons.auto_awesome_rounded, color: fgColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ask Exo about ${entity.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
