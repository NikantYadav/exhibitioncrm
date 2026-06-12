import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum ButtonVariant { primary, secondary, outline, ghost, destructive }

enum ButtonSize { sm, md, lg }

/// Thin wrapper over [FButton] that preserves existing call-sites unchanged.
class AppButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    this.label,
    this.child,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.loading = false,
    this.isLoading = false,
    this.fullWidth = false,
  }) : assert(label != null || child != null, 'Either label or child must be provided');

  bool get _isLoading => loading || isLoading;

  FButtonVariant get _variant {
    switch (variant) {
      case ButtonVariant.primary:
        return FButtonVariant.primary;
      case ButtonVariant.secondary:
        return FButtonVariant.secondary;
      case ButtonVariant.outline:
        return FButtonVariant.outline;
      case ButtonVariant.ghost:
        return FButtonVariant.ghost;
      case ButtonVariant.destructive:
        return FButtonVariant.destructive;
    }
  }

  FButtonSizeVariant get _size {
    switch (size) {
      case ButtonSize.sm:
        return FButtonSizeVariant.sm;
      case ButtonSize.md:
        return FButtonSizeVariant.md;
      case ButtonSize.lg:
        return FButtonSizeVariant.lg;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (child != null) {
      content = child!;
    } else if (_isLoading) {
      content = const SizedBox(
        width: 16,
        height: 16,
        child: FCircularProgress(),
      );
    } else {
      content = Text(label!);
    }

    final btn = FButton(
      variant: _variant,
      size: _size,
      onPress: _isLoading ? null : onPressed,
      child: content,
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}
