import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/entry_flow_components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
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
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.55, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOutBack)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic)),
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
        Navigator.of(context).pushReplacementNamed(kIsWeb ? '/landing' : '/auth');
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(kIsWeb ? '/landing' : '/auth');
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

    return EntryFlowScaffold(
      child: Center(
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
                  child: EntryPanel(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EntryEyebrow(label: 'INITIALIZING EXONO'),
                        const SizedBox(height: 24),
                        _buildLogo(isMobile),
                        const SizedBox(height: 28),
                        Text(
                          'EXONO',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'INTELLIGENT CRM',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 2.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing your targets, events, capture tools, contacts, and assistant workspace.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 440;
                            if (compact) {
                              return const Column(
                                children: [
                                  EntryMetricCard(
                                    icon: Icons.track_changes_rounded,
                                    title: 'Targets',
                                    value: 'Ready',
                                    subtitle: 'Priority lists and next actions are loading',
                                  ),
                                  SizedBox(height: 12),
                                  EntryMetricCard(
                                    icon: Icons.forum_rounded,
                                    title: 'Assistant',
                                    value: 'Syncing',
                                    subtitle: 'Restoring your recent workspace and mode',
                                  ),
                                ],
                              );
                            }
                            return const Row(
                              children: [
                                Expanded(
                                  child: EntryMetricCard(
                                    icon: Icons.track_changes_rounded,
                                    title: 'Targets',
                                    value: 'Ready',
                                    subtitle: 'Priority lists and next actions are loading',
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: EntryMetricCard(
                                    icon: Icons.forum_rounded,
                                    title: 'Assistant',
                                    value: 'Syncing',
                                    subtitle: 'Restoring your recent workspace and mode',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        EntrySoftTile(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.colorsOf(context).accentStrong),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Checking session and restoring your last workspace...',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildLogo(bool isMobile) {
    final colors = AppTheme.colorsOf(context);
    final size = isMobile ? 112.0 : 124.0;
    final innerSquare = isMobile ? 46.0 : 52.0;
    final dotSize = isMobile ? 12.0 : 14.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.accentSoft],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
        boxShadow: AppTheme.softShadow(context),
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
                  border: Border.all(color: colors.accentStrong.withValues(alpha: 0.22), width: 3),
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
                  border: Border.all(color: colors.accentStrong.withValues(alpha: 0.42), width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: colors.accentStrong,
                borderRadius: BorderRadius.circular(dotSize / 2),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentStrong.withValues(alpha: 0.35),
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
