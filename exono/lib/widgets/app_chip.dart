import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// Three chip variants backed by [FBadge].
/// All share the same visual style: filled rect, borderRadius 4, bold small-caps.
///
/// AppChip('AI & Robotics')                         — filled neutral tag
/// AppChip.label('BOOTH B-04')                      — filled neutral badge
/// AppChip.status('MET', color: c.success)          — filled colored status badge
class AppChip extends StatelessWidget {
  final String label;
  final _AppChipVariant _variant;
  final Color? color;
  final Color? textColor;
  final bool ellipsis;
  final IconData? leadingIcon;

  const AppChip(
    this.label, {
    super.key,
    this.color,
    this.textColor,
    this.ellipsis = false,
    this.leadingIcon,
  }) : _variant = _AppChipVariant.tag;

  const AppChip.label(
    this.label, {
    super.key,
    this.color,
    this.textColor,
    this.ellipsis = false,
    this.leadingIcon,
  }) : _variant = _AppChipVariant.labelBadge;

  const AppChip.status(
    this.label, {
    super.key,
    required Color this.color,
    this.textColor,
    this.ellipsis = false,
    this.leadingIcon,
  }) : _variant = _AppChipVariant.status;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);

    switch (_variant) {
      case _AppChipVariant.tag:
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
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
              padding: EdgeInsetsGeometryDelta.value(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ),
          ),
          child: _buildLabel(textColor ?? c.textMuted),
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
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
              padding: EdgeInsetsGeometryDelta.value(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ),
          ),
          child: _buildLabel(textColor ?? c.textMuted),
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
          child: _buildLabel(textColor ?? c.surface),
        );
    }
  }

  Widget _buildLabel(Color textColor) {
    final text = ellipsis
        ? Text(label.toUpperCase(), overflow: TextOverflow.ellipsis, maxLines: 1)
        : Text(label.toUpperCase());
    if (leadingIcon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(leadingIcon, size: 8, color: textColor),
        const SizedBox(width: 3),
        text,
      ],
    );
  }
}

enum _AppChipVariant { tag, labelBadge, status }
