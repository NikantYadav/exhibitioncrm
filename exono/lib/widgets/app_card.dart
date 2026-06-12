import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool elevated;
  final Color? borderColor;
  final List<BoxShadow>? extraShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.elevated = false,
    this.borderColor,
    this.extraShadow,
  });

  @override
  Widget build(BuildContext context) {
    // If caller wants a custom border color or shadow, apply a delta on top of the forui theme style.
    if (borderColor != null || extraShadow != null) {
      final baseStyle = context.theme.cardStyle;
      final baseDeco = baseStyle.decoration as ShapeDecoration?;
      final newDeco = ShapeDecoration(
        color: baseDeco?.color,
        shape: baseDeco?.shape ?? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none,
        ),
        shadows: extraShadow,
      );
      return FCard.raw(
        style: FCardStyleDelta.delta(decoration: DecorationDelta.value(newDeco)),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      );
    }

    return FCard.raw(
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
