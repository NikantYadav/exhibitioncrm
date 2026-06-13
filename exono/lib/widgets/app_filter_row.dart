import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

enum AppFilterRowStyle {
  /// Outlined pills — active item gets textPrimary border.
  outline,

  /// Filled pills — active item gets accent background fill.
  filled,
}

/// Horizontal scrollable pill-filter row backed by [FButton].
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
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          final filter = filters[index];
          final isActive = filter == selected;
          return _FilterPill(
            label: filter,
            isActive: isActive,
            rowStyle: style,
            onTap: () => onSelect(filter),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final AppFilterRowStyle rowStyle;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.rowStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);

    // For outline style: active = outline variant (bordered), inactive = ghost.
    // For filled style: active = primary (accent fill), inactive = ghost.
    final FButtonVariant variant;
    if (rowStyle == AppFilterRowStyle.filled) {
      variant = isActive ? FButtonVariant.primary : FButtonVariant.ghost;
    } else {
      // outline row: use a custom decorated container for precise pill styling
      return _outlinePill(context, c);
    }

    return FButton(
      variant: variant,
      size: FButtonSizeVariant.sm,
      onPress: onTap,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: isActive
              ? Colors.white
              : c.textSecondary,
        ),
      ),
    );
  }

  /// Outline-style pill rendered as an [InkWell] + [AnimatedContainer] so we
  /// keep the exact Exono look (border-only active state, no fill).
  Widget _outlinePill(BuildContext context, ExonoColors c) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? c.textPrimary : c.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: isActive ? c.textPrimary : c.textMuted,
          ),
        ),
      ),
    );
  }
}
