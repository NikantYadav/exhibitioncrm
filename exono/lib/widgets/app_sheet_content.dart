import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Standard bottom-sheet content wrapper.
///
/// Handles: drag handle, title + optional subtitle, scrollable body,
/// keyboard avoidance, and safe-area insets — so individual sheets only
/// supply their fields and actions.
///
/// Usage:
/// ```dart
/// showAppSheet(
///   context: context,
///   builder: (ctx) => AppSheetContent(
///     title: 'New Company',
///     subtitle: 'Fill in details below.',
///     child: Column(children: [...fields, AppButton(...)]),
///   ),
/// );
/// ```
class AppSheetContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const AppSheetContent({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Keyboard avoidance is handled centrally by `showAppSheet` (it pads the
    // sheet by the keyboard inset). Do NOT add `viewInsets.bottom` here or the
    // keyboard is counted twice and the sheet rides up into the status bar.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: context.theme.typography.xl.copyWith(
                fontWeight: FontWeight.w600,
                color: context.theme.colors.foreground,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: context.theme.typography.xs
                    .copyWith(color: context.theme.colors.mutedForeground),
              ),
            ],
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
