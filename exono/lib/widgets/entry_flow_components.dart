import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import 'app_card.dart';
import '../providers/theme_provider.dart';

SystemUiOverlayStyle entryFlowOverlayStyle(BuildContext context) {
  final colors = AppTheme.colorsOf(context);
  return colors.isDark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
}

class EntryFlowScaffold extends StatelessWidget {
  final Widget child;
  final bool showGrid;

  const EntryFlowScaffold({super.key, required this.child, this.showGrid = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: entryFlowOverlayStyle(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(child: child),
      ),
    );
  }
}

class EntryFlowTopBar extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String badgeLabel;

  const EntryFlowTopBar({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: colors.isDark ? 0.94 : 0.98),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Icon(leadingIcon, color: colors.accentStrong, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: colors.textPrimary,
              height: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: colors.isDark ? 0.90 : 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const EntryThemeToggleButton(),
        ],
      ),
    );
  }
}

class EntryThemeToggleButton extends StatelessWidget {
  const EntryThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Consumer<ThemeProvider>(
      builder: (context, theme, _) => IconButton(
        onPressed: () => theme.toggleTheme(),
        tooltip: theme.isDarkMode ? 'Switch to day mode' : 'Switch to night mode',
        icon: Icon(
          theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 20,
          color: colors.textPrimary,
        ),
        style: IconButton.styleFrom(
          backgroundColor: colors.surface.withValues(alpha: colors.isDark ? 0.92 : 0.98),
          side: BorderSide(color: colors.border),
          foregroundColor: colors.textPrimary,
        ),
      ),
    );
  }
}

class EntryPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const EntryPanel({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding ?? const EdgeInsets.all(20),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class EntrySoftTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const EntrySoftTile({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding ?? const EdgeInsets.all(16),
      radius: 20,
      elevated: true,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class EntryEyebrow extends StatelessWidget {
  final String label;

  const EntryEyebrow({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.accentSoft.withValues(alpha: colors.isDark ? 0.85 : 1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

class EntryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const EntryChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.accentStrong),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class EntryMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const EntryMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return EntrySoftTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                child: Icon(icon, size: 15, color: colors.accentStrong),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: -1.0)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: colors.textMuted, height: 1.4)),
        ],
      ),
    );
  }
}

class EntryPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const EntryPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.accent, colors.accentStrong],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppTheme.softShadow(context),
        ),
        child: FButton(
          variant: FButtonVariant.primary,
          onPress: loading ? null : onPressed,
          prefix: loading
              ? const SizedBox(width: 18, height: 18, child: FCircularProgress())
              : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class EntryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final int maxLines;
  final Widget? suffix;
  final IconData prefixIcon;
  final ValueChanged<String>? onSubmitted;

  const EntryTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isMultiline = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: isMultiline ? TextInputType.multiline : keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          minLines: isMultiline ? maxLines : 1,
          maxLines: maxLines,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: isMultiline
                ? Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10, top: 14),
                    child: Icon(prefixIcon, color: colors.accent, size: 20),
                  )
                : Icon(prefixIcon, color: colors.accent, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: suffix,
            fillColor: colors.surfaceAlt,
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class EntryBullet extends StatelessWidget {
  final String title;
  final String description;

  const EntryBullet({super.key, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: colors.accentSoft,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          child: Icon(Icons.check_rounded, size: 14, color: colors.accentStrong),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 3),
              Text(description, style: TextStyle(fontSize: 12, height: 1.45, color: colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

