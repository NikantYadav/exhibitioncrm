import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'events_screen.dart';
import 'contacts_screen.dart';
import 'capture_screen.dart';
import 'dashboard_screen.dart';
import 'follow_ups_screen.dart';
import 'profile_screen.dart';
import 'meetings_screen.dart';
import 'integrations_screen.dart';
import 'account_settings_screen.dart';
import 'log_interaction_screen.dart';

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

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 1:
        return EventsScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 2:
        return CaptureScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 3:
        return ContactsScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 4:
        return FollowUpsScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 5:
        return ProfileScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 6:
        return MeetingsScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      case 7:
        return IntegrationsScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
      default:
        return DashboardScreen(
          onNavigateTab: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final useStitchMobileChrome =
        isMobile &&
        (_selectedIndex == 0 ||
            _selectedIndex == 1 ||
            _selectedIndex == 2 ||
            _selectedIndex == 3 ||
            _selectedIndex == 4 ||
            _selectedIndex == 5);
    final usesInternalMobileChrome =
        isMobile &&
        (_selectedIndex == 0 ||
            _selectedIndex == 2 ||
            _selectedIndex == 3 ||
            _selectedIndex == 4);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: useStitchMobileChrome
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Color(0xFF141313),
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: useStitchMobileChrome
            ? (_selectedIndex == 0
                  ? const Color(0xFF000000)
                  : _selectedIndex == 2
                  ? const Color(0xFF0E0E0E)
                  : _selectedIndex == 4
                  ? const Color(0xFF080808)
                  : const Color(0xFF141313))
            : AppTheme.background,
        body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        bottomNavigationBar: usesInternalMobileChrome
            ? null
            : isMobile
            ? (useStitchMobileChrome
                  ? _buildStitchBottomBar()
                  : _buildBottomBar())
            : null,
        floatingActionButton:
            (_selectedIndex == 0 ||
                _selectedIndex == 1 ||
                _selectedIndex == 2 ||
                _selectedIndex == 3 ||
                _selectedIndex == 4 ||
                _selectedIndex == 5)
            ? null
            : _buildFAB(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar Navigation
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          width: _isSidebarCollapsed ? 80 : 288,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(
                color: AppTheme.stone200.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 1,
                offset: const Offset(1, 0),
              ),
            ],
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
                color: AppTheme.stone100.withValues(alpha: 0.5),
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
                          color: AppTheme.stone400,
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Collapse Sidebar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.stone400,
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
                      color: AppTheme.stone100,
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
        _selectedIndex == 2 ||
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

  Widget _buildBottomBar() {
    // Show only first 5 items in bottom bar
    final bottomNavItems = _navItems.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.stone200.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(bottomNavItems.length, (index) {
              final item = bottomNavItems[index];
              final isActive = _selectedIndex == index;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.stone900
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: isActive ? Colors.white : AppTheme.stone400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isActive
                              ? AppTheme.stone900
                              : AppTheme.stone400,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedBrand() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.stone900,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.stone900.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.785398, // 45 degrees
              child: Container(
                width: 20,
                height: 20,
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
              angle: -0.785398, // -45 degrees
              child: Container(
                width: 20,
                height: 20,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.stone900,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.stone900.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      width: 20,
                      height: 20,
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
                  color: AppTheme.stone900,
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
                  color: AppTheme.stone400,
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
            color: isActive ? AppTheme.stone900 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.stone900.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: _isSidebarCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isActive ? Colors.white : AppTheme.stone400,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isActive ? Colors.white : AppTheme.stone400,
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

  Widget _buildSettingsItem() {
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
            Icon(Icons.settings_rounded, size: 20, color: AppTheme.stone400),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 12),
              Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.stone400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final currentPage = _navItems[_selectedIndex].label;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Debug: Check if topBarAction is provided
    if (widget.topBarAction != null) {
      debugPrint('TopBarAction is provided');
    } else {
      debugPrint('TopBarAction is NULL');
    }

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.stone200.withValues(alpha: 0.6),
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
                    color: AppTheme.stone400,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppTheme.stone300,
                  ),
                ),
                Text(
                  currentPage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.stone900,
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
                                color: AppTheme.stone900,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.designation,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.stone400,
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
                          color: AppTheme.stone900,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppTheme.stone100,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            auth.initials,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
    if (_selectedIndex == 2) {
      return Container(
        height: 56,
        decoration: const BoxDecoration(color: Color(0xFF0E0E0E)),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Text(
                  'EXONO',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Flash toggle is UI-only for now.'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.flashlight_on,
                          color: Colors.white,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                      IconButton(
                        onPressed: () => setState(() => _selectedIndex = 0),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
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
      decoration: const BoxDecoration(
        color: Color(0xFF141313),
        border: Border(bottom: BorderSide(color: Color(0xFF444748), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.menu, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Text(
                'EXONO',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStitchBottomBar() {
    if (_selectedIndex == 2) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141313),
          border: Border(top: BorderSide(color: Color(0xFF444748), width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: _buildStitchNavItem(
                    icon: Icons.track_changes_outlined,
                    label: 'Targets',
                    isActive: false,
                    showLabel: true,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ),
                Expanded(
                  child: _buildStitchNavItem(
                    icon: Icons.group_outlined,
                    label: 'Contacts',
                    isActive: false,
                    showLabel: true,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                ),
                Expanded(
                  child: _buildStitchNavItem(
                    icon: Icons.event_outlined,
                    label: 'Events',
                    isActive: false,
                    showLabel: true,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                Expanded(
                  child: _buildStitchNavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    isActive: _selectedIndex == 5,
                    showLabel: true,
                    onTap: () => setState(() => _selectedIndex = 5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final showLabels = _selectedIndex == 0 || _selectedIndex == 1;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141313),
        border: Border(top: BorderSide(color: Color(0xFF444748), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: showLabels ? 66 : 84,
          child: Row(
            children: [
              Expanded(
                child: _buildStitchNavItem(
                  icon: Icons.track_changes_outlined,
                  label: 'Targets',
                  isActive: _selectedIndex == 0,
                  showLabel: showLabels,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
              ),
              Expanded(
                child: _buildStitchNavItem(
                  icon: _selectedIndex == 3
                      ? Icons.contact_page_outlined
                      : Icons.group_outlined,
                  label: 'Contacts',
                  isActive: _selectedIndex == 3,
                  showLabel: showLabels,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ),
              SizedBox(
                width: 78,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, showLabels ? -14 : -18),
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = 2),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: showLabels
                              ? Colors.white
                              : const Color(0xFF080808),
                          borderRadius: BorderRadius.circular(12),
                          border: showLabels
                              ? null
                              : Border.all(color: const Color(0xFF262626)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: showLabels
                              ? const Color(0xFF141313)
                              : Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildStitchNavItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Events',
                  isActive: _selectedIndex == 1,
                  showLabel: showLabels,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
              Expanded(
                child: _buildStitchNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  isActive: _selectedIndex == 5,
                  showLabel: showLabels,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStitchNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool showLabel,
    required VoidCallback onTap,
  }) {
    const activeColor = Colors.white;
    const inactiveColor = Color(0xFFC4C7C8);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isActive ? activeColor : inactiveColor),
          if (showLabel) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileTopBar() {
    final currentPage = _navItems[_selectedIndex].label;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.stone200.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: AppTheme.stone900,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.stone900.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                      color: AppTheme.stone900,
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
                      color: AppTheme.stone400,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // User Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.stone900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.stone100, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'JD',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return FloatingActionButton.extended(
      onPressed: () => showLogInteractionSheet(context),
      backgroundColor: AppTheme.stone900,
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        'ADD NOTE',
        style: TextStyle(
          fontSize: isMobile ? 9 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: isMobile ? 1.5 : 2,
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
