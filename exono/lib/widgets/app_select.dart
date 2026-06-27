import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import 'app_feedback.dart';

/// A custom dropdown field: shows the selected option's label with a chevron,
/// and opens a bottom sheet of selectable rows on tap. Built from the app's own
/// primitives (no raw forui `FSelect`) so the selected row reads correctly —
/// white text on the accent fill — matching the option-picker pattern used
/// elsewhere in the app.
///
/// ```dart
/// AppSelect<String>(
///   value: channel,
///   items: const {'Email': 'email', 'Call': 'call', 'Manual': 'manual'},
///   onChanged: (v) => setState(() => channel = v),
/// )
/// ```
class AppSelect<T> extends StatelessWidget {
  final String? hint;
  final T? value;
  final Map<String, T> items;
  final ValueChanged<T?> onChanged;
  // Optional sheet title; defaults to "Select".
  final String? sheetTitle;

  const AppSelect({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.sheetTitle,
  });

  String? get _selectedLabel {
    for (final e in items.entries) {
      if (e.value == value) return e.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final label = _selectedLabel;
    final isPlaceholder = label == null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.theme.colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? (hint ?? 'Select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.typography.sm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPlaceholder
                      ? context.theme.colors.mutedForeground
                      : context.theme.colors.foreground,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: context.theme.colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.theme.colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                sheetTitle ?? 'Select',
                style: ctx.theme.typography.lg.copyWith(
                    fontWeight: FontWeight.w700, color: ctx.theme.colors.foreground),
              ),
              const SizedBox(height: 12),
              // Options scroll within the sheet's height cap so a long list (or a
              // short screen) never overflows; the handle/title stay pinned.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in items.entries) ...[
                        _OptionRow(
                          label: e.key,
                          isSelected: e.value == value,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            if (e.value != value) onChanged(e.value);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    // Selected: accent fill with white text. Unselected: surface with foreground.
    final bg = isSelected ? c.accent : c.surfaceAlt;
    final fg = isSelected ? Colors.white : context.theme.colors.foreground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? c.accent : context.theme.colors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w600, color: fg),
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}
