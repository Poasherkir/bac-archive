import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system — 2026 refresh, light + dark.
///
/// Widgets read semantic colors from `Theme.of(context).colorScheme`:
///   onSurface → primary text · onSurfaceVariant → secondary text
///   outline → borders · surface → cards · primaryContainer → tinted chips
/// `AppColors` keeps brand constants + the light palette for places that are
/// intentionally fixed (e.g. the branded splash gradient).
class AppColors {
  AppColors._();
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const accent = Color(0xFFDBEAFE); // light primary container
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF56637A); // AA on white at small sizes
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Dark palette.
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkPrimary = Color(0xFF3B82F6); // brighter blue for contrast
  static const darkText = Color(0xFFE2E8F0); // off-white
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF334155);
}

/// Per-year accent colors (icon-container tints on Home).
/// Years older than the map cycle through the same palette.
const kYearAccents = <int, Color>{
  2026: Color(0xFF2563EB), // blue
  2025: Color(0xFF22C55E), // green
  2024: Color(0xFF8B5CF6), // purple
  2023: Color(0xFFF59E0B), // orange
  2022: Color(0xFF06B6D4), // cyan
  2021: Color(0xFFEC4899), // pink
  2020: Color(0xFF6366F1), // indigo
  2019: Color(0xFF14B8A6), // teal
};

Color yearAccent(String year) {
  final y = int.tryParse(year);
  if (y == null) return AppColors.primary;
  final direct = kYearAccents[y];
  if (direct != null) return direct;
  final palette = kYearAccents.values.toList();
  return palette[y % palette.length];
}

/// Per-subject accent colors, keyed by the subject's storage slug (stable,
/// unlike display labels). Unlisted subjects fall back to slate.
const kSubjectAccents = <String, Color>{
  'physique': Color(0xFF2563EB), // physics — blue
  'maths': Color(0xFFF59E0B), // mathematics — orange
  'svt': Color(0xFF22C55E), // natural science — green
  'arabe': Color(0xFFEF4444), // arabic — red
  'francais': Color(0xFF8B5CF6), // french — purple
  'anglais': Color(0xFF06B6D4), // english — cyan
  'histoire-geo': Color(0xFF8D6E63), // history/geo — brown
  'philo': Color(0xFF6366F1), // philosophy — indigo
  'techno': Color(0xFFEA580C), // technology — engineering orange
};

Color subjectAccent(String slug) =>
    kSubjectAccents[slug] ?? const Color(0xFF64748B); // slate fallback

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accent,
      onPrimaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
    );
    return _base(
      scheme: scheme,
      scaffoldBackground: AppColors.background,
      cardShadow: const Color(0x1A0F172A),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.darkPrimary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF1E3A5F),
      onPrimaryContainer: const Color(0xFF93C5FD),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      error: const Color(0xFFF87171),
    );
    return _base(
      scheme: scheme,
      scaffoldBackground: AppColors.darkBackground,
      cardShadow: const Color(0x66000000),
    );
  }

  /// Shared construction for both modes — one source of truth for shapes,
  /// spacing and typography.
  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardShadow,
  }) {
    final baseText = scheme.brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: GoogleFonts.alexandriaTextTheme(baseText).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.alexandria(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shadowColor: cardShadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(2),
        shadowColor: WidgetStatePropertyAll(cardShadow),
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurfaceVariant, fontSize: 14.5),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontSize: 14.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle:
              GoogleFonts.alexandria(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
    );
  }
}
