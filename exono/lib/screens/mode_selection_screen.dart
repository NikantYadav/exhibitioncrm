import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  String? _selectedMode;

  void _selectMode(String mode) async {
    setState(() => _selectedMode = mode);
    
    // Save selected mode
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_mode', mode);
    
    // Navigate after a short delay for visual feedback
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (mode == 'chat') {
          Navigator.of(context).pushReplacementNamed('/chat');
        } else {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: isMobile ? 80 : 96,
                    height: isMobile ? 80 : 96,
                    decoration: BoxDecoration(
                      color: AppTheme.stone900,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.stone900.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
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
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: -0.785398,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose Your Experience',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.stone900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SELECT HOW YOU WANT TO USE EXHIBIT.AI',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.stone400,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Mode Cards
                  if (isMobile)
                    Column(
                      children: [
                        _buildModeCard(
                          'chat',
                          'Chat Mode',
                          'Conversational AI assistant for quick interactions',
                          Icons.chat_bubble_rounded,
                          [
                            'Natural conversation',
                            'Quick answers',
                            'Task assistance',
                            'Smart suggestions',
                          ],
                          isMobile,
                        ),
                        const SizedBox(height: 20),
                        _buildModeCard(
                          'crm',
                          'CRM Mode',
                          'Full-featured CRM for managing contacts and events',
                          Icons.dashboard_rounded,
                          [
                            'Contact management',
                            'Event tracking',
                            'Follow-up system',
                            'Analytics dashboard',
                          ],
                          isMobile,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeCard(
                            'chat',
                            'Chat Mode',
                            'Conversational AI assistant for quick interactions',
                            Icons.chat_bubble_rounded,
                            [
                              'Natural conversation',
                              'Quick answers',
                              'Task assistance',
                              'Smart suggestions',
                            ],
                            isMobile,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildModeCard(
                            'crm',
                            'CRM Mode',
                            'Full-featured CRM for managing contacts and events',
                            Icons.dashboard_rounded,
                            [
                              'Contact management',
                              'Event tracking',
                              'Follow-up system',
                              'Analytics dashboard',
                            ],
                            isMobile,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    String mode,
    String title,
    String description,
    IconData icon,
    List<String> features,
    bool isMobile,
  ) {
    final isSelected = _selectedMode == mode;
    
    return InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.stone900 : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isSelected
                ? AppTheme.stone900
                : AppTheme.stone200.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.stone900.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: isMobile ? 64 : 80,
              height: isMobile ? 64 : 80,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.stone100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: isMobile ? 32 : 40,
                color: isSelected ? Colors.white : AppTheme.stone600,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : AppTheme.stone900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppTheme.stone500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Features
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppTheme.stone200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: isSelected ? Colors.white : AppTheme.stone600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppTheme.stone700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            
            if (isSelected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
