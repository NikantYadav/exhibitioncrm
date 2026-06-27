import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// One stat in an [AppStatRow]: a large value over a small uppercase label.
class AppStat {
  final String value;
  final String label;
  final Color? valueColor;

  const AppStat({required this.value, required this.label, this.valueColor});
}

/// A row of equal-width stat cells (value + uppercase label) separated by thin
/// dividers, e.g. CONTACTS / PENDING / SKIPPED / DONE on the events past card
/// and the follow-up queue summary.
///
/// Labels are scaled by a SINGLE shared factor derived from the widest label at
/// the current width, so every label renders at the exact same size and none of
/// them ever wraps to a second line on small screens. (Per-cell FittedBox would
/// shrink only the long labels, leaving cells mismatched.)
class AppStatRow extends StatelessWidget {
  final List<AppStat> stats;
  final double dividerHeight;

  const AppStatRow({super.key, required this.stats, this.dividerHeight = 28});

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final colors = context.theme.colors;

    final valueStyle = typography.xl.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.0,
    );
    final labelStyle = typography.xs.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: colors.mutedForeground,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final dividerCount = stats.length - 1;
        const dividerWidth = 1.0 + 8.0; // 1px line + 4px margin each side
        final cellWidth =
            (constraints.maxWidth - dividerWidth * dividerCount) / stats.length;

        // Find the single scale factor so the widest label fits its cell.
        double scale = 1.0;
        for (final s in stats) {
          final tp = TextPainter(
            text: TextSpan(text: s.label.toUpperCase(), style: labelStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
          if (tp.width > 0 && cellWidth > 0) {
            scale = scale.clamp(0.0, (cellWidth / tp.width).clamp(0.0, 1.0));
          }
        }

        final scaledLabelStyle = labelStyle.copyWith(
          fontSize: (labelStyle.fontSize ?? 11) * scale,
          letterSpacing: 0.8 * scale,
        );

        final children = <Widget>[];
        for (var i = 0; i < stats.length; i++) {
          final s = stats[i];
          children.add(Expanded(
            child: Column(
              children: [
                Text(
                  s.value,
                  style: valueStyle.copyWith(
                    color: s.valueColor ?? colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.label.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  style: scaledLabelStyle,
                ),
              ],
            ),
          ));
          if (i < stats.length - 1) {
            children.add(Container(
              width: 1,
              height: dividerHeight,
              color: AppTheme.colorsOf(context).border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ));
          }
        }

        return Row(children: children);
      },
    );
  }
}
