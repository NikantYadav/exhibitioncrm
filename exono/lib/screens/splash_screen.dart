import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _backgroundColor = Color(0xFF080808);
  static const Color _surfaceColor = Color(0xFF141313);
  static const Color _borderColor = Color(0xFF444748);
  static const Color _mutedColor = Color(0xFFC4C7C8);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.55, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;

        final selectedMode = prefs.getString('selected_mode');
        if (selectedMode == 'chat') {
          Navigator.of(context).pushReplacementNamed('/chat');
        } else if (selectedMode == 'main' || selectedMode == 'crm') {
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          Navigator.of(context).pushReplacementNamed('/mode-selection');
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 56,
                right: -16,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: isMobile ? 140 : 180,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Positioned(
                bottom: 120,
                left: -18,
                child: Icon(
                  Icons.blur_on_rounded,
                  size: isMobile ? 120 : 150,
                  color: Colors.white.withValues(alpha: 0.035),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 24 : 32),
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'INITIALIZING EXONO',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.1,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildLogo(isMobile),
                                const SizedBox(height: 28),
                                Text(
                                  'EXONO',
                                  style: TextStyle(
                                    fontSize: isMobile ? 34 : 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1.4,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'INTELLIGENT CRM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _mutedColor,
                                    letterSpacing: 2.2,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Preparing your targets, events, capture tools, contacts, and assistant workspace.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: _mutedColor,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1B1B),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Checking session and restoring your last workspace...',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildLogo(bool isMobile) {
    final size = isMobile ? 112.0 : 124.0;
    final innerSquare = isMobile ? 46.0 : 52.0;
    final dotSize = isMobile ? 12.0 : 14.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 24,
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
                width: innerSquare,
                height: innerSquare,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _backgroundColor.withValues(alpha: 0.18),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.785398,
              child: Container(
                width: innerSquare,
                height: innerSquare,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _backgroundColor.withValues(alpha: 0.36),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
                boxShadow: [
                  BoxShadow(
                    color: _backgroundColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
