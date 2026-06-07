import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Three chip variants, all sourced from offline_mode_screen patterns.
///
/// AppChip('AI & Robotics')                         — outlined pill tag
/// AppChip.label('BOOTH B-04')                      — filled rect badge
/// AppChip.status('MET', color: c.textSecondary)    — filled status badge
class AppChip extends StatelessWidget {
  final String label;
  final _AppChipVariant _variant;
  final Color? color;
  final Color? textColor;

  const AppChip(
    this.label, {
    super.key,
    this.color,
    this.textColor,
  }) : _variant = _AppChipVariant.tag;

  const AppChip.label(
    this.label, {
    super.key,
    this.color,
    this.textColor,
  }) : _variant = _AppChipVariant.labelBadge;

  const AppChip.status(
    this.label, {
    super.key,
    required Color this.color,
    this.textColor,
  }) : _variant = _AppChipVariant.status;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);

    switch (_variant) {
      case _AppChipVariant.tag:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color ?? c.border),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor ?? c.textMuted,
            ),
          ),
        );

      case _AppChipVariant.labelBadge:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color ?? c.surfaceElevated,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textColor ?? c.textMuted,
            ),
          ),
        );

      case _AppChipVariant.status:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textColor ?? c.surface,
            ),
          ),
        );
    }
  }
}

enum _AppChipVariant { tag, labelBadge, status }
