import 'dart:async';
import 'dart:ui';

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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final curved = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutQuint);
    _logoOpacity = curved;
    _logoScale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
    if (PlatformDispatcher.instance.accessibilityFeatures.disableAnimations) {
      _logoCtrl.value = 1.0;
    } else {
      _logoCtrl.forward();
    }
    _navigate();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();

    // Wait until auth has finished restoring the session before routing, so a
    // logged-in user never sees the auth screen flash. Keep a minimum splash
    // duration so the logo doesn't blink on fast restores.
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 800));
    await _waitForAuthInit(auth);
    await minSplash;

    if (!mounted) return;
    if (auth.isAuthenticated) {
      context.go('/');
    } else {
      context.go('/auth');
    }
  }

  Future<void> _waitForAuthInit(AuthProvider auth) {
    if (auth.initialized) return Future.value();
    final completer = Completer<void>();
    void listener() {
      if (auth.initialized && !completer.isCompleted) {
        auth.removeListener(listener);
        completer.complete();
      }
    }
    auth.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final logoAsset = colors.isDark
        ? 'assets/images/logo-white.svg'
        : 'assets/images/logo-black.svg';

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: FadeTransition(
          opacity: _logoOpacity,
          child: ScaleTransition(
            scale: _logoScale,
            child: SvgPicture.asset(
              logoAsset,
              width: 72,
              height: 72,
            ),
          ),
        ),
      ),
    );
  }
}
