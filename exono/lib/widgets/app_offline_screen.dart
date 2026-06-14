import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_header.dart';

/// Full-screen offline placeholder. Drop-in replacement for a screen's build
/// return value when the device has no connectivity.
///
/// Usage:
///   if (!isOnline) return AppOfflineScreen(title: 'Contacts');
class AppOfflineScreen extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const AppOfflineScreen({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(onBack: onBack),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 52,
                        color: context.theme.colors.mutedForeground,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'You\'re offline',
                        style: context.theme.typography.xl.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$title is not available without an internet connection.',
                        textAlign: TextAlign.center,
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
