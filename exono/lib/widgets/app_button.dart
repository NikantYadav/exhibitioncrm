import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, ghost, destructive, branded }

enum ButtonSize { xs, sm, md, lg }

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
  final Color? labelColor;

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
    this.labelColor,
  }) : assert(label != null || child != null, 'Either label or child must be provided');

  bool get _isLoading => loading || isLoading;

  // Label text that never overflows: kept to a single line and scaled down to
  // fit the available width when the button is narrow (small screens, long
  // labels like "FOLLOWED UP" in a cramped Row). FittedBox with scaleDown only
  // shrinks — it never enlarges past the intrinsic size — so buttons with room
  // are unaffected. Applied centrally here so every screen benefits.
  Widget _label(String text, {TextStyle? style}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    );
  }

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

  // xs reuses forui's sm geometry, then tightens padding via _xsStyle below.
  bool get _isXs => size == ButtonSize.xs;

  FButtonSizeVariant get _size {
    switch (size) {
      case ButtonSize.xs:
      case ButtonSize.sm:
        return FButtonSizeVariant.sm;
      case ButtonSize.md:
        return FButtonSizeVariant.md;
      case ButtonSize.lg:
        return FButtonSizeVariant.lg;
    }
  }

  // Tighten the sm geometry for xs: smaller content padding.
  FButtonStyleDelta get _styleDelta => _isXs
      ? FButtonStyleDelta.delta(
          contentStyle: FButtonContentStyleDelta.delta(
            padding: const EdgeInsetsGeometryDelta.value(
              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        )
      : const FButtonStyleDelta.context();

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
            Flexible(child: _label(label!, style: t.typography.sm.copyWith(fontWeight: FontWeight.w600, color: fg))),
          ],
        );
      } else if (child != null) {
        content = child!;
      } else {
        content = _label(label!, style: t.typography.sm.copyWith(fontWeight: FontWeight.w600, color: fg));
      }

      return GestureDetector(
        onTap: _isLoading ? null : onPressed,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: content),
        ),
      );
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
              Flexible(child: _label(label!, style: t.typography.sm.copyWith(color: fg, fontWeight: FontWeight.w500))),
            ],
          );
        } else {
          ghostContent = _label(label!, style: t.typography.sm.copyWith(color: fg, fontWeight: FontWeight.w500));
        }
        final btn = GestureDetector(
          onTap: _isLoading ? null : onPressed,
          child: Padding(
            padding: _isXs
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      // Inside the Row, the label is Flexible so it scales down via FittedBox on
      // narrow buttons. The Row itself is NOT wrapped in Flexible: FButton takes
      // this widget as its direct child, which has no Flex parent, so a bare
      // Flexible there throws a ParentData/semantics assertion.
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [prefixIcon!, const SizedBox(width: 6), Flexible(child: _label(label!))],
      );
    } else {
      // _label's FittedBox(scaleDown) already prevents overflow. Do NOT wrap in
      // Flexible here: this is FButton's direct child (no Flex parent), and a
      // bare Flexible triggers the '!semantics.parentDataDirty' assertion.
      content = _label(label!);
    }

    Widget btn = FButton(
      variant: _variant,
      size: _size,
      style: _styleDelta,
      onPress: _isLoading ? null : onPressed,
      child: content,
    );

    // Outline buttons inherit secondaryForeground for their text/icon color.
    // Since secondaryForeground is white (for the filled secondary button),
    // we locally override it to primary (blue) so outline text reads correctly.
    if (variant == ButtonVariant.outline) {
      btn = Builder(builder: (ctx) {
        final t = ctx.theme;
        final c = AppTheme.colorsOf(ctx);
        // forui's outline button fills with `secondary` on hover/press. Our theme
        // sets secondary == accent (blue), which made the whole button turn blue.
        // Override secondary to the soft accent tint so the hover/press state is a
        // light tinted fill with blue text in both light and dark mode.
        final colors = t.colors.copyWith(
          secondary: c.accentSoft,
          secondaryForeground: labelColor ?? t.colors.primary,
        );
        return FTheme(
          data: FThemeData(colors: colors, touch: true),
          child: FButton(
            variant: _variant,
            size: _size,
            style: _styleDelta,
            onPress: _isLoading ? null : onPressed,
            child: content,
          ),
        );
      });
    }

    // Destructive renders through the SAME FButton path as primary (so it sizes
    // identically), with a theme override forcing solid red fill + white text.
    // The native forui destructive style uses muted pink/red, which reads too
    // soft for a delete action.
    if (variant == ButtonVariant.destructive) {
      btn = Builder(builder: (ctx) {
        final t = ctx.theme;
        final colors = t.colors.copyWith(
          primary: Colors.red,
          primaryForeground: Colors.white,
        );
        return FTheme(
          data: FThemeData(colors: colors, touch: true),
          child: FButton(
            variant: FButtonVariant.primary,
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
