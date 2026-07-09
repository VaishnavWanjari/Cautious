import 'package:flutter/material.dart';

/// Premium theme built from the SV Wedding Planner brand logo:
/// deep emerald green + rose-gold. Minimal, luxurious, Material 3, tuned for
/// both light and dark modes.
class AppTheme {
  // Brand palette (sampled from the logo).
  static const brandGreen = Color(0xFF0F3D2E);
  static const brandGreenDeep = Color(0xFF0A2A20);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE3C56B);
  static const marigold = Color(0xFFF5A623);
  static const cream = Color(0xFFFBF7EF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: brightness,
    );
    // Pin the brand identity: green leads in light mode, gold pops on dark.
    scheme = scheme.copyWith(
      primary: isDark ? goldLight : brandGreen,
      onPrimary: isDark ? brandGreenDeep : Colors.white,
      secondary: gold,
      tertiary: gold,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? brandGreenDeep : cream,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: isDark ? const Color(0xFF123A2C) : Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: scheme.surface,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
