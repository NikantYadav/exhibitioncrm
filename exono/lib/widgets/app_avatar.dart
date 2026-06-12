import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';

/// Rounded-square contact avatar with gradient background and initials.
///
/// Usage:
///   AppAvatar(initials: 'JS')
///   AppAvatar(initials: 'JS', size: 52)
///   AppAvatar(initials: 'JS', done: true)   // green check state
///   AppAvatar.network(url: avatarUrl, initials: 'JS')
class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool done;
  final String? imageUrl;

  const AppAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.done = false,
    this.imageUrl,
  });

  const AppAvatar.network({
    super.key,
    required String url,
    required this.initials,
    this.size = 44,
    this.done = false,
  }) : imageUrl = url;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final radius = BorderRadius.circular(12);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, e, _) => _buildInitials(ctx, c, radius),
        ),
      );
    }

    return _buildInitials(context, c, radius);
  }

  Widget _buildInitials(BuildContext context, ExonoColors c, BorderRadius radius) {
    if (done) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.success.withValues(alpha: 0.18), c.success.withValues(alpha: 0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          border: Border.all(color: c.success.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check_rounded, size: size * 0.40, color: c.success),
      );
    }

    final fontSize = size < 36 ? context.theme.typography.xs : context.theme.typography.sm;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent.withValues(alpha: 0.22), c.accentStrong.withValues(alpha: 0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: fontSize.copyWith(fontWeight: FontWeight.w700, color: c.accent),
      ),
    );
  }
}
