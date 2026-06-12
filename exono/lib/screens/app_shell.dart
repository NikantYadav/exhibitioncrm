import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/live_bar.dart';
import '../utils/screen_logger.dart';

// Maps route path → AppBottomNav index
int tabIndexForPath(String location) {
  if (location.startsWith('/events'))    return 1;
  if (location.startsWith('/contacts'))  return 3;
  if (location.startsWith('/follow-ups')) return 4;
  if (location.startsWith('/profile'))   return 5;
  if (location.startsWith('/meetings'))  return 6;
  if (location.startsWith('/chat-history')) return 7;
  if (location.startsWith('/chat'))        return 7;
  return 0; // '/'
}

const _tabPaths = {
  0: '/',
  1: '/events',
  3: '/contacts',
  4: '/follow-ups',
  5: '/profile',
  6: '/meetings',
  7: '/chat-history',
};

// Only these paths show the mobile bottom nav bar
const _navBarPaths = {'/', '/events', '/contacts', '/profile', '/chat-history', '/chat'};
// Paths where bottom nav + live bar should be hidden
bool _isNoNavPath(String location) => location == '/chat' || location.startsWith('/chat?') || location.startsWith('/chat/');

/// Lets a descendant screen (e.g. an in-page detail view that lives on an
/// allowed route) temporarily hide the shell's bottom nav bar.
final ValueNotifier<bool> appNavBarHidden = ValueNotifier<bool>(false);

/// Incremented each time the capture screen is popped — listeners can refresh.
final ValueNotifier<int> captureReturnSignal = ValueNotifier<int>(0);

class AppShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);
  bool _sidebarCollapsed = false;

  int get _tabIndex => tabIndexForPath(widget.location);

  void _onNav(int index) {
    if (index == 2) {
      context.push('/capture').then((_) {
        captureReturnSignal.value++;
      });
      return;
    }
    final path = _tabPaths[index] ?? '/';
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      backgroundColor: _c.background,
      body: DecoratedBox(
        decoration: AppTheme.appBackground(context),
        child: isMobile ? _mobile() : _desktop(),
      ),
      bottomNavigationBar: isMobile
          && _navBarPaths.any((p) => widget.location == p || widget.location.startsWith('$p?'))
          && !_isNoNavPath(widget.location)
          ? ValueListenableBuilder<bool>(
              valueListenable: appNavBarHidden,
              builder: (_, hidden, __) {
                if (hidden) return const SizedBox.shrink();
                final isHome = widget.location == '/' || widget.location.startsWith('/?');
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isHome && !widget.location.startsWith('/profile'))
                      LiveBar(
                        onTap: () => context.go('/live-event'),
                      ),
                    AppBottomNav(selectedIndex: _tabIndex, onNavigate: _onNav),
                  ],
                );
              },
            )
          : null,
    );
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────

  Widget _mobile() => SafeArea(bottom: false, child: widget.child);

  // ── Desktop ────────────────────────────────────────────────────────────────

  Widget _desktop() {
    return Row(
      children: [
        _sidebar(),
        Expanded(
          child: Column(
            children: [
              _topBar(),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebar() {
    final w = _sidebarCollapsed ? 80.0 : 260.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      width: w,
      decoration: BoxDecoration(
        color: _c.surface.withValues(alpha: _c.isDark ? 0.92 : 0.86),
        border: Border(right: BorderSide(color: _c.border.withValues(alpha: 0.8))),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          _brand(),
          const SizedBox(height: 20),
          FDivider(),
          const SizedBox(height: 8),
          _collapseToggle(),
          const SizedBox(height: 8),
          Expanded(child: _navList()),
          _bottomSection(),
        ],
      ),
    );
  }

  Widget _brand() {
    if (_sidebarCollapsed) {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_c.accent, _c.accentStrong]),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text('E', style: TextStyle(color: _c.isDark ? _c.background : Colors.white,
            fontSize: 18, fontWeight: FontWeight.w800)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_c.accent, _c.accentStrong]),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('E', style: TextStyle(color: _c.isDark ? _c.background : Colors.white,
                fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text('exono', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              letterSpacing: -0.5, color: _c.textPrimary)),
        ],
      ),
    );
  }

  Widget _collapseToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(_sidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                  size: 18, color: _c.textMuted),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 10),
                Text('Collapse', style: TextStyle(fontSize: 13, color: _c.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _navList() {
    final items = [
      _NavEntry(0, Icons.home_outlined, 'Home', '/'),
      _NavEntry(7, Icons.auto_awesome_outlined, 'AI Chat', '/chat-history'),
      _NavEntry(2, Icons.qr_code_scanner_rounded, 'Capture', '/capture'),
      _NavEntry(3, Icons.group_outlined, 'Contacts', '/contacts'),
      _NavEntry(1, Icons.calendar_today_outlined, 'Events', '/events'),
      _NavEntry(4, Icons.mail_outlined, 'Follow-Ups', '/follow-ups'),
      _NavEntry(6, Icons.event_note_rounded, 'Meetings', '/meetings'),
    ];
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 12),
      children: items.map(_navItem).toList(),
    );
  }

  Widget _navItem(_NavEntry e) {
    final active = _tabIndex == e.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _onNav(e.index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? _c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(e.icon, size: 18, color: active ? _c.accent : _c.textMuted),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 10),
                Text(e.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? _c.accent : _c.textSecondary,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final auth = context.read<AuthProvider>();
    final name = auth.displayName.trim();
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _c.navBackground,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: Row(
        children: [
          Text(
            _pathLabel(widget.location),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.textPrimary),
          ),
          const Spacer(),
          if (name.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _c.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_c.accent, _c.accentStrong]),
                  ),
                  alignment: Alignment.center,
                  child: Text(name[0].toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: _c.isDark ? _c.background : Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(name, style: TextStyle(fontSize: 13, color: _c.textPrimary, fontWeight: FontWeight.w500)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _bottomSection() {
    final isProfileActive = widget.location.startsWith('/profile');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        FDivider(),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => context.go('/profile'),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(Icons.settings_outlined, size: 18, color: isProfileActive ? _c.accent : _c.textMuted),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Text('Settings', style: TextStyle(fontSize: 13, color: _c.textMuted)),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _pathLabel(String loc) {
    if (loc.startsWith('/events'))     return 'Events';
    if (loc.startsWith('/contacts'))   return 'Contacts';
    if (loc.startsWith('/follow-ups')) return 'Follow-Ups';
    if (loc.startsWith('/profile'))    return 'Profile';
    if (loc.startsWith('/meetings'))   return 'Meetings';
    return 'Home';
  }
}

class _NavEntry {
  final int index;
  final IconData icon;
  final String label;
  final String path;
  const _NavEntry(this.index, this.icon, this.label, this.path);
}
