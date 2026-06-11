import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final String? actionTooltip;
  final Widget? actionWidget;
  final bool showProfile;

  const AppHeader({
    super.key,
    this.onNotificationPressed,
    this.onActionPressed,
    this.actionIcon,
    this.actionTooltip,
    this.actionWidget,
    this.showProfile = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final auth = context.read<AuthProvider>();
    final name = auth.displayName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'EXONO',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: colors.textPrimary,
              height: 1,
            ),
          ),
          const Spacer(),
          if (actionWidget != null)
            actionWidget!
          else if (actionIcon != null)
            IconButton(
              onPressed: onActionPressed,
              tooltip: actionTooltip,
              icon: Icon(actionIcon, color: colors.accent, size: 22),
              splashRadius: 20,
            ),
          if (showProfile) GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.accent, colors.accentStrong],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.isDark ? colors.background : Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
