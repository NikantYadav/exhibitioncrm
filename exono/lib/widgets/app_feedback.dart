import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

// Imported lazily via a function reference to avoid a circular import.
// The notifier lives in app_shell.dart.
import '../screens/app_shell.dart' show appNavBarHidden;

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
}) {
  appNavBarHidden.value = true;
  return showFSheet<T>(
    context: context,
    side: side,
    mainAxisMaxRatio: isScrollControlled ? null : 9 / 16,
    builder: (ctx) {
      final bg = ctx.theme.colors.background;
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(color: bg, child: builder(ctx)),
      );
    },
  ).whenComplete(() => appNavBarHidden.value = false);
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
  appNavBarHidden.value = true;
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, _) => FDialog(
      title: Text(title),
      body: message != null ? Text(message) : null,
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FButton(
          variant: destructive ? FButtonVariant.destructive : FButtonVariant.primary,
          onPress: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  ).whenComplete(() => appNavBarHidden.value = false);
}

/// Dialog wrapper that hides the live bar while open. Use this instead of
/// calling [showFDialog] directly in screens.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext, FDialogStyle, Animation<double>) builder,
  bool barrierDismissible = true,
}) {
  appNavBarHidden.value = true;
  return showFDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  ).whenComplete(() => appNavBarHidden.value = false);
}
