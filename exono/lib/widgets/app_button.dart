import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, ghost, destructive }

enum ButtonSize { sm, md, lg }

/// Custom button widget matching CRM's button design
class AppButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool isLoading; // Alias for loading
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

  @override
  Widget build(BuildContext context) {
    final buttonChild = child ??
        Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: _getIconSize(),
                height: _getIconSize(),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_getForegroundColor()),
                ),
              )
            else if (icon != null)
              Icon(icon, size: _getIconSize()),
            if ((_isLoading || icon != null) && label != null) SizedBox(width: _getGap()),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: _getFontSize(),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _getHeight(),
      child: _buildButton(context, buttonChild),
    );
  }

  Widget _buildButton(BuildContext context, Widget child) {
    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppTheme.primary.withValues(alpha: 0.3),
            padding: _getPadding(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
            disabledBackgroundColor: AppTheme.stone300,
            disabledForegroundColor: AppTheme.stone500,
          ),
          child: child,
        );

      case ButtonVariant.secondary:
      case ButtonVariant.outline:
        return OutlinedButton(
          onPressed: _isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: variant == ButtonVariant.secondary ? AppTheme.cardBackground : null,
            foregroundColor: AppTheme.stone700,
            side: BorderSide(color: AppTheme.stone300),
            padding: _getPadding(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          child: child,
        );

      case ButtonVariant.ghost:
        return TextButton(
          onPressed: _isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.stone600,
            padding: _getPadding(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          child: child,
        );

      case ButtonVariant.destructive:
        return ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.destructive,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: _getPadding(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          child: child,
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case ButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 12);
    }
  }

  double _getHeight() {
    switch (size) {
      case ButtonSize.sm:
        return 36;
      case ButtonSize.md:
        return 40;
      case ButtonSize.lg:
        return 44;
    }
  }

  double _getFontSize() {
    switch (size) {
      case ButtonSize.sm:
        return 12;
      case ButtonSize.md:
        return 14;
      case ButtonSize.lg:
        return 14;
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.sm:
        return 16;
      case ButtonSize.md:
        return 18;
      case ButtonSize.lg:
        return 20;
    }
  }

  double _getGap() {
    switch (size) {
      case ButtonSize.sm:
        return 6;
      case ButtonSize.md:
        return 8;
      case ButtonSize.lg:
        return 8;
    }
  }

  Color _getForegroundColor() {
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.destructive:
        return Colors.white;
      case ButtonVariant.secondary:
      case ButtonVariant.outline:
      case ButtonVariant.ghost:
        return AppTheme.stone700;
    }
  }
}
