import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../config/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Motion-graphic splash.
//
// The logo tile springs in with an elastic scale, then EXONO fades in below it,
// over a soft accent-glow background. Exits with a fade before navigating.
//
// This is the app's splash screen, wired to the '/splash' route in router.dart.
// It hands off from the native (OS-level) splash on the first frame so the
// launch reads as one continuous logo screen — see main.dart's preserve() call.
// ═════════════════════════════════════════════════════════════════════════════

/// Set true to preview the animation on a loop instead of navigating away.
/// Never ship with this on — flip back to false before committing.
const _kPreviewLoop = false;

class MotionSplashScreen extends StatefulWidget {
  const MotionSplashScreen({super.key});

  @override
  State<MotionSplashScreen> createState() => _MotionSplashScreenState();
}

class _MotionSplashScreenState extends State<MotionSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _exitCtrl;

  // Derived intro tracks (all read off _introCtrl's 0→1 timeline).
  late final Animation<double> _logoScale; // spring-in
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _logoOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.30, 0.55, curve: Curves.easeOut),
    );
    _logoScale = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.30, 0.72, curve: Curves.elasticOut),
    );
    _textOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.68, 1.0, curve: Curves.easeOut),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    // Hand off from the native splash on the first frame, then play.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
    });

    if (PlatformDispatcher.instance.accessibilityFeatures.disableAnimations) {
      _introCtrl.value = 1.0;
    } else {
      _introCtrl.forward();
    }

    if (_kPreviewLoop) {
      _loopPreview();
    } else {
      _navigate();
    }
  }

  Future<void> _loopPreview() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _introCtrl.reset();
      _introCtrl.forward();
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    // Give the entrance room to breathe, but don't stall a ready session.
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1700));
    await _waitForAuthInit(auth);
    await minSplash;

    if (!mounted) return;
    await _exitCtrl.forward();

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
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Container(
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                colors.accentGlow.withValues(alpha: colors.isDark ? 0.30 : 0.35),
                colors.background,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centered logo tile — springs in.
              AnimatedBuilder(
                animation: _introCtrl,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: SvgPicture.asset(logoAsset, width: 76, height: 76),
              ),
              // EXONO wordmark below center — fades in, does not move.
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, 92),
                  child: AnimatedBuilder(
                    animation: _introCtrl,
                    builder: (context, child) => Opacity(
                      opacity: _textOpacity.value,
                      child: child,
                    ),
                    child: Text(
                      'EXONO',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.6,
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
}
