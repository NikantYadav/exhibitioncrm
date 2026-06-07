import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final String? actionTooltip;
  final Widget? actionWidget;

  const AppHeader({
    super.key,
    this.onNotificationPressed,
    this.onActionPressed,
    this.actionIcon,
    this.actionTooltip,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

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
              icon: Icon(actionIcon, color: colors.textPrimary, size: 22),
              splashRadius: 20,
            ),
          IconButton(
            onPressed: onNotificationPressed,
            tooltip: 'Notifications',
            icon: Icon(Icons.notifications_none_rounded, color: colors.textPrimary, size: 22),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
