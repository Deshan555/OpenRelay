import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OpenRelay design system — brutalist off-white and red aesthetic with sharp borders.
class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFFE50012); // Vibrant Red
  static const Color primaryDark = Color(0xFFB3000E);
  static const Color primaryLight = Color(0xFFFF3344);
  
  static const Color background = Color(0xFFF5F5F5); // Off-white
  static const Color border = Color(0xFF111111); // Dark charcoal border
  static const Color gridLine = Color(0xFFCCCCCC); // Table grid line

  static const Color accent = Color(0xFFE50012);
  static const Color accentGreen = Color(0xFF2E7D32); // Darker green for accessibility
  static const Color accentOrange = Color(0xFFEF6C00);
  static const Color accentRed = Color(0xFFC62828);

  // Status colors
  static const Color online = Color(0xFF2E7D32);
  static const Color offline = Color(0xFFE50012);
  static const Color connecting = Color(0xFFEF6C00);
  static const Color pending = Color(0xFFF57F17);

  // Surface colors (dark theme)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF333333);

  // Text colors (dark theme)
  static const Color textPrimary = Color(0xFFEEF2FF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  /// Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: border,
        surface: Colors.white,
        error: accentRed,
      ),
      textTheme: GoogleFonts.robotoTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.bebasNeue(
          fontSize: 28,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          side: const BorderSide(color: border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.roboto(color: Colors.grey.shade600),
        labelStyle: GoogleFonts.roboto(color: Colors.black54, fontWeight: FontWeight.bold),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}
