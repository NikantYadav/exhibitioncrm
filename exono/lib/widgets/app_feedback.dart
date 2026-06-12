import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
  return showFSheet<T>(
    context: context,
    side: side,
    // forui sizes sheets via mainAxisMaxRatio; null lets tall content scroll.
    mainAxisMaxRatio: isScrollControlled ? null : 9 / 16,
    builder: (ctx) {
      // showFSheet has no implicit background; wrap here so callers never need ColoredBox.
      final bg = ctx.theme.colors.background;
      return ColoredBox(color: bg, child: builder(ctx));
    },
  );
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
  );
}
