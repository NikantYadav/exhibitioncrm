import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum AppFilterRowStyle {
  /// Outlined pills — active item gets a white/textPrimary border.
  /// Used in offline_mode_screen (reference).
  outline,

  /// Filled pills — active item gets accent background fill.
  /// Used in dashboard_screen.
  filled,
}

/// Horizontal scrollable pill-filter row.
/// Sourced from offline_mode_screen's `_buildFilterRow` pattern.
///
/// AppFilterRow(
///   filters: ['All', 'Must Meet', 'Met', 'Remaining'],
///   selected: _selectedFilter,
///   onSelect: (f) => setState(() => _selectedFilter = f),
/// )
class AppFilterRow extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelect;
  final AppFilterRowStyle style;
  final EdgeInsetsGeometry? padding;

  const AppFilterRow({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelect,
    this.style = AppFilterRowStyle.outline,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isActive = filter == selected;
          return _FilterChip(
            label: filter,
            isActive: isActive,
            style: style,
            onTap: () => onSelect(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final AppFilterRowStyle style;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: _decoration(c),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: style == AppFilterRowStyle.filled ? 10 : 11,
            fontWeight: style == AppFilterRowStyle.filled
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: style == AppFilterRowStyle.filled ? 0.9 : 1.2,
            color: _textColor(c),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(ExonoColors c) {
    switch (style) {
      case AppFilterRowStyle.outline:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? c.textPrimary : c.border,
          ),
        );
      case AppFilterRowStyle.filled:
        return BoxDecoration(
          color: isActive ? c.accent : c.accentSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? c.accent.withValues(alpha: 0.4) : c.border,
          ),
        );
    }
  }

  Color _textColor(ExonoColors c) {
    switch (style) {
      case AppFilterRowStyle.outline:
        return isActive ? c.textPrimary : c.textMuted;
      case AppFilterRowStyle.filled:
        return isActive
            ? (c.isDark ? c.background : Colors.white)
            : c.textSecondary;
    }
  }
}
