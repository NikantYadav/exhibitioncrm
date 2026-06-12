import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, ghost, destructive, branded }

enum ButtonSize { sm, md, lg }

/// Thin wrapper over [FButton] that preserves existing call-sites unchanged.
class AppButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final Widget? prefixIcon;
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
    this.prefixIcon,
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
      case ButtonVariant.branded:
        return FButtonVariant.primary;
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
    // Branded variant: blue bg + white text (light) / white bg + blue text (dark).
    if (variant == ButtonVariant.branded) {
      final c = AppTheme.colorsOf(context);
      final t = context.theme;
      final isDark = c.isDark;
      final bg = isDark ? Colors.white : c.accent;
      final fg = isDark ? c.accent : Colors.white;

      Widget content;
      if (_isLoading) {
        content = SizedBox(width: 16, height: 16, child: FCircularProgress());
      } else if (prefixIcon != null) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(data: IconThemeData(color: fg, size: 16), child: prefixIcon!),
            const SizedBox(width: 6),
            Text(label!, style: t.typography.sm.copyWith(fontWeight: FontWeight.w600, color: fg)),
          ],
        );
      } else if (child != null) {
        content = child!;
      } else {
        content = Text(label!, style: t.typography.sm.copyWith(fontWeight: FontWeight.w600, color: fg));
      }

      final btn = GestureDetector(
        onTap: _isLoading ? null : onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: content),
        ),
      );

      if (fullWidth) return SizedBox(width: double.infinity, child: btn);
      return btn;
    }

    // Ghost variant: FButton.ghost renders white text on light backgrounds.
    // Render manually so the text always uses mutedForeground — readable on any bg.
    if (variant == ButtonVariant.ghost) {
      return Builder(builder: (ctx) {
        final t = ctx.theme;
        final fg = t.colors.mutedForeground;
        Widget ghostContent;
        if (child != null) {
          ghostContent = child!;
        } else if (_isLoading) {
          ghostContent = const SizedBox(width: 16, height: 16, child: FCircularProgress());
        } else if (prefixIcon != null) {
          ghostContent = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(data: IconThemeData(color: fg, size: 16), child: prefixIcon!),
              const SizedBox(width: 6),
              Text(label!, style: t.typography.sm.copyWith(color: fg, fontWeight: FontWeight.w500)),
            ],
          );
        } else {
          ghostContent = Text(label!, style: t.typography.sm.copyWith(color: fg, fontWeight: FontWeight.w500));
        }
        final btn = GestureDetector(
          onTap: _isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(child: ghostContent),
          ),
        );
        if (fullWidth) return SizedBox(width: double.infinity, child: btn);
        return btn;
      });
    }

    Widget content;
    if (child != null) {
      content = child!;
    } else if (_isLoading) {
      content = const SizedBox(width: 16, height: 16, child: FCircularProgress());
    } else if (prefixIcon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [prefixIcon!, const SizedBox(width: 6), Text(label!)],
      );
    } else {
      content = Text(label!);
    }

    Widget btn = FButton(
      variant: _variant,
      size: _size,
      onPress: _isLoading ? null : onPressed,
      child: content,
    );

    // Outline buttons inherit secondaryForeground for their text/icon color.
    // Since secondaryForeground is white (for the filled secondary button),
    // we locally override it to primary (blue) so outline text reads correctly.
    if (variant == ButtonVariant.outline) {
      btn = Builder(builder: (ctx) {
        final t = ctx.theme;
        final colors = t.colors.copyWith(secondaryForeground: t.colors.primary);
        return FTheme(
          data: FThemeData(colors: colors, touch: true),
          child: FButton(
            variant: _variant,
            size: _size,
            onPress: _isLoading ? null : onPressed,
            child: content,
          ),
        );
      });
    }

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}
