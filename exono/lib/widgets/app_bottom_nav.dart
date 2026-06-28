import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// Single shared bottom nav bar.
/// Layout: Home | AI Chat | [QR elevated] | Contacts | Events
///
/// selectedIndex mapping:
///   0 = Home, 1 = Events, 2 = QR/Capture, 3 = Contacts,
///   5 = Profile, 7 = AI Chat, 4 = sentinel (no tab active)
///
/// This is a fully custom bar (NOT forui's `FBottomNavigationBar`). forui's bar
/// hardcodes its bottom inset as `viewPadding.bottom * 2/3` plus an internal
/// SafeArea, which rendered inconsistently across devices (extra space on iOS,
/// the bar sliding under the system nav on some Android devices). We replicate
/// forui's exact visual style (top border, background, icon/label colors, sizes,
/// spacing) but add NO system bottom inset — the bar sits flush against the very
/// bottom of the screen on every device, by design.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigate;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  // Items, left-to-right. Index 2 (QR) is an invisible placeholder so the
  // floating QR button sits centered above it. `appIndex` is the value passed
  // back to onNavigate; null means non-tappable placeholder.
  static const _items = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, label: 'Home', appIndex: 0),
    _NavItem(icon: Icons.auto_awesome_outlined, label: 'AI Chat', appIndex: 7),
    _NavItem(icon: null, label: '', appIndex: null), // QR placeholder
    _NavItem(icon: Icons.group_outlined, label: 'Contacts', appIndex: 3),
    _NavItem(icon: Icons.calendar_today_outlined, label: 'Events', appIndex: 4),
  ];

  // Which item index (0-based, left-to-right) is highlighted for the current
  // app selectedIndex. -1 = no tab active (e.g. scanner / detail routes).
  int get _activeItem {
    switch (selectedIndex) {
      case 0:
        return 0; // Home
      case 7:
        return 1; // AI Chat
      case 3:
        return 3; // Contacts
      case 1:
        return 4; // Events
      default:
        return -1;
    }
  }

  void _onTapItem(_NavItem item) {
    switch (item.appIndex) {
      case 0:
        onNavigate(0);
      case 7:
        onNavigate(7);
      case 3:
        onNavigate(3);
      case 4:
        onNavigate(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final theme = context.theme;
    final activeItem = selectedIndex == 2 ? -1 : _activeItem;

    final bar = _buildBar(context, theme, activeItem);

    // When the scanner is active there is no elevated QR button overlay.
    if (selectedIndex == 2) return bar;

    // Wrap with the QR center button overlay.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        bar,
        Positioned(
          top: -14,
          child: GestureDetector(
            onTap: () => onNavigate(2),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.softShadow(context),
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: colors.isDark ? Colors.black : Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(BuildContext context, FThemeData theme, int activeItem) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: theme.style.borderWidth,
          ),
        ),
      ),
      child: Padding(
        // Zero system bottom inset by design: the bar sits flush against the
        // very bottom of the screen (no home-indicator / nav-bar gap). Only
        // forui's base 5px item band is kept around the row.
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final (i, item) in _items.indexed)
              Expanded(
                child: _buildItem(context, theme, item, selected: i == activeItem),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    FThemeData theme,
    _NavItem item, {
    required bool selected,
  }) {
    // Placeholder slot under the floating QR button: keep the same footprint
    // (24px icon box) so spacing matches the other items, but render nothing.
    if (item.icon == null) {
      return const Padding(
        padding: EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [SizedBox(width: 24, height: 24)],
        ),
      );
    }

    final color = selected ? theme.colors.primary : theme.colors.mutedForeground;
    // forui: label is typography.xs3 with height 1.5; selected = bold.
    final textStyle = theme.typography.xs3.copyWith(
      color: color,
      height: 1.5,
      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTapItem(item),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 24,
              color: color,
              // forui bumps the selected icon to weight 700.
              weight: selected ? 700 : null,
            ),
            const SizedBox(height: 2), // forui item spacing
            Text(
              item.label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String label;
  final int? appIndex;

  const _NavItem({required this.icon, required this.label, required this.appIndex});
}
