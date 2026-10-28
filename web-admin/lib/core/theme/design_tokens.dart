// core/theme/design_tokens.dart
//
// Single source of truth for design tokens in Dart.
// Mirrors assets/design-tokens.json (Three-layer token architecture):
//   1. Primitives (raw values: AppPrimitiveColors, AppSpacing, AppRadius, etc.)
//   2. Semantics  (purpose aliases: AppColors, AppTypography, AppShadows)
//   3. Components (component specs: AppCardTheme, AppButtonTheme, etc.)

import 'package:flutter/material.dart';

// =============================================================================
// LAYER 1: PRIMITIVES
// =============================================================================

abstract class AppPrimitiveColors {
  // Blue scale
  static const Color blue50  = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBAD9FD);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF2563EB); // Primary accent
  static const Color blue600 = Color(0xFF2E6BE6);
  static const Color blue700 = Color(0xFF1E40AF);
  static const Color blue800 = Color(0xFF1E3A8A);
  static const Color blue900 = Color(0xFF0D2A5C); // Deep navy header

  // Navy scale (neutrals)
  static const Color navy50  = Color(0xFFF5F7FA); // Page background
  static const Color navy100 = Color(0xFFEEF2F7);
  static const Color navy200 = Color(0xFFE0E8F4); // Default border
  static const Color navy300 = Color(0xFFD0DBEE); // Strong border
  static const Color navy400 = Color(0xFFB4C6DB);
  static const Color navy500 = Color(0xFF8A9EB5); // Muted captions
  static const Color navy600 = Color(0xFF7A9CCE); // Sidebar default text
  static const Color navy700 = Color(0xFF5A7099); // Subtitles / secondary text
  static const Color navy800 = Color(0xFF3A5070);
  static const Color navy900 = Color(0xFF1E293B); // Sidebar bg & main text
  static const Color navy950 = Color(0xFF111A2E);

  // Deep brand-blue tones (sidebar chrome)
  static const Color brandBlue900 = Color(0xFF1A3A7C);
  static const Color brandBlue800 = Color(0xFF1E3E7C);
  static const Color brandBlue600 = Color(0xFF1A4A9C);

  // Hue-free neutrals (selected / active surfaces)
  static const Color neutral700 = Color(0xFF3F3F46);

  // Accent (audit-only)
  static const Color purple600 = Color(0xFF5A1A7A);

  // Gray scale
  static const Color gray50  = Color(0xFFF8FAFC);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF8A9BB0);
  static const Color gray600 = Color(0xFF6B7280);
  static const Color gray700 = Color(0xFF5A7099);
  static const Color gray800 = Color(0xFF374151);
  static const Color gray900 = Color(0xFF111827);

  // Status colors
  static const Color green50  = Color(0xFFECFDF5);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green400 = Color(0xFF4ADE80);
  static const Color green500 = Color(0xFF16A34A);
  static const Color green600 = Color(0xFF1A7A4A); // Paid / success

  static const Color amber50  = Color(0xFFFFF8E0);
  static const Color amber100 = Color(0xFFFEF9C3);
  static const Color amber600 = Color(0xFFB45309);
  static const Color amber700 = Color(0xFF7A6A1A); // Pending / warning

  static const Color red50   = Color(0xFFFEE2E2);
  static const Color red200  = Color(0xFFFECACA);
  static const Color red300  = Color(0xFFFCA5A5);
  static const Color red500  = Color(0xFFEF4444);
  static const Color red600  = Color(0xFFDC2626);
  static const Color red700  = Color(0xFFB91C1C);

  static const Color danger  = Color(0xFFCC2200); // High-contrast overdue
  static const Color info    = Color(0xFF3B82F6);
  static const Color gold    = Color(0xFFC9A84C);
  static const Color white   = Color(0xFFFFFFFF);
}

abstract class AppSpacing {
  static const double space0   = 0;
  static const double space0_5 = 2;
  static const double space1   = 4;
  static const double space1_5 = 6;
  static const double space2   = 8;
  static const double space2_5 = 10;
  static const double space3   = 12;
  static const double space3_5 = 14;
  static const double space4   = 16;
  static const double space5   = 20;
  static const double space6   = 24;
  static const double space7   = 28;
  static const double space8   = 32;
  static const double space10  = 40;

