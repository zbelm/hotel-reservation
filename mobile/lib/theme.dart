import 'package:flutter/material.dart';

// Same palette as the web app
class Palette {
  static const sea = Color(0xFF0E5E5A);
  static const seaLight = Color(0xFF5FB8AE);
  static const sand = Color(0xFFF6F1E8);
  static const paper = Color(0xFFFFFDF8);
  static const ink = Color(0xFF1E2A2B);
  static const muted = Color(0xFF5E6B6A);
  static const line = Color(0xFFE3DACB);
  static const sun = Color(0xFFB8572E);
  static const good = Color(0xFF2F7A4B);
  static const bad = Color(0xFFA23B2E);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.sea,
    brightness: brightness,
    primary: dark ? Palette.seaLight : Palette.sea,
    surface: dark ? const Color(0xFF1A2221) : Palette.paper,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF111716) : Palette.sand,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF111716) : Palette.sand,
      foregroundColor: dark ? Colors.white : Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : Palette.ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0xFF2C3735) : Palette.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? const Color(0xFF2C3735) : Palette.line),
      ),
    ),
  );
}

TextStyle displayStyle(BuildContext context, double size) => TextStyle(
      fontFamily: 'serif',
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.1,
      color: Theme.of(context).colorScheme.onSurface,
    );
