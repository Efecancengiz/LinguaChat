// lib/config/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Dark palette ──────────────────────────────────────────
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color primary = Color(0xFF2D7FF9);   // vibrant blue
  static const Color primaryDark = Color(0xFF1A5FCC);
  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF10B981);    // green for PREMIUM
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color danger = Color(0xFFF85149);
  static const Color warning = Color(0xFFF59E0B);
  static const Color border = Color(0xFF30363D);
  static const Color cardGlow = Color(0x1A58A6FF);

  // ── Light palette (Indigo Harmony) ──────────────────────
  //   Hue family : 225–260° (blue-indigo-violet)
  //   Accent     : 188° cyan  (complementary warmth)
  //   All tints derived from the same hue family for cohesion

  static const Color lightBackground   = Color(0xFFEEF2FF); // indigo-50  — warm off-white
  static const Color lightSurface      = Color(0xFFFFFFFF); // pure white cards
  static const Color lightSurfaceMid   = Color(0xFFF5F7FF); // indigo-25  — input fill
  static const Color lightSurfaceHover = Color(0xFFE8EDFF); // indigo-75  — hover state

  static const Color lightPrimary      = Color(0xFF4F46E5); // indigo-600 — main CTA
  static const Color lightPrimaryLight = Color(0xFF818CF8); // indigo-400 — soft variant
  static const Color lightPrimaryDark  = Color(0xFF3730A3); // indigo-700 — pressed state

  static const Color lightSecondary    = Color(0xFF7C3AED); // violet-600 — secondary actions
  static const Color lightAccent       = Color(0xFF06B6D4); // cyan-500   — highlights & PREMIUM
  static const Color lightPremium      = Color(0xFF8B5CF6); // violet-500 — PREMIUM badge

  static const Color lightTextPrimary   = Color(0xFF1E1B4B); // indigo-950 — near-black
  static const Color lightTextSecondary = Color(0xFF6B7280); // gray-500   — captions
  static const Color lightTextMuted     = Color(0xFF9CA3AF); // gray-400   — placeholders

  static const Color lightBorder        = Color(0xFFE0E7FF); // indigo-100 — subtle border
  static const Color lightBorderStrong  = Color(0xFFC7D2FE); // indigo-200 — active border

  static const Color lightDanger        = Color(0xFFEF4444); // red-500
  static const Color lightWarning       = Color(0xFFF59E0B); // amber-500
  static const Color lightSuccess       = Color(0xFF10B981); // emerald-500

  // Tonal glow colors
  static const Color lightPrimaryGlow   = Color(0x264F46E5); // indigo @ 15%
  static const Color lightAccentGlow    = Color(0x2206B6D4); // cyan   @ 13%

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textSecondary),
          bodySmall: TextStyle(color: textSecondary),
          labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primary),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Gradient presets (dark)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, Color(0xFF1A1F2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: surface.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border.withValues(alpha: 0.5)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Light gradients ────────────────────────────────────────
  // Page background: very subtle indigo fog
  static const LinearGradient surfaceGradientLight = LinearGradient(
    colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero / header accent gradient
  static const LinearGradient primaryGradientLight = LinearGradient(
    colors: [lightPrimary, Color(0xFF7C3AED)], // indigo → violet
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Cyan accent gradient (for highlights)
  static const LinearGradient accentGradientLight = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF4F46E5)], // cyan → indigo
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration get glassDecorationLight => BoxDecoration(
    color: lightSurface.withValues(alpha: 0.90),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: lightBorder),
    boxShadow: [
      BoxShadow(
        color: lightPrimaryGlow,
        blurRadius: 24,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Light ThemeData ────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        surface: lightSurface,
        error: lightDanger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge:  TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w700),
          displaySmall:  TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w600),
          headlineMedium:TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w500),
          titleLarge:    TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w600),
          titleMedium:   TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w500),
          titleSmall:    TextStyle(color: lightTextSecondary, fontWeight: FontWeight.w500),
          bodyLarge:     TextStyle(color: lightTextPrimary),
          bodyMedium:    TextStyle(color: lightTextSecondary),
          bodySmall:     TextStyle(color: lightTextSecondary),
          labelLarge:    TextStyle(color: lightTextPrimary,   fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: lightTextPrimary),
        surfaceTintColor: Colors.transparent,
        shadowColor: lightBorder,
        foregroundColor: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightDanger),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
        labelStyle: const TextStyle(color: lightTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: lightPrimary),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 0.8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightTextPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
