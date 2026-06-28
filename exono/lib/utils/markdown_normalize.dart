/// Normalizes AI-generated markdown so GitHub-flavored tables render reliably.
///
/// The `flutter_markdown` GFM table parser requires a blank line *before* a
/// table block (a run of `| ... |` rows). AI output frequently writes the table
/// immediately after a paragraph with no separating blank line, which makes the
/// parser treat the pipes as ordinary inline text. This helper inserts the
/// required blank lines around table blocks so the table is recognized.
String normalizeMarkdownTables(String input) {
  final lines = input.split('\n');
  final out = <String>[];

  bool isTableRow(String s) {
    final t = s.trim();
    return t.startsWith('|') && t.endsWith('|') && t.length > 1;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final prev = out.isNotEmpty ? out.last : '';

    // Entering a table block: ensure a blank line separates it from a
    // preceding non-blank, non-table line.
    if (isTableRow(line) &&
        !isTableRow(prev) &&
        prev.trim().isNotEmpty) {
      out.add('');
    }

    // Leaving a table block: ensure a blank line separates it from a
    // following non-blank, non-table line.
    if (!isTableRow(line) &&
        line.trim().isNotEmpty &&
        isTableRow(prev)) {
      out.add('');
    }

    out.add(line);
  }

  return out.join('\n');
}
