import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../router.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/live_bar.dart';
import '../utils/screen_logger.dart';

// Maps route path → AppBottomNav index
int tabIndexForPath(String location) {
  if (location.startsWith('/events'))    return 1;
  if (location.startsWith('/contacts'))  return 3;
  if (location.startsWith('/follow-ups')) return 4;
  if (location.startsWith('/profile'))   return 5;
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
  7: '/chat-history',
};

// Only these paths show the mobile bottom nav bar
const _navBarPaths = {'/', '/events', '/contacts', '/profile', '/chat-history', '/chat'};
// Paths where bottom nav + live bar should be hidden
bool _isNoNavPath(String location) => location == '/chat' || location.startsWith('/chat?') || location.startsWith('/chat/');

/// Tracks which overlays/screens currently want the nav bar hidden. The nav bar
/// is hidden whenever the set is non-empty.
///
/// We key on an identity token per requester (one per open sheet or pushed
/// full-screen route) instead of a bare counter. A counter desyncs when a
/// requester hides via a `postFrameCallback` but shows synchronously in
/// `dispose()` (or vice versa): if `dispose()` runs before the scheduled hide
/// fires, the show decrements first and the late hide then leaves the counter
/// stuck at 1 with no owner left to balance it — the nav bar stays hidden until
/// a hot reload resets the global. A token set is order-independent and
/// idempotent: a late `navBarHide(token)` followed by no further calls is
/// impossible because the same token's `navBarShow` always removes it, and a
/// duplicate hide/show with the same token is a no-op. So hide/show can fire in
/// any order across frames and the set always converges correctly.
final Set<Object> _navHideTokens = <Object>{};
final ValueNotifier<bool> appNavBarHidden = ValueNotifier<bool>(false);

/// Hide the nav bar on behalf of [token]. Pass a stable per-requester object
/// (e.g. the State instance, or a fresh `Object()` for a sheet) and pass the
/// SAME token to [navBarShow]. Calling twice with one token is harmless.
void navBarHide([Object? token]) {
  _navHideTokens.add(token ?? _legacyToken);
  _applyNavHidden();
}

/// Show the nav bar on behalf of [token] (removes that token's hide request).
/// The bar reappears only once every requester has shown.
void navBarShow([Object? token]) {
  _navHideTokens.remove(token ?? _legacyToken);
  _applyNavHidden();
}

/// Pushes the current hidden state to [appNavBarHidden].
///
/// `navBarShow` is frequently called from a `State.dispose()`, which Flutter
/// runs inside `finalizeTree()` while the widget tree is LOCKED. Writing
/// `appNavBarHidden.value` there synchronously notifies the
/// `ValueListenableBuilder` in the shell, which calls `markNeedsBuild()` — and
/// that throws "setState()/markNeedsBuild() called when widget tree was locked".
/// The throw aborts the notifier's value change, so the nav bar gets stranded in
/// whatever (hidden) state it was in until a hot reload — exactly the reported
/// bug. To avoid this we detect a locked/in-frame phase and defer the value
/// write to a post-frame callback (where building is allowed again); outside a
/// frame we apply it immediately so there is no flicker.
void _applyNavHidden() {
  final target = _navHideTokens.isNotEmpty;
  final phase = SchedulerBinding.instance.schedulerPhase;
  final treeLocked = phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks;
  if (treeLocked) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Re-read the live set: more hide/show calls may have landed before this
      // fires, so always push the latest converged state.
      appNavBarHidden.value = _navHideTokens.isNotEmpty;
    });
  } else {
    appNavBarHidden.value = target;
  }
}

/// Shared token for legacy callers that hide/show without passing one. They are
/// strictly nested (sheets: hide then whenComplete-show), so a single shared
/// token is safe — the last show clears it.
final Object _legacyToken = Object();

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
    // Defensive: pop any imperatively-pushed routes off the shell's nested
    // navigator before go_router navigates. (Full-screen detail screens now
    // push onto the root navigator, so this is normally a no-op.)
    final shellNav = shellNavigatorKey.currentState;
    if (shellNav != null) {
      shellNav.popUntil((route) => route.isFirst);
    }
    final path = _tabPaths[index] ?? '/';
    context.go(path);
  }

  bool get _isHome => widget.location == '/' || widget.location.startsWith('/?');

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final hasNavBar = isMobile
        && _navBarPaths.any((p) => widget.location == p || widget.location.startsWith('$p?'))
        && !_isNoNavPath(widget.location);
    return PopScope(
      canPop: _isHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
      backgroundColor: _c.background,
      body: isMobile ? _mobile() : _desktop(),
      bottomNavigationBar: hasNavBar
          ? ValueListenableBuilder<bool>(
              valueListenable: appNavBarHidden,
              builder: (_, hidden, _) {
                if (hidden) return const SizedBox.shrink();
                final isHome = _isHome;
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
      ),
    );
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────

  // Note on bottom insets: when the nav bar is present it lives in the
  // Scaffold's bottomNavigationBar slot, which makes Flutter strip the body's
  // bottom inset (Scaffold sets removeBottomPadding: bottomNavigationBar != null
  // on the body slot). So inside tab screens `MediaQuery.viewPadding.bottom` is
  // already ~0 and `bottomScrollInset` returns just the base margin — the nav
  // bar covers the system inset. Pushed/detail screens have no nav bar, keep the
  // real inset, and reserve it. One helper is therefore correct everywhere; no
  // manual inset juggling is needed here.
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
          const SizedBox(height: 24),
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
          color: _c.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text('E', style: context.theme.typography.lg.copyWith(
            color: Colors.white, fontWeight: FontWeight.w800)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _c.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('E', style: context.theme.typography.sm.copyWith(
                color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text('exono', style: context.theme.typography.lg.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.theme.colors.foreground)),
        ],
      ),
    );
  }

  Widget _collapseToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(_sidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                  size: 18, color: _c.accent),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 10),
                Text('Collapse', style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground)),
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
      child: GestureDetector(
        onTap: () => _onNav(e.index),
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
              Icon(e.icon, size: 18, color: active ? _c.accent : context.theme.colors.mutedForeground),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 10),
                Text(e.label,
                    style: context.theme.typography.sm.copyWith(
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
        border: Border(bottom: BorderSide(color: context.theme.colors.border)),
      ),
      child: Row(
        children: [
          Text(
            _pathLabel(widget.location),
            style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.w700,
                color: context.theme.colors.foreground),
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
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _c.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(name[0].toUpperCase(),
                      style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(name, style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.foreground,
                    fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(Icons.settings_outlined, size: 18,
                    color: isProfileActive ? _c.accent : context.theme.colors.mutedForeground),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Text('Settings', style: context.theme.typography.sm.copyWith(
                      color: isProfileActive ? _c.accent : context.theme.colors.mutedForeground)),
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
