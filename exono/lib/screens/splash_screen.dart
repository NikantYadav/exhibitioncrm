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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
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
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final logoAsset = colors.isDark
        ? 'assets/images/logo-white.svg'
        : 'assets/images/logo-black.svg';

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: SvgPicture.asset(
          logoAsset,
          width: 72,
          height: 72,
        ),
      ),
    );
  }
}
