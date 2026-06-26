import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';

// Imported lazily via a function reference to avoid a circular import.
// The notifier lives in app_shell.dart.
import '../screens/app_shell.dart' show navBarHide, navBarShow;

/// ForUI sheet / toast / dialog helpers.
///
/// These replace the raw `showModalBottomSheet`, `ScaffoldMessenger.showSnackBar`,
/// and `showDialog` call-sites with one-liners that already use the forui APIs.
/// Migration becomes find-and-replace instead of rewriting each call.

/// Bottom sheet. Replaces `showModalBottomSheet(... )`.
///
/// Before:
///   showModalBottomSheet(context: context, builder: (_) => MySheet());
/// After:
///   showAppSheet(context: context, builder: (ctx) => MySheet());
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  FLayout side = FLayout.btt,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
}) {
  navBarHide();
  // Read the system bottom inset from the raw FlutterView. This value is never
  // consumed by an ancestor SafeArea/Scaffold, so it is reliable on Android
  // edge-to-edge (where `MediaQuery.padding.bottom` can already be 0) as well as
  // iOS. We restate it as `padding.bottom` inside the sheet so each builder's
  // `SafeArea(bottom: true)` lifts content above the system nav bar / home
  // indicator. Falls back to whatever padding the sheet already has if larger.
  final view = View.of(context);
  final bottomInset = view.viewPadding.bottom / view.devicePixelRatio;
  return showFSheet<T>(
    context: context,
    side: side,
    useRootNavigator: useRootNavigator,
    mainAxisMaxRatio: isScrollControlled ? null : 9 / 16,
    builder: (ctx) {
      final bg = ctx.theme.colors.background;
      final mq = MediaQuery.of(ctx);
      return MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: mq.padding.bottom < bottomInset ? bottomInset : mq.padding.bottom,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(color: bg, child: builder(ctx)),
        ),
      );
    },
  ).whenComplete(navBarShow);
}

/// Toast / snackbar. Replaces `ScaffoldMessenger.of(context).showSnackBar(...)`.
///
/// Before:
///   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
/// After:
///   showAppToast(context, 'Saved');
void showAppToast(
  BuildContext context,
  String message, {
  String? description,
  FToastVariant variant = FToastVariant.primary,
}) {
  showFToast(
    context: context,
    title: Text(message),
    description: description != null ? Text(description) : null,
    variant: variant,
  );
}

/// Confirm dialog. Replaces `showDialog(... AlertDialog ...)`.
///
/// Returns true if the confirm action was tapped, false/null otherwise.
///
/// Before:
///   final ok = await showDialog(context: context, builder: (_) => AlertDialog(...));
/// After:
///   final ok = await showAppConfirmDialog(
///     context: context,
///     title: 'Delete event?',
///     message: 'This cannot be undone.',
///     confirmLabel: 'Delete',
///     destructive: true,
///   );
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  navBarHide();
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, _) => FDialog(
      title: Text(title),
      body: message != null ? Text(message) : null,
      actions: [
        FButton(
          variant: FButtonVariant.outline,
          onPress: () => Navigator.pop(ctx, false),
          child: Builder(
            // Cancel: blue (accent) text on the outline button.
            builder: (bCtx) => Text(
              cancelLabel,
              style: TextStyle(color: AppTheme.colorsOf(bCtx).accent),
            ),
          ),
        ),
        if (destructive)
          // Destructive confirm: solid red fill + white text. forui's
          // destructive variant is only a tinted fill, so we recolor a primary
          // button via a localised FTheme (primary -> red, foreground -> white).
          Builder(
            builder: (bCtx) {
              final red = AppTheme.colorsOf(bCtx).destructive;
              return FTheme(
                // Rebuild the theme with primary recoloured to red so the
                // primary button renders a solid red fill with white text.
                data: FThemeData(
                  colors: bCtx.theme.colors.copyWith(
                    primary: red,
                    primaryForeground: Colors.white,
                  ),
                  touch: true,
                ),
                child: FButton(
                  onPress: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
              );
            },
          )
        else
          FButton(
            onPress: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  ).whenComplete(navBarShow);
}

/// Dialog wrapper that hides the live bar while open. Use this instead of
/// calling [showFDialog] directly in screens.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext, FDialogStyle, Animation<double>) builder,
  bool barrierDismissible = true,
}) {
  navBarHide();
  return showFDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  ).whenComplete(navBarShow);
}
