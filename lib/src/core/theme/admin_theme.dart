import 'package:flutter/material.dart';

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

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
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
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardTheme(
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
    textTheme: const TextTheme(
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
}
