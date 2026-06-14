import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// A badge that can show an icon or an inline spinner alongside a label.
///
/// Used for the offline/syncing status indicator in the app header.
/// Backed by [FBadge] (same as AppChip) — inherits the same visual style:
/// filled rect, borderRadius 4, bold small-caps text.
///
/// Usage:
///   AppStatusBadge(label: 'OFFLINE', leading: Icon(Icons.cloud_off_rounded, size: 12))
///   AppStatusBadge(label: 'SYNCING 3', spinner: true, color: _c.accentGlow, textColor: _c.accent)
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  /// Optional leading icon. Ignored when [spinner] is true.
  final Widget? leading;

  /// When true, shows an [FCircularProgress] spinner instead of [leading].
  final bool spinner;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.leading,
    this.spinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final bg = color ?? c.surfaceElevated;
    final fg = textColor ?? c.textMuted;

    final labelWidget = Text(
      label.toUpperCase(),
      style: TextStyle(
        color: fg,
        fontWeight: FontWeight.w800,
        fontSize: 9,
        letterSpacing: 0.8,
        height: 1,
      ),
    );

    Widget? leadingWidget;
    if (spinner) {
      leadingWidget = SizedBox(
        width: 11,
        height: 11,
        child: FittedBox(
          fit: BoxFit.contain,
          child: FCircularProgress(),
        ),
      );
    } else if (leading != null) {
      leadingWidget = IconTheme(
        data: IconThemeData(color: fg, size: 10),
        child: leading!,
      );
    }

    final child = leadingWidget == null
        ? labelWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leadingWidget,
              const SizedBox(width: 5),
              labelWidget,
            ],
          );

    return FBadge(
      variant: FBadgeVariant.secondary,
      style: FBadgeStyleDelta.delta(
        decoration: DecorationDelta.boxDelta(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.transparent),
        ),
        contentStyle: FBadgeContentStyleDelta.delta(
          padding: EdgeInsetsGeometryDelta.value(
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          ),
        ),
      ),
      child: child,
    );
  }
}
