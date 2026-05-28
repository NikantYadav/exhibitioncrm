import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'events_screen.dart';
import 'contacts_screen.dart';
import 'capture_screen.dart';
import 'dashboard_screen.dart';

/// Main screen with sidebar navigation matching CRM's information architecture
class MainScreen extends StatefulWidget {
  final Widget? topBarAction;
  
  const MainScreen({super.key, this.topBarAction});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      route: '/',
    ),
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
    _NavItem(
      icon: Icons.people_rounded,
      label: 'Contacts',
      route: '/contacts',
    ),
    _NavItem(
      icon: Icons.mail_rounded,
      label: 'Follow-Ups',
      route: '/follow-ups',
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
        return const DashboardScreen();
      case 1:
        return const EventsScreen();
      case 2:
        return const CaptureScreen();
      case 3:
        return const ContactsScreen();
      case 4:
        return const PlaceholderScreen(title: 'Follow-Ups');
      case 5:
        return const PlaceholderScreen(title: 'Meetings');
      case 6:
        return const PlaceholderScreen(title: 'Integrations');
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      bottomNavigationBar: isMobile ? _buildBottomBar() : null,
      floatingActionButton: _selectedIndex != 0 ? _buildFAB() : null, // Hide FAB on chat page
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
              Expanded(
                child: _getScreen(_selectedIndex),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Top Bar
        _buildMobileTopBar(),
        
        // Page Content
        Expanded(
          child: _getScreen(_selectedIndex),
        ),
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
        // TODO: Navigate to settings
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: _isSidebarCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.settings_rounded,
              size: 20,
              color: AppTheme.stone400,
            ),
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
                  border: Border.all(
                    color: AppTheme.stone100,
                    width: 1,
                  ),
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
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quick note coming soon!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
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

  _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
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
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: AppTheme.stone300,
          ),
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
