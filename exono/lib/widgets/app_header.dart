import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_provider.dart';
import 'app_status_badge.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final String? actionTooltip;
  final Widget? actionWidget;
  final bool showProfile;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    this.onActionPressed,
    this.actionIcon,
    this.actionTooltip,
    this.actionWidget,
    this.showProfile = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isDark = colors.isDark;
    final auth = context.read<AuthProvider>();
    final name = auth.displayName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final offline = context.watch<OfflineProvider>();

    // Build suffix children, then wrap in a Row with consistent 8px gaps.
    final suffixChildren = <Widget>[
      // Offline / syncing badge — first so it appears left of action/profile.
      if (offline.state != SyncState.online || offline.pendingCount > 0)
        _buildStatusBadge(context, offline, colors),
      if (actionWidget != null)
        actionWidget!
      else if (actionIcon != null)
        AppHeaderActionButton(
          icon: Icons.add_rounded,
          onPressed: onActionPressed,
        ),
      if (showProfile) _ProfileButton(initial: initial, isDark: isDark, colors: colors),
    ];

    final suffixRow = suffixChildren.isEmpty
        ? const SizedBox.shrink()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < suffixChildren.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                suffixChildren[i],
              ],
            ],
          );

    final logo = SvgPicture.asset(
      isDark ? 'assets/images/logo-black.svg' : 'assets/images/logo-white.svg',
      width: 28,
      height: 28,
      fit: BoxFit.contain,
    );

    if (onBack != null) {
      return FHeader.nested(
        title: const SizedBox.shrink(),
        prefixes: [
          _HeaderActionFHeaderAction(icon: Icons.arrow_back_rounded, onPress: onBack!),
          Padding(padding: const EdgeInsets.only(left: 8), child: logo),
        ],
        suffixes: [suffixRow],
      );
    }

    return FHeader.nested(
      title: const SizedBox.shrink(),
      prefixes: [logo],
      suffixes: [suffixRow],
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    OfflineProvider offline,
    ExonoColors c,
  ) {
    switch (offline.state) {
      case SyncState.offline:
        return AppStatusBadge(
          label: 'OFFLINE',
          color: context.theme.colors.muted,
          textColor: context.theme.colors.mutedForeground,
          leading: const Icon(Icons.cloud_off_rounded, size: 10),
        );
      case SyncState.syncing:
        return AppStatusBadge(
          label: offline.pendingCount > 0
              ? 'SYNCING ${offline.pendingCount}'
              : 'SYNCING',
          spinner: true,
          color: c.accentGlow,
          textColor: c.accent,
        );
      case SyncState.online:
        // pendingCount > 0 but not yet syncing (queued ops waiting).
        return AppStatusBadge(
          label: 'PENDING ${offline.pendingCount}',
          color: context.theme.colors.muted,
          textColor: context.theme.colors.mutedForeground,
          leading: const Icon(Icons.schedule_rounded, size: 10),
        );
    }
  }
}

/// Shared 34×34 outline action button — matches profile button size exactly.
/// Used for back buttons in all screens (follow_ups, pre_event_prep, contact_detail, live screens).
class AppHeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const AppHeaderActionButton({super.key, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.theme.colors.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: context.theme.colors.foreground),
      ),
    );
  }
}

/// Same 34×34 outline style for use inside FHeader.nested prefix slots.
class _HeaderActionFHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPress;

  const _HeaderActionFHeaderAction({required this.icon, required this.onPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPress,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.theme.colors.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: context.theme.colors.foreground),
      ),
    );
  }
}


// ── Profile avatar button ─────────────────────────────────────────────────────

class _ProfileButton extends StatelessWidget {
  final String initial;
  final bool isDark;
  final ExonoColors colors;
  const _ProfileButton({required this.initial, required this.isDark, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.accent, colors.accentStrong],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: context.theme.typography.sm.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
