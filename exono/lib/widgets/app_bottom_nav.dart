import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';

/// Single shared bottom nav bar.
/// Layout: Home | AI Chat | [QR elevated] | Contacts | Events
///
/// selectedIndex mapping:
///   0 = Home, 1 = Events, 2 = QR/Capture, 3 = Contacts,
///   5 = Profile, 7 = AI Chat, 4 = sentinel (no tab active)
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigate;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  // Map app selectedIndex to FBottomNavigationBar 0-based index.
  // Items order: 0=Home, 1=AIChat, 2=placeholder(QR), 3=Contacts, 4=Events
  int get _forIndex {
    switch (selectedIndex) {
      case 0:
        return 0;
      case 7:
        return 1;
      case 3:
        return 3;
      case 1:
        return 4;
      default:
        return -1; // no tab active
    }
  }

  void _handleChange(int forIndex) {
    switch (forIndex) {
      case 0:
        onNavigate(0);
      case 1:
        onNavigate(7);
      case 2:
        onNavigate(2); // QR placeholder — handled by the floating button
      case 3:
        onNavigate(3);
      case 4:
        onNavigate(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    if (selectedIndex == 2) {
      return _buildScannerNav(colors, context);
    }

    final nav = FBottomNavigationBar(
      index: _forIndex,
      onChange: _handleChange,
      safeAreaBottom: true,
      children: const [
        FBottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: Text('Home'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_outlined),
          label: Text('AI Chat'),
        ),
        // Invisible placeholder so the QR floating button sits centered above it
        FBottomNavigationBarItem(
          icon: SizedBox(width: 24, height: 24),
          label: Text(''),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.group_outlined),
          label: Text('Contacts'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: Text('Events'),
        ),
      ],
    );

    // Wrap with the QR center button overlay
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        nav,
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

  Widget _buildScannerNav(ExonoColors colors, BuildContext context) {
    return FBottomNavigationBar(
      index: -1,
      onChange: _handleChange,
      safeAreaBottom: true,
      children: const [
        FBottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: Text('Home'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_outlined),
          label: Text('AI Chat'),
        ),
        FBottomNavigationBarItem(
          icon: SizedBox(width: 24, height: 24),
          label: Text(''),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.group_outlined),
          label: Text('Contacts'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: Text('Events'),
        ),
      ],
    );
  }
}
