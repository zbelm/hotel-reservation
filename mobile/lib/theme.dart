import 'package:flutter/material.dart';

// The same colors as the website (web/src/app/globals.css), light and dark.
class Palette {
  static const sand = Color(0xFFEDF1EE); // page background
  static const paper = Color(0xFFFAFCFA); // cards and fields
  static const ink = Color(0xFF13303B); // text
  static const muted = Color(0xFF55686B);
  static const line = Color(0xFFD3DDD8);
  static const bay = Color(0xFF13303B); // dark header surfaces; text on mango buttons
  static const onBay = Color(0xFFE9F0EC);
  static const sea = Color(0xFF1B6B73);
  static const seaTint = Color(0xFFDCEBE8);
  static const mango = Color(0xFFF0A23B); // main buttons, stars
  static const sun = Color(0xFFA3541F); // warnings
  static const sunTint = Color(0xFFF6E6D6);
  static const good = Color(0xFF2F7A4B);
  static const goodTint = Color(0xFFDFF0E4);
  static const bad = Color(0xFFA23B2E);
  static const badTint = Color(0xFFF6E0DC);
}

class PaletteDark {
  static const sand = Color(0xFF0D1F27);
  static const paper = Color(0xFF142A33);
  static const ink = Color(0xFFE6EEEA);
  static const muted = Color(0xFF9DB2B1);
  static const line = Color(0xFF24404A);
  static const sea = Color(0xFF6FC3C0);
  static const seaTint = Color(0xFF173A3F);
  static const mango = Color(0xFFF3B259);
  static const sun = Color(0xFFEBA373);
  static const sunTint = Color(0xFF3A2A1D);
  static const good = Color(0xFF7CC795);
  static const goodTint = Color(0xFF183225);
  static const bad = Color(0xFFEC8B7D);
  static const badTint = Color(0xFF3A1F1B);
}

/// Status colors that switch with light and dark mode. Use `tones(context).bad` etc.
@immutable
class Tones extends ThemeExtension<Tones> {
  const Tones({
    required this.sea,
    required this.seaTint,
    required this.good,
    required this.goodTint,
    required this.bad,
    required this.badTint,
    required this.sun,
    required this.sunTint,
    required this.mango,
    required this.muted,
    required this.line,
  });

  final Color sea, seaTint, good, goodTint, bad, badTint, sun, sunTint, mango, muted, line;

  static const light = Tones(
    sea: Palette.sea, seaTint: Palette.seaTint, good: Palette.good, goodTint: Palette.goodTint,
    bad: Palette.bad, badTint: Palette.badTint, sun: Palette.sun, sunTint: Palette.sunTint,
    mango: Palette.mango, muted: Palette.muted, line: Palette.line,
  );
  static const dark = Tones(
    sea: PaletteDark.sea, seaTint: PaletteDark.seaTint, good: PaletteDark.good, goodTint: PaletteDark.goodTint,
    bad: PaletteDark.bad, badTint: PaletteDark.badTint, sun: PaletteDark.sun, sunTint: PaletteDark.sunTint,
    mango: PaletteDark.mango, muted: PaletteDark.muted, line: PaletteDark.line,
  );

  /// The soft background that goes with one of the strong colors (for notes and chips)
  Color tintFor(Color c) {
    if (c == good) return goodTint;
    if (c == bad) return badTint;
    if (c == sun) return sunTint;
    if (c == sea) return seaTint;
    return c.withValues(alpha: 0.12);
  }

  @override
  Tones copyWith() => this;

  @override
  Tones lerp(ThemeExtension<Tones>? other, double t) => t < 0.5 || other is! Tones ? this : other;
}

Tones tones(BuildContext context) => Theme.of(context).extension<Tones>() ?? Tones.light;

const bodyFont = 'Figtree';
const displayFont = 'BricolageGrotesque';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final sand = dark ? PaletteDark.sand : Palette.sand;
  final paper = dark ? PaletteDark.paper : Palette.paper;
  final ink = dark ? PaletteDark.ink : Palette.ink;
  final muted = dark ? PaletteDark.muted : Palette.muted;
  final line = dark ? PaletteDark.line : Palette.line;
  final sea = dark ? PaletteDark.sea : Palette.sea;
  final seaTint = dark ? PaletteDark.seaTint : Palette.seaTint;
  final mango = dark ? PaletteDark.mango : Palette.mango;
  final bad = dark ? PaletteDark.bad : Palette.bad;

  final scheme = ColorScheme.fromSeed(seedColor: Palette.sea, brightness: brightness).copyWith(
    primary: sea,
    onPrimary: dark ? Palette.bay : Palette.paper,
    primaryContainer: seaTint,
    onPrimaryContainer: ink,
    secondary: mango,
    onSecondary: Palette.bay,
    secondaryContainer: seaTint,
    onSecondaryContainer: ink,
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: muted,
    surfaceContainerLowest: paper,
    surfaceContainerLow: paper,
    surfaceContainer: sand,
    surfaceContainerHigh: paper,
    surfaceContainerHighest: seaTint,
    outline: line,
    outlineVariant: line,
    error: bad,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness, fontFamily: bodyFont);
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink, fontFamily: bodyFont);
  TextStyle? display(TextStyle? s) => s?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w600, letterSpacing: -0.3);

  return base.copyWith(
    scaffoldBackgroundColor: sand,
    textTheme: text.copyWith(
      displayLarge: display(text.displayLarge),
      displayMedium: display(text.displayMedium),
      displaySmall: display(text.displaySmall),
      headlineLarge: display(text.headlineLarge),
      headlineMedium: display(text.headlineMedium),
      headlineSmall: display(text.headlineSmall),
      titleLarge: display(text.titleLarge),
    ),
    extensions: [dark ? Tones.dark : Tones.light],
    appBarTheme: AppBarTheme(
      backgroundColor: sand,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: displayFont, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: seaTint,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? sea : muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: bodyFont,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? ink : muted,
          )),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: line)),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    // Main buttons: mango with dark text, like "Reserve" on the website
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: mango,
        foregroundColor: Palette.bay,
        disabledBackgroundColor: mango.withValues(alpha: 0.5),
        disabledForegroundColor: Palette.bay.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    // Secondary buttons: outlined, like the website's quiet buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: paper,
        side: BorderSide(color: line),
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: sea,
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: paper,
      selectedColor: seaTint,
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontFamily: bodyFont, color: ink),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? sea : null),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? sea : muted),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: sea),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? PaletteDark.paper : Palette.bay,
      contentTextStyle: TextStyle(fontFamily: bodyFont, color: dark ? PaletteDark.ink : Palette.onBay),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: sea, width: 1.6)),
    ),
  );
}

/// Headings in the website's display font
TextStyle displayStyle(BuildContext context, double size) => TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.1,
      letterSpacing: -0.02 * size,
      color: Theme.of(context).colorScheme.onSurface,
    );
