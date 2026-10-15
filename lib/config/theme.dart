// lib/config/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  /// Checks whether the user's device is in Dark Mode
  static bool get isDark {
    try {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } catch (_) {
      return false;
    }
  }

  // ── Light palette (Crisp Modern White & Slate) ───────────
  static const Color lightBackground = Color(0xFFFFFFFF); // soft clean pure white
  static const Color lightSurface = Color(0xFFFFFFFF); // pure white cards/dialogs
  static const Color lightSurfaceLight = Color(0xFFF1F5F9); // light slate for inputs & badges
  static const Color lightSurfaceMid = Color(0xFFE2E8F0);
  static const Color lightSurfaceHover = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A); // deep charcoal/slate for crisp contrast
  static const Color lightTextSecondary = Color(0xFF64748B); // muted slate gray
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0); // subtle clean border
  static const Color lightBorderStrong = Color(0xFFCBD5E1);

  // ── Dark palette (Instagram Pure OLED Pitch Black #000000) ────────────
  static const Color darkBackground = Color(0xFF000000); // Pure OLED AMOLED Black like Instagram
  static const Color darkSurface = Color(0xFF121212); // Sleek dark card & container surface
  static const Color darkSurfaceLight = Color(0xFF1C1C1E); // Apple/Instagram input & pill surface
  static const Color darkSurfaceMid = Color(0xFF262626); // elevated containers & dialogs
  static const Color darkSurfaceHover = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // crisp pure white text
  static const Color darkTextSecondary = Color(0xFFA8A8A8); // clear slate text
  static const Color darkTextMuted = Color(0xFF737373);
  static const Color darkBorder = Color(0xFF262626); // subtle crisp Instagram border
  static const Color darkBorderStrong = Color(0xFF383838);

  // ── Brand & Status Colors ────────────────────────────────
  static const Color primary = Color(0xFF3B82F6); // vibrant royal blue
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF6366F1); // indigo/violet accent
  static const Color accent = Color(0xFF10B981); // emerald green for online & active
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color premium = Color(0xFF8B5CF6);

  // ── Dynamic Adaptive Colors (Follows Device Theme) ───────
  static Color get background => isDark ? darkBackground : lightBackground;
  static Color get surface => isDark ? darkSurface : lightSurface;
  static Color get surfaceLight => isDark ? darkSurfaceLight : lightSurfaceLight;
  static Color get surfaceMid => isDark ? darkSurfaceMid : lightSurfaceMid;
  static Color get textPrimary => isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => isDark ? darkTextSecondary : lightTextSecondary;
  static Color get border => isDark ? darkBorder : lightBorder;
  static Color get cardGlow => isDark ? const Color(0x333B82F6) : const Color(0x143B82F6);

  // ── Aliases ──────────────────────────────────────────────
  static const Color lightPrimary = primary;
  static const Color lightPrimaryLight = Color(0xFF60A5FA);
  static const Color lightPrimaryDark = primaryDark;
  static const Color lightSecondary = secondary;
  static const Color lightAccent = accent;
  static const Color lightPremium = premium;
  static const Color lightDanger = danger;
  static const Color lightWarning = warning;
  static const Color lightSuccess = accent;
  static const Color lightPrimaryGlow = Color(0x1A3B82F6);
  static const Color lightAccentGlow = Color(0x1A10B981);

  static const Color darkPrimary = primary;
  static const Color darkSecondary = secondary;
  static const Color darkAccent = accent;
  static const Color darkDanger = danger;
  static const Color darkWarning = warning;
  static const Color darkSuccess = accent;

  // ── Gradients ────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get surfaceGradient => isDark
      ? const LinearGradient(
          colors: [darkBackground, darkBackground],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : const LinearGradient(
          colors: [lightBackground, lightBackground],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border, width: 0.8),
    boxShadow: [
      if (!isDark)
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
    ],
  );

  // ── Light ThemeData ──────────────────────────────────────
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
        fillColor: lightSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: lightPrimary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: lightDanger),
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

  // ── Dark ThemeData ───────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkSurface,
        error: darkDanger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge:  TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w700),
          displaySmall:  TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w600),
          headlineMedium:TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w500),
          titleLarge:    TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w600),
          titleMedium:   TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w500),
          titleSmall:    TextStyle(color: darkTextSecondary, fontWeight: FontWeight.w500),
          bodyLarge:     TextStyle(color: darkTextPrimary),
          bodyMedium:    TextStyle(color: darkTextSecondary),
          bodySmall:     TextStyle(color: darkTextSecondary),
          labelLarge:    TextStyle(color: darkTextPrimary,   fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary),
        surfaceTintColor: Colors.transparent,
        shadowColor: darkBorder,
        foregroundColor: darkTextPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceMid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: darkDanger),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary),
        labelStyle: const TextStyle(color: darkTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: darkPrimary),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 0.8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceLight,
        contentTextStyle: GoogleFonts.inter(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
