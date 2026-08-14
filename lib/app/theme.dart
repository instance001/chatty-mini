import 'package:flutter/material.dart';

ThemeData buildChattyMiniTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final baseBackground = isDark
      ? const Color(0xFF111615)
      : const Color(0xFFF3F0E8);
  final surface = isDark ? const Color(0xFF18211F) : const Color(0xFFFFFCF6);
  final surfaceMuted = isDark
      ? const Color(0xFF263431)
      : const Color(0xFFE6DFD2);
  final ink = isDark ? const Color(0xFFEAF1ED) : const Color(0xFF1F2321);
  final accent = isDark ? const Color(0xFF8AC4AF) : const Color(0xFF2F5D50);
  final accentSoft = isDark ? const Color(0xFF314940) : const Color(0xFFC7D6CF);
  final warning = isDark ? const Color(0xFFE4A06D) : const Color(0xFFB36A3C);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        primary: accent,
        secondary: warning,
        surface: surface,
        surfaceContainerHighest: surfaceMuted,
        onSurface: ink,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: baseBackground,
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.4, color: ink),
      bodyMedium: TextStyle(fontSize: 13, height: 1.35, color: ink),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentSoft, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: accentSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: accentSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      disabledColor: surfaceMuted,
      selectedColor: accentSoft,
      secondarySelectedColor: accentSoft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: accentSoft),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: surface.withValues(alpha: 0.88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
