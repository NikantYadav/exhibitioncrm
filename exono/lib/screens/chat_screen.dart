import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'main_screen.dart';

/// Standalone chat screen (not part of main navigation)
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isDashboardView = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDashboard = prefs.getBool('chat_dashboard_view') ?? false;
    setState(() {
      _isDashboardView = isDashboard;
      _isLoading = false;
    });
  }

  Future<void> _saveViewPreference(bool isDashboard) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_dashboard_view', isDashboard);
  }

  void _toggleView(bool isDashboard) {
    setState(() => _isDashboardView = isDashboard);
    _saveViewPreference(isDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.stone900),
          ),
        ),
      );
    }

    // If dashboard view, show the full CRM interface with toggle in top bar
    if (_isDashboardView) {
      return MainScreen(
        topBarAction: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.stone100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.stone200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                icon: Icons.chat_bubble_rounded,
                label: isMobile ? null : 'Chat',
                isActive: false,
                onTap: () => _toggleView(false),
              ),
              _buildToggleButton(
                icon: Icons.dashboard_rounded,
                label: isMobile ? null : 'CRM',
                isActive: true,
                onTap: () => _toggleView(true),
              ),
            ],
          ),
        ),
      );
    }

    // Chat view - use same structure as dashboard but with HomeScreen content
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Top Bar (matching dashboard structure)
          Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  // Brand Identity
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                        'CHAT MODE',
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
                  
                  // Actions (matching dashboard structure)
                  Row(
                    children: [
                      // Toggle Button
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.stone100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.stone200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildToggleButton(
                              icon: Icons.chat_bubble_rounded,
                              label: isMobile ? null : 'Chat',
                              isActive: true,
                              onTap: () => _toggleView(false),
                            ),
                            _buildToggleButton(
                              icon: Icons.dashboard_rounded,
                              label: isMobile ? null : 'CRM',
                              isActive: false,
                              onTap: () => _toggleView(true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
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
          ),
          
          // Chat Content
          const Expanded(
            child: HomeScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    String? label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.stone900 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : AppTheme.stone500,
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppTheme.stone500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