  // Semantic page spacing
  static const double pagePadding = 32;
  static const double cardPadding = 20;
  static const double cardGap     = 14;
  static const double sectionGap  = 28;
}

abstract class AppRadius {
  static const double none    = 0;
  static const double sm      = 4;
  static const double md      = 6;
  static const double lg      = 8;
  static const double xl      = 12; // Primary card & button radius
  static const double xxl     = 16; // Dialog radius
  static const double full    = 9999;

  static final BorderRadius cardBorderRadius   = BorderRadius.circular(xl);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(lg);
  static final BorderRadius pillBorderRadius   = BorderRadius.circular(full);
  static final BorderRadius dialogBorderRadius = BorderRadius.circular(xxl);
}

// =============================================================================
// LAYER 2: SEMANTIC TOKENS
// =============================================================================

abstract class AppColors {
  // Page / Surface
  static const Color background        = AppPrimitiveColors.navy50;
  static const Color surface           = AppPrimitiveColors.white;
  static const Color surfaceAlt       = AppPrimitiveColors.navy50;

  // Text / Foreground
  static const Color textPrimary       = AppPrimitiveColors.navy900;
  static const Color textSecondary     = AppPrimitiveColors.navy700;
  static const Color textMuted         = AppPrimitiveColors.navy500;
  static const Color textInverted      = AppPrimitiveColors.white;

  // Brand / Action
  static const Color primary          = AppPrimitiveColors.blue500;
  static const Color primaryHover     = AppPrimitiveColors.blue600;
  static const Color primaryActive    = AppPrimitiveColors.blue700;
  static const Color primaryHeader    = AppPrimitiveColors.blue900;
  static const Color primaryBg        = AppPrimitiveColors.blue50;
  // Deep brand blue — the one accent used for data emphasis (e.g. the
  // compliance-rate figure). Same hue family as `primary`, darker.
  static const Color dataInk          = AppPrimitiveColors.brandBlue600;

  // Borders & Dividers
  static const Color border           = AppPrimitiveColors.navy200;
  static const Color borderStrong     = AppPrimitiveColors.navy300;
  static const Color borderSubtle     = AppPrimitiveColors.navy100;

  // Status
  static const Color success          = AppPrimitiveColors.green600;
  static const Color successBg        = AppPrimitiveColors.green50;
  static const Color warning          = AppPrimitiveColors.amber700;
  static const Color warningBg        = AppPrimitiveColors.amber50;
  static const Color danger           = AppPrimitiveColors.danger;
  static const Color dangerBg         = AppPrimitiveColors.red50;
  static const Color error            = AppPrimitiveColors.red600;

  // Navigation Sidebar
  static const Color sidebarBg        = AppPrimitiveColors.navy900;
  static const Color sidebarBorder    = AppPrimitiveColors.brandBlue900;
  static const Color sidebarDivider   = AppPrimitiveColors.brandBlue800;
  static const Color sidebarText      = AppPrimitiveColors.navy600;
  static const Color sidebarTextActive= AppPrimitiveColors.white;
  // Selected nav pill — a hue-free grey so it reads as "current", not "brand".
  static const Color sidebarSelectedBg= AppPrimitiveColors.neutral700;

  // Accent (audit action coding only)
  static const Color purple           = AppPrimitiveColors.purple600;
}

abstract class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle greeting = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
}

abstract class AppShadows {
  // A soft aura behind every card — the "backdrop" the Figma reference
  // shows under each panel. Wider and fainter than the drop shadow, so it
  // reads as a glow rather than a second hard edge.
  static final List<BoxShadow> cardGlow = [
    BoxShadow(
      color: AppColors.dataInk.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.dataInk.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static final List<BoxShadow> dropdown = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

// =============================================================================
// LAYER 3: COMPONENT STYLES
// =============================================================================

abstract class AppComponents {
  static BoxDecoration cardDecoration({
    Color bg = AppColors.surface,
    Color border = AppColors.border,
  }) =>
      BoxDecoration(
        color: bg,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: border),
        boxShadow: [
          ...AppShadows.cardGlow,
          ...AppShadows.card,
        ],
      );

  static BoxDecoration iconBoxDecoration(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      );
}
