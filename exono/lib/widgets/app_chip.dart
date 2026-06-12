import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// Three chip variants backed by [FBadge].
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
        return FBadge(
          variant: FBadgeVariant.outline,
          style: FBadgeStyleDelta.delta(
            decoration: DecorationDelta.shapeDelta(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(color: color ?? c.border),
              ),
              color: Colors.transparent,
            ),
            contentStyle: FBadgeContentStyleDelta.delta(
              labelTextStyle: TextStyleDelta.delta(
                color: textColor ?? c.textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
              padding: EdgeInsetsGeometryDelta.value(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ),
          ),
          child: Text(label.toUpperCase()),
        );

      case _AppChipVariant.labelBadge:
        return FBadge(
          variant: FBadgeVariant.secondary,
          style: FBadgeStyleDelta.delta(
            decoration: DecorationDelta.boxDelta(
              color: color ?? c.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.transparent),
            ),
            contentStyle: FBadgeContentStyleDelta.delta(
              labelTextStyle: TextStyleDelta.delta(
                color: textColor ?? c.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
              padding: EdgeInsetsGeometryDelta.value(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ),
          ),
          child: Text(label.toUpperCase()),
        );

      case _AppChipVariant.status:
        return FBadge(
          variant: FBadgeVariant.primary,
          style: FBadgeStyleDelta.delta(
            decoration: DecorationDelta.boxDelta(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.transparent),
            ),
            contentStyle: FBadgeContentStyleDelta.delta(
              labelTextStyle: TextStyleDelta.delta(
                color: textColor ?? c.surface,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
              padding: EdgeInsetsGeometryDelta.value(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ),
          ),
          child: Text(label.toUpperCase()),
        );
    }
  }
}

enum _AppChipVariant { tag, labelBadge, status }
