import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'events_screen.dart';
import 'contacts_screen.dart';
import 'capture_screen.dart';
import 'dashboard_screen.dart';
import 'follow_ups_screen.dart';
import 'account_settings_screen.dart';
import 'meetings_screen.dart';
import 'integrations_screen.dart';
import 'account_settings_screen.dart';
import 'log_interaction_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Main screen with sidebar navigation matching CRM's information architecture
class MainScreen extends StatefulWidget {
  final Widget? topBarAction;
  final int initialIndex;

  const MainScreen({super.key, this.topBarAction, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  // Incremented each time a tab is selected so the screen widget gets a new
  // key, forcing Flutter to remount it and call initState (i.e. fresh fetch).
  final Map<int, int> _tabGen = {};

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 7);
  }

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/'),
    _NavItem(
      icon: Icons.calendar_today_rounded,
      label: 'Events',
      route: '/events',
    ),
    _NavItem(
      icon: Icons.camera_alt_rounded,
      label: 'Capture',
      route: '/capture',
    ),
    _NavItem(icon: Icons.people_rounded, label: 'Contacts', route: '/contacts'),
    _NavItem(
      icon: Icons.mail_rounded,
      label: 'Follow-Ups',
      route: '/follow-ups',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      label: 'Profile',
      route: '/profile',
    ),
    _NavItem(
      icon: Icons.event_note_rounded,
      label: 'Meetings',
      route: '/meetings',
    ),
    _NavItem(
      icon: Icons.extension_rounded,
      label: 'Integrations',
      route: '/integrations',
    ),
  ];

  void _handleNavigation(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CaptureScreen(
            onNavigateTab: (i) {
              Navigator.of(context).pop();
              _navigateTo(i);
            },
          ),
        ),
      ).then((_) {
        // When Capture is dismissed (contact may have been saved), remount
        // the current tab so it fetches fresh data.
        if (mounted) setState(() => _tabGen[_selectedIndex] = (_tabGen[_selectedIndex] ?? 0) + 1);
      });
      return;
    }
    _navigateTo(index);
  }

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
      _tabGen[index] = (_tabGen[index] ?? 0) + 1;
    });
  }

  Key _tabKey(int index) => ValueKey('tab_${index}_${_tabGen[index] ?? 0}');

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          key: _tabKey(0),
          onNavigateTab: _navigateTo,
        );
      case 1:
        return EventsScreen(
          key: _tabKey(1),
          onNavigateTab: _navigateTo,
        );
      case 2:
        // CaptureScreen is pushed as a full route via _handleNavigation
        return const SizedBox.shrink();
      case 3:
        return ContactsScreen(
          key: _tabKey(3),
          onNavigateTab: _navigateTo,
        );
      case 4:
        return FollowUpsScreen(
          key: _tabKey(4),
          onNavigateTab: _navigateTo,
        );
      case 5:
        return const AccountSettingsScreen(
          key: ValueKey(5),
        );
      case 6:
        return MeetingsScreen(
          key: _tabKey(6),
          onNavigateTab: _navigateTo,
        );
      case 7:
        return IntegrationsScreen(
          key: _tabKey(7),
          onNavigateTab: _navigateTo,
        );
      default:
        return DashboardScreen(
          key: _tabKey(0),
          onNavigateTab: _navigateTo,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final colors = AppTheme.colorsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: colors.navBackground,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: colors.navBackground,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: DecoratedBox(
          decoration: AppTheme.appBackground(context),
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
        bottomNavigationBar: isMobile
            ? AppBottomNav(
                selectedIndex: _selectedIndex,
                onNavigate: _handleNavigation,
              )
            : null,
        floatingActionButton: (_selectedIndex >= 0 && _selectedIndex <= 5)
            ? null
            : _buildFAB(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final colors = AppTheme.colorsOf(context);

    return Row(
      children: [
        // Sidebar Navigation
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          width: _isSidebarCollapsed ? 80 : 288,
          decoration: BoxDecoration(
            color: colors.surface.withValues(
              alpha: colors.isDark ? 0.92 : 0.86,
            ),
            border: Border(
              right: BorderSide(
                color: colors.border.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            boxShadow: AppTheme.softShadow(context),
          ),
          child: Column(
            children: [
              // Brand Identity
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: _isSidebarCollapsed
                    ? _buildCollapsedBrand()
                    : _buildExpandedBrand(),
              ),

              // Divider
              Container(
                width: _isSidebarCollapsed ? 40 : double.infinity,
                height: 1,
                margin: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 20 : 24,
                ),
                color: colors.border.withValues(alpha: 0.6),
              ),

              const SizedBox(height: 24),

              // Collapse Toggle
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 16 : 16,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: _isSidebarCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          _isSidebarCollapsed
                              ? Icons.menu_open_rounded
                              : Icons.menu_rounded,
                          size: 20,
                          color: colors.textMuted,
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Collapse Sidebar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Navigation Items
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSidebarCollapsed ? 16 : 16,
                  ),
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) {
                    return _buildNavItem(index);
                  },
                ),
              ),

              // Settings at bottom
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: _isSidebarCollapsed ? 32 : double.infinity,
                      height: 1,
                      color: colors.border,
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsItem(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),

              // Page Content
              Expanded(child: _getScreen(_selectedIndex)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedIndex == 0 ||
        _selectedIndex == 3 ||
        _selectedIndex == 4) {
      return _getScreen(_selectedIndex);
    }

    final useStitchMobileChrome =
        _selectedIndex == 0 ||
        _selectedIndex == 1 ||
        _selectedIndex == 3 ||
        _selectedIndex == 4;

    return Column(
      children: [
        useStitchMobileChrome
            ? _buildStitchMobileTopBar()
            : _buildMobileTopBar(),
        Expanded(child: _getScreen(_selectedIndex)),
      ],
    );
  }



  Widget _buildCollapsedBrand() {
    final colors = AppTheme.colorsOf(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accentStrong],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.785398,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBrand() {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accentStrong],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -0.785398,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'exhibit.ai',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'INTELLIGENT CRM',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: colors.textMuted,
                  letterSpacing: 1.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final colors = AppTheme.colorsOf(context);
    final item = _navItems[index];
    final isActive = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? AppTheme.softShadow(context) : null,
          ),
          child: Row(
            mainAxisAlignment: _isSidebarCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isActive
                    ? (colors.isDark ? colors.background : Colors.white)
                    : colors.textMuted,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isActive
                          ? (colors.isDark ? colors.background : Colors.white)
                          : colors.textMuted,
                      letterSpacing: 2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final colors = AppTheme.colorsOf(context);

    return Consumer<ThemeProvider>(
      builder: (context, theme, _) => IconButton(
        onPressed: () => theme.toggleTheme(),
        tooltip: theme.isDarkMode
            ? 'Switch to day mode'
            : 'Switch to night mode',
        icon: Icon(
          theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: colors.textPrimary,
          size: 20,
        ),
        style: IconButton.styleFrom(
          backgroundColor: colors.surfaceAlt,
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
        ),
      ),
    );
  }

  Widget _buildSettingsItem() {
    final colors = AppTheme.colorsOf(context);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AccountSettingsScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: _isSidebarCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(Icons.settings_rounded, size: 20, color: colors.accent),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 12),
              Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final colors = AppTheme.colorsOf(context);
    final currentPage = _navItems[_selectedIndex].label;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: colors.isDark ? 0.82 : 0.74),
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.85),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
        child: Row(
          children: [
            // Breadcrumbs
            Row(
              children: [
                Text(
                  'CRM',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colors.borderStrong,
                  ),
                ),
                Text(
                  currentPage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Actions
            Row(
              children: [
                // Custom action widget (e.g., toggle button)
                if (widget.topBarAction != null) ...[
                  widget.topBarAction!,
                  const SizedBox(width: 16),
                ],
                _buildThemeToggle(),
                const SizedBox(width: 12),
                // User Profile
                Row(
                  children: [
                    if (!isMobile) ...[
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              auth.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.designation,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colors.textMuted,
                                letterSpacing: 1.5,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: colors.borderStrong,
                            width: 1,
                          ),
                          boxShadow: AppTheme.softShadow(context),
                        ),
                        child: Center(
                          child: Text(
                            auth.initials,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.isDark
                                  ? colors.background
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStitchMobileTopBar() {
    final colors = AppTheme.colorsOf(context);

    if (_selectedIndex == 2) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: colors.isDark ? 0.96 : 0.95),
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.8)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
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
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          showFToast(context: context, title: const Text('Flash toggle is UI-only for now.'));
                        },
                        icon: Icon(
                          Icons.flashlight_on,
                          color: colors.textSecondary,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                      IconButton(
                        onPressed: () => setState(() => _selectedIndex = 0),
                        icon: Icon(
                          Icons.close,
                          color: colors.textSecondary,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: colors.isDark ? 0.96 : 0.92),
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.85),
            width: 1,
          ),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.menu, color: colors.accent, size: 22),
              const SizedBox(width: 14),
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
              Icon(
                Icons.notifications_none_rounded,
                color: colors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTopBar() {
    final colors = AppTheme.colorsOf(context);
    final currentPage = _navItems[_selectedIndex].label;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: colors.isDark ? 0.84 : 0.78),
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Brand
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppTheme.softShadow(context),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: 0.785398,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: -0.785398,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'exhibit.ai',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentPage.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: colors.textMuted,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildThemeToggle(),
              const SizedBox(width: 10),
              // User Avatar
              Consumer<AuthProvider>(
                builder: (context, auth, _) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderStrong, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      auth.initials,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: colors.isDark ? colors.background : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    final colors = AppTheme.colorsOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return FloatingActionButton.extended(
      onPressed: () => showLogInteractionSheet(context),
      backgroundColor: colors.accent,
      icon: Icon(
        Icons.add_rounded,
        size: 24,
        color: colors.isDark ? colors.background : Colors.white,
      ),
      label: Text(
        'ADD NOTE',
        style: TextStyle(
          fontSize: isMobile ? 9 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: isMobile ? 1.5 : 2,
          color: colors.isDark ? colors.background : Colors.white,
        ),
      ),
      elevation: 8,
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  _NavItem({required this.icon, required this.label, required this.route});
}

// Placeholder for Dashboard
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: AppTheme.stone300),
          const SizedBox(height: 24),
          Text(
            '$title Coming Soon',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.stone400,
            ),
          ),
        ],
      ),
    );
  }
}
