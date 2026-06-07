import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Drop-in card component. Wraps [child] in the standard navy-gradient card
/// decoration. Pass [padding] to avoid a separate Container wrapper.
///
/// Usage:
///   AppCard(padding: EdgeInsets.all(16), child: ...)
///   AppCard(radius: 28, child: ...)
///   AppCard(elevated: true, child: ...)   // slightly raised surface
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
    this.radius = AppTheme.radiusCard,
    this.elevated = false,
    this.borderColor,
    this.extraShadow,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration deco = AppTheme.cardDecoration(
      context,
      radius: radius,
      elevated: elevated,
    );

    if (borderColor != null || extraShadow != null) {
      deco = deco.copyWith(
        border: borderColor != null ? Border.all(color: borderColor!) : deco.border,
        boxShadow: extraShadow,
      );
    }

    return Container(
      padding: padding,
      decoration: deco,
      child: child,
    );
  }
}
