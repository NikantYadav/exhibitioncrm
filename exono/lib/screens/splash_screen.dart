import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../config/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _fadeController;
  late final AnimationController _glowController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _wordmarkFadeAnim;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _wordmarkFadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _glowController.forward();

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      context.go('/');
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isDark = colors.isDark;
    final logoAsset = isDark
        ? 'assets/images/logo-white.svg'
        : 'assets/images/logo-black.svg';

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnim, _fadeAnim, _glowAnim]),
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // glow halo behind logo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // outer glow ring
                    Transform.scale(
                      scale: 1.0 + _glowAnim.value * 0.3,
                      child: Opacity(
                        opacity: (1.0 - _glowAnim.value) * 0.18,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                    // logo mark
                    Transform.scale(
                      scale: 0.6 + _scaleAnim.value * 0.4,
                      child: Opacity(
                        opacity: _scaleAnim.value.clamp(0.0, 1.0),
                        child: SvgPicture.asset(
                          logoAsset,
                          width: 72,
                          height: 72,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // wordmark fade-in below
                Opacity(
                  opacity: _wordmarkFadeAnim.value,
                  child: Text(
                    'exono',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                      height: 1,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
