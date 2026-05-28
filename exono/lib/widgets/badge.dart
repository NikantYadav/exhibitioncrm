import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Badge variants matching the design system
enum BadgeVariant {
  default_,
  success,
  warning,
  error,
  info,
  outline,
}

/// Badge widget matching CRM's badge design
/// Fully rounded pills with semantic colors
class Badge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const Badge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.default_,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(9999), // fully rounded
        border: variant == BadgeVariant.outline
            ? Border.all(color: AppTheme.stone300, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: colors.foreground,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _getColors() {
    switch (variant) {
      case BadgeVariant.success:
        return _BadgeColors(
          background: const Color(0xFFD1FAE5), // green-100
          foreground: const Color(0xFF065F46), // green-800
        );
      case BadgeVariant.warning:
        return _BadgeColors(
          background: const Color(0xFFFEF3C7), // amber-100
          foreground: const Color(0xFF92400E), // amber-800
        );
      case BadgeVariant.error:
        return _BadgeColors(
          background: const Color(0xFFFEE2E2), // red-100
          foreground: const Color(0xFF991B1B), // red-800
        );
      case BadgeVariant.info:
        return _BadgeColors(
          background: const Color(0xFFDBEAFE), // blue-100
          foreground: const Color(0xFF1E40AF), // blue-800
        );
      case BadgeVariant.outline:
        return _BadgeColors(
          background: Colors.transparent,
          foreground: AppTheme.stone700,
        );
      case BadgeVariant.default_:
        return _BadgeColors(
          background: AppTheme.stone100,
          foreground: AppTheme.stone700,
        );
    }
  }
}

class _BadgeColors {
  final Color background;
  final Color foreground;

  _BadgeColors({
    required this.background,
    required this.foreground,
  });
}
