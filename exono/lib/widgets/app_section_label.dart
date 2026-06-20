import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// Small uppercase section label used inside cards.
/// Matches the "PREPARED NOTES" / "AI PREP NOTES" pattern in offline_mode_screen.
///
/// AppSectionLabel('Prepared Notes')
/// AppSectionLabel('AI Prep Notes', color: c.accent)
class AppSectionLabel extends StatelessWidget {
  final String label;
  final Color? color;
  final double letterSpacing;

  const AppSectionLabel(
    this.label, {
    super.key,
    this.color,
    this.letterSpacing = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return Text(
      label.toUpperCase(),
      style: context.theme.typography.xs.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
        color: color ?? c.textMuted,
      ),
    );
  }
}
