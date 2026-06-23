import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAdminTheme() {
  const primary = Color(0xFF0B3A66);
  const primaryDark = Color(0xFF082949);
  const background = Color(0xFFF5F7FB);

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: const Color(0xFF1D7CF2),
        surface: Colors.white,
        surfaceContainerHighest: Colors.white,
      );

  // Cairo is a high-quality Arabic + Latin font from Google Fonts.
  // Using GoogleFonts.cairoTextTheme() ensures Arabic characters render
  // correctly on web without "Could not find Noto fonts" warnings.
  final cairoTextTheme = GoogleFonts.cairoTextTheme(
    const TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF13233B),
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF13233B),
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF13233B),
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF13233B),
      ),
      bodyLarge: TextStyle(color: Color(0xFF35465E)),
      bodyMedium: TextStyle(color: Color(0xFF516174)),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    textTheme: cairoTextTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: GoogleFonts.cairo().fontFamily,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5EAF2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5EAF2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    ),
  );
}
