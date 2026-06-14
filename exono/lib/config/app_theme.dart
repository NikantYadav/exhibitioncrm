import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ExonoColors extends ThemeExtension<ExonoColors> {
  final bool isDark;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceElevated;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color accentGlow;
  final Color navBackground;
  final Color destructive;
  final Color success;

  const ExonoColors({
    required this.isDark,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.accentGlow,
    required this.navBackground,
    required this.destructive,
    required this.success,
  });

  @override
  ExonoColors copyWith({
    bool? isDark,
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? accentGlow,
    Color? navBackground,
    Color? destructive,
    Color? success,
  }) {
    return ExonoColors(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSoft: accentSoft ?? this.accentSoft,
      accentGlow: accentGlow ?? this.accentGlow,
      navBackground: navBackground ?? this.navBackground,
      destructive: destructive ?? this.destructive,
      success: success ?? this.success,
    );
  }

  @override
  ExonoColors lerp(ThemeExtension<ExonoColors>? other, double t) {
    if (other is! ExonoColors) return this;
    return ExonoColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Centralized design system for EXONO.
///
/// Future visual refreshes should primarily happen in this file so the rest of
/// the codebase can consume semantic tokens instead of hardcoded palette values.
class AppTheme {
  // Legacy palette kept for older screens still migrating to semantic tokens.
  static const Color background = Color(0xFFEBF3FF);
  static const Color foreground = Color(0xFF152238);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF3A67C7);
  static const Color primaryDark = Color(0xFF244FAE);
  static const Color secondary = Color(0xFFEFF4FF);
  static const Color muted = Color(0xFF6D7FA5);
  static const Color border = Color(0xFFD6E0F2);
  static const Color destructive = Color(0xFFDB5B68);

  static const Color stone50 = Color(0xFFF8FAFF);
  static const Color stone100 = Color(0xFFEFF4FF);
  static const Color stone200 = Color(0xFFD9E3F4);
  static const Color stone300 = Color(0xFFBDCCE6);
  static const Color stone400 = Color(0xFF93A4C4);
  static const Color stone500 = Color(0xFF6D7FA5);
  static const Color stone600 = Color(0xFF4E5E7F);
  static const Color stone700 = Color(0xFF34425D);
  static const Color stone800 = Color(0xFF1E2C43);
  static const Color stone900 = Color(0xFF152238);

  static const double radiusCard = 20.0;
  static const double radiusButton = 999.0;
  static const double radiusInput = 16.0;
  static const double radiusLarge = 28.0;

  static const ExonoColors lightColors = ExonoColors(
    isDark: false,
    background: Color(0xFFEBF3FF),
    backgroundAlt: Color(0xFFD6E8FF),
    surface: Color(0xFFF5F9FF),
    surfaceAlt: Color(0xFFE0EEFF),
    surfaceElevated: Color(0xFFD0E4FF),
    border: Color(0xFFD4E0F7),
    borderStrong: Color(0xFFB9C9EA),
    textPrimary: Color(0xFF18253B),
    textSecondary: Color(0xFF50627F),
    textMuted: Color(0xFF7E8FAC),
    accent: Color(0xFF0672EF),
    accentStrong: Color(0xFF0559C2),
    accentSoft: Color(0xFFD6EAFD),
    accentGlow: Color(0xFFB0D6FB),
    navBackground: Color(0xFFEBF3FF),
    destructive: Color(0xFFDB5B68),
    success: Color(0xFF3AAE7A),
  );

  static const ExonoColors darkColors = ExonoColors(
    isDark: true,
    background: Color(0xFF000000),
    backgroundAlt: Color(0xFF000000),
    surface: Color(0xFF0B1422),
    surfaceAlt: Color(0xFF0F1B2E),
    surfaceElevated: Color(0xFF152538),
    border: Color(0xFF1C2F4A),
    borderStrong: Color(0xFF283F62),
    textPrimary: Color(0xFFF0F6FF),
    textSecondary: Color(0xFFB5C6E4),
    textMuted: Color(0xFF7A90B5),
    accent: Color(0xFF2B8BFF),
    accentStrong: Color(0xFF0672EF),
    accentSoft: Color(0xFF0D2A50),
    accentGlow: Color(0xFF071C3A),
    navBackground: Color(0xFF020408),
    destructive: Color(0xFFFF7A8A),
    success: Color(0xFF5DC89A),
  );

  static ExonoColors colorsOf(BuildContext context) {
    final extension = Theme.of(context).extension<ExonoColors>();
    assert(extension != null, 'ExonoColors theme extension is not configured.');
    return extension!;
  }

  static List<BoxShadow> softShadow(BuildContext context) {
    final colors = colorsOf(context);
    return [
      BoxShadow(
        color: colors.accentGlow.withValues(alpha: colors.isDark ? 0.28 : 0.18),
        blurRadius: 40,
        spreadRadius: -12,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: colors.isDark ? 0.24 : 0.08),
        blurRadius: 18,
        spreadRadius: -8,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static BoxDecoration appBackground(BuildContext context) {
    final colors = colorsOf(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.background,
          Color.lerp(colors.background, colors.backgroundAlt, 0.9)!,
          colors.backgroundAlt,
        ],
      ),
    );
  }

  /// Standard card decoration with a subtle navy gradient in dark mode.
  /// Use this instead of a flat `BoxDecoration(color: _c.surface)` on cards.
  static BoxDecoration cardDecoration(
    BuildContext context, {
    double radius = radiusCard,
    bool elevated = false,
  }) {
    final colors = colorsOf(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.isDark
            ? [
                elevated ? colors.surfaceAlt : colors.surface,
                elevated ? colors.surfaceElevated : colors.surfaceAlt,
              ]
            : [
                colors.surface,
                colors.surfaceAlt,
              ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colors.border.withValues(alpha: colors.isDark ? 0.85 : 0.90),
      ),
    );
  }

  static ThemeData get lightTheme => _buildTheme(lightColors, Brightness.light);

  static ThemeData get darkTheme => _buildTheme(darkColors, Brightness.dark);

  static ThemeData _buildTheme(ExonoColors colors, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
          primary: colors.accent,
          secondary: colors.accentSoft,
          surface: colors.surface,
          error: colors.destructive,
        ).copyWith(
          onPrimary: colors.isDark ? colors.background : Colors.white,
          onSecondary: colors.textPrimary,
          onSurface: colors.textPrimary,
          onError: Colors.white,
          outline: colors.border,
          outlineVariant: colors.borderStrong,
          surfaceContainerHighest: colors.surfaceElevated,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: GoogleFonts.inter().fontFamily,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: colors.isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Color(0xFF04060E),
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Color(0xFFF4F7FF),
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: colors.border.withValues(alpha: 0.9)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.isDark ? colors.background : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.isDark ? colors.background : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.destructive),
        ),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.navBackground,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.isDark ? colors.background : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.accentSoft,
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border.withValues(alpha: 0.8),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 24),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderStrong.withValues(alpha: 0.5)),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          letterSpacing: -0.7,
          height: 1.15,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          letterSpacing: -0.6,
          height: 1.15,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          letterSpacing: -0.5,
          height: 1.15,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textSecondary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colors.textMuted,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.textMuted,
        ),
      ),
    );
  }
}
