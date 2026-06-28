import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Renders AI briefing output where **bold** lines are section headings
/// and everything else is body text. Handles both the new `**Label**\nbody`
/// format and legacy `LABEL: body` single-line format gracefully.
class BriefingBody extends StatelessWidget {
  final List<String> lines;
  final Color accentColor;

  const BriefingBody({super.key, required this.lines, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final widgets = <Widget>[];
    bool prevWasHeading = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final isHeading = line.startsWith('**') && line.endsWith('**') && line.length > 4;

      if (isHeading) {
        final label = line.substring(2, line.length - 2).trim();
        if (widgets.isNotEmpty && !prevWasHeading) {
          widgets.add(const SizedBox(height: 14));
        }
        widgets.add(Text(
          label,
          style: theme.typography.sm.copyWith(
            fontWeight: FontWeight.w700,
            color: accentColor,
            height: 1.3,
          ),
        ));
        widgets.add(const SizedBox(height: 4));
        prevWasHeading = true;
      } else {
        widgets.add(Text(
          line,
          style: theme.typography.sm.copyWith(
            color: theme.colors.mutedForeground,
            height: 1.55,
          ),
        ));
        prevWasHeading = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
