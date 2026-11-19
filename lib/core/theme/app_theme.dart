import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna, tipografi Plus Jakarta Sans, dan token tata letak dari Stitch DESIGN.md.
class FinkuColors {
  FinkuColors._();

  // Canvas & Surfaces (DESIGN.md)
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceSlate = Color(0xFFF8FAFC);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color surfaceVariant = Color(0xFFD3E4FE);

  // Typography & Ink
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color navyBase = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF3E4A3D);
  static const Color inverseSurface = Color(0xFF213145);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);
  static const Color tertiary = Color(0xFF545C72);
  static const Color neutralSlate = Color(0xFF64748B);
  static const Color outline = Color(0xFF6E7B6C);
  static const Color outlineVariant = Color(0xFFBDCABA);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color borderInput = Color(0xFFCBD5E1);
  static const Color progressTrack = Color(0xFFF1F5F9);

  // Primary Brand & Semantic Greens
  static const Color primary = Color(0xFF006B2C);
  static const Color primaryBrand = Color(0xFF16A34A);
  static const Color primaryContainer = Color(0xFF00873A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFF7FFC97);
  static const Color primaryFixedDim = Color(0xFF62DF7D);
  static const Color onPrimaryFixed = Color(0xFF002109);
  static const Color onPrimaryFixedVariant = Color(0xFF005320);
  static const Color safeBg = Color(0xFFDCFCE7);

  // Secondary Brand & Collaborative Blues
  static const Color secondary = Color(0xFF0051D5);
  static const Color secondaryBrand = Color(0xFF2563EB);
  static const Color secondaryContainer = Color(0xFF316BF3);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryFixed = Color(0xFFDBE1FF);
  static const Color onSecondaryFixedVariant = Color(0xFF003EA8);
  static const Color roleTagBg = Color(0xFFDBEAFE);

  // Warning & Danger / Alert (GEMINI.md 5.4.2 & DESIGN.md)
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFBA1A1A);
  static const Color dangerAlert = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color tertiaryFixed = Color(0xFFDAE2FD);
  static const Color onTertiaryFixed = Color(0xFF131B2E);
}

class FinkuTypography {
  FinkuTypography._();

  static TextStyle displayCurrency({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.64,
        color: color,
      );

  static TextStyle headlineLg({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        letterSpacing: -0.24,
        color: color,
      );

  static TextStyle headlineMd({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle headlineSm({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: color,
      );

  static TextStyle titleMd({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: color,
      );

  static TextStyle bodyLg({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: color,
      );

  static TextStyle bodyMd({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: color,
      );

  static TextStyle bodySm({Color color = FinkuColors.tertiary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: color,
      );

  static TextStyle labelLg({Color color = FinkuColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: color,
      );

  static TextStyle labelMd({Color color = FinkuColors.onSurfaceVariant}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.12,
        color: color,
      );

  static TextStyle labelSm({Color color = FinkuColors.tertiary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 14 / 11,
        letterSpacing: 0.22,
        color: color,
      );

  static TextStyle currencyPrefix({Color color = FinkuColors.neutralSlate}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: color,
      );
}

class FinkuTheme {
  FinkuTheme._();

  static ThemeData light() {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FinkuColors.surface,
      colorScheme: const ColorScheme.light(
        primary: FinkuColors.primary,
        onPrimary: FinkuColors.onPrimary,
        primaryContainer: FinkuColors.primaryContainer,
        secondary: FinkuColors.secondary,
        onSecondary: FinkuColors.onSecondary,
        secondaryContainer: FinkuColors.secondaryContainer,
        tertiary: FinkuColors.tertiary,
        error: FinkuColors.error,
        surface: FinkuColors.surface,
        onSurface: FinkuColors.onSurface,
        surfaceContainerLowest: FinkuColors.surfaceContainerLowest,
        surfaceContainerLow: FinkuColors.surfaceContainerLow,
        surfaceContainer: FinkuColors.surfaceContainer,
        surfaceContainerHigh: FinkuColors.surfaceContainerHigh,
        outline: FinkuColors.outline,
        outlineVariant: FinkuColors.borderSubtle,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: FinkuColors.onSurface,
        displayColor: FinkuColors.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FinkuColors.surface.withValues(alpha: 0.92),
        foregroundColor: FinkuColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: FinkuTypography.headlineSm(),
      ),
      cardTheme: CardThemeData(
        color: FinkuColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: FinkuColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FinkuColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinkuColors.borderInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinkuColors.borderInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinkuColors.primaryBrand, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FinkuColors.primaryBrand,
          foregroundColor: FinkuColors.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: FinkuTypography.labelLg(color: FinkuColors.onPrimary),
          elevation: 0,
        ),
      ),
    );
  }
}
