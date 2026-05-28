import 'package:flutter/material.dart';

/// Design tokens matching the CRM Design System
/// Based on DESIGN_SYSTEM.md specifications
class DesignTokens {
  // Prevent instantiation
  DesignTokens._();

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================
  
  /// Display - Page titles, hero headings (30px, semibold)
  static const TextStyle textDisplay = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1C1917), // stone-900
    height: 1.2,
    letterSpacing: -0.75, // -0.025em
  );

  /// Section Header - Major section titles (18px, semibold)
  static const TextStyle textSectionHeader = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1C1917), // stone-900
    height: 1.3,
    letterSpacing: -0.27, // -0.015em
  );

  /// Card Title - Card and component titles (14px, semibold)
  static const TextStyle textCardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1C1917), // stone-900
    height: 1.4,
    letterSpacing: -0.14, // -0.01em
  );

  /// Body - Default body text (14px, normal)
  static const TextStyle textBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF57534E), // stone-600
    height: 1.6,
  );

  /// Caption - Small text, timestamps, metadata (12px, normal)
  static const TextStyle textCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF78716C), // stone-500
    height: 1.5,
  );

  // ============================================================================
  // SPACING SCALE
  // ============================================================================
  
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space20 = 80;
  static const double space24 = 96;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================
  
  static const double radiusCard = 24.0; // rounded-3xl
  static const double radiusModal = 16.0; // rounded-2xl
  static const double radiusButton = 12.0; // rounded-xl
  static const double radiusSmall = 8.0; // rounded-lg
  static const double radiusFull = 9999.0; // rounded-full

  // ============================================================================
  // SEMANTIC COLORS
  // ============================================================================
  
  // Success (Green)
  static const Color success = Color(0xFF10B981); // green-500
  static const Color successBg = Color(0xFFD1FAE5); // green-100
  static const Color successText = Color(0xFF065F46); // green-800
  static const Color successBorder = Color(0xFF6EE7B7); // green-300

  // Warning (Amber)
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color warningBg = Color(0xFFFEF3C7); // amber-100
  static const Color warningText = Color(0xFF92400E); // amber-800
  static const Color warningBorder = Color(0xFFFCD34D); // amber-300

  // Error/Destructive (Red)
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color errorBg = Color(0xFFFEE2E2); // red-100
  static const Color errorText = Color(0xFF991B1B); // red-800
  static const Color errorBorder = Color(0xFFFCA5A5); // red-300

  // Info (Blue)
  static const Color info = Color(0xFF3B82F6); // blue-500
  static const Color infoBg = Color(0xFFDBEAFE); // blue-100
  static const Color infoText = Color(0xFF1E40AF); // blue-800
  static const Color infoBorder = Color(0xFF93C5FD); // blue-300

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================
  
  static const Duration transitionSmooth = Duration(milliseconds: 150);
  static const Duration transitionPage = Duration(milliseconds: 400);
  static const Duration shimmerDuration = Duration(milliseconds: 2000);

  // ============================================================================
  // SHADOWS
  // ============================================================================
  
  /// Soft shadow for cards (default state)
  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];

  /// Card shadow (default)
  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Card hover shadow
  static List<BoxShadow> get shadowCardHover => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  /// Button shadow (primary)
  static List<BoxShadow> get shadowButton => [
        BoxShadow(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ============================================================================
  // TOUCH TARGETS
  // ============================================================================
  
  static const double touchTargetMin = 44.0; // Minimum touch target size
  static const double touchTargetSpacing = 8.0; // Minimum spacing between targets

  // ============================================================================
  // CONTAINER WIDTHS
  // ============================================================================
  
  static const double maxWidthXl = 1280.0; // max-w-7xl
  static const double maxWidthLg = 896.0; // max-w-4xl
  static const double maxWidthMd = 672.0; // max-w-2xl
}
