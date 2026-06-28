import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:forui/forui.dart';
import '../utils/markdown_normalize.dart';

/// Renders AI briefing output as GitHub-flavored markdown so headings, lists
/// and **tables** all render correctly. Bold lines that act as section headings
/// (`**Label**`) are rendered with the accent color via the `strong` style.
///
/// Input is the briefing as a list of lines (split on `\n`); they are rejoined
/// and normalized so table blocks parse reliably.
class BriefingBody extends StatelessWidget {
  final List<String> lines;
  final Color accentColor;

  const BriefingBody({super.key, required this.lines, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final data = normalizeMarkdownTables(lines.join('\n'));

    return MarkdownBody(
      data: data,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: theme.typography.sm.copyWith(
          color: theme.colors.mutedForeground,
          height: 1.55,
        ),
        // Bold lines act as accent-colored section headings.
        strong: theme.typography.sm.copyWith(
          fontWeight: FontWeight.w700,
          color: accentColor,
          height: 1.3,
        ),
        em: theme.typography.sm.copyWith(
          color: theme.colors.mutedForeground,
          fontStyle: FontStyle.italic,
          height: 1.55,
        ),
        h1: theme.typography.lg.copyWith(
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
        h2: theme.typography.sm.copyWith(
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
        h3: theme.typography.sm.copyWith(
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
        listBullet: theme.typography.sm.copyWith(
          color: theme.colors.mutedForeground,
          height: 1.55,
        ),
        tableHead: theme.typography.sm.copyWith(
          color: theme.colors.foreground,
          fontWeight: FontWeight.w700,
        ),
        tableBody: theme.typography.sm.copyWith(
          color: theme.colors.foreground,
          height: 1.5,
        ),
        tableBorder: TableBorder.all(color: theme.colors.border, width: 1),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        blockquote: theme.typography.sm.copyWith(
          color: theme.colors.mutedForeground,
          fontStyle: FontStyle.italic,
          height: 1.55,
        ),
      ),
    );
  }
}
