import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OpenRelay design system — dark-first premium theme.
class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B85FF);
  static const Color primaryDark = Color(0xFF4A42E0);
  static const Color accent = Color(0xFF00D9FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentOrange = Color(0xFFFF9100);
  static const Color accentRed = Color(0xFFFF5252);

  // Surface colors (dark theme)
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFF1A2332);
  static const Color surfaceCard = Color(0xFF1E293B);
  static const Color surfaceBorder = Color(0xFF2A3548);

  // Text colors
  static const Color textPrimary = Color(0xFFEEF2FF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status colors
  static const Color online = Color(0xFF00E676);
  static const Color offline = Color(0xFFFF5252);
  static const Color connecting = Color(0xFFFF9100);
  static const Color pending = Color(0xFFFFD740);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: accentRed,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: textMuted),
        labelStyle: GoogleFonts.inter(color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceBorder,
        thickness: 1,
      ),
    );
  }
}
