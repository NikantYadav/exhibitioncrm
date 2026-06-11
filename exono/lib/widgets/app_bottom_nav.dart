import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Single shared bottom nav bar used across all mobile screens.
/// Layout: Home | AI Chat | [QR] | Contacts | Events
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigate;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final showLabels = selectedIndex != 2;

    if (selectedIndex == 2) {
      return _buildScannerNav(colors, context);
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.navBackground.withValues(alpha: colors.isDark ? 0.97 : 0.94),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.85), width: 1),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: showLabels ? 66 : 66,
          child: Row(
            children: [
              Expanded(
                child: _item(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  isActive: selectedIndex == 0,
                  showLabel: showLabels,
                  onTap: () => onNavigate(0),
                  colors: colors,
                ),
              ),
              Expanded(
                child: _item(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI Chat',
                  isActive: selectedIndex == 7,
                  showLabel: showLabels,
                  onTap: () => onNavigate(7),
                  colors: colors,
                ),
              ),
              SizedBox(
                width: 78,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: InkWell(
                      onTap: () => onNavigate(2),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [colors.accent, colors.accentStrong],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppTheme.softShadow(context),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: colors.isDark ? colors.background : Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _item(
                  icon: Icons.group_outlined,
                  label: 'Contacts',
                  isActive: selectedIndex == 3,
                  showLabel: showLabels,
                  onTap: () => onNavigate(3),
                  colors: colors,
                ),
              ),
              Expanded(
                child: _item(
                  icon: Icons.calendar_today_outlined,
                  label: 'Events',
                  isActive: selectedIndex == 1,
                  showLabel: showLabels,
                  onTap: () => onNavigate(1),
                  colors: colors,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerNav(ExonoColors colors, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.navBackground.withValues(alpha: colors.isDark ? 0.97 : 0.94),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.85), width: 1),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              Expanded(child: _item(icon: Icons.home_outlined, label: 'Home', isActive: false, showLabel: true, onTap: () => onNavigate(0), colors: colors)),
              Expanded(child: _item(icon: Icons.auto_awesome_outlined, label: 'AI Chat', isActive: false, showLabel: true, onTap: () => onNavigate(7), colors: colors)),
              Expanded(child: _item(icon: Icons.group_outlined, label: 'Contacts', isActive: false, showLabel: true, onTap: () => onNavigate(3), colors: colors)),
              Expanded(child: _item(icon: Icons.calendar_today_outlined, label: 'Events', isActive: false, showLabel: true, onTap: () => onNavigate(1), colors: colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool showLabel,
    required VoidCallback onTap,
    required ExonoColors colors,
  }) {
    final color = isActive ? colors.accent : colors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            if (showLabel) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
