import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/story.dart';

/// Palette: near-black base, blood crimson, deep emerald, antique gold.
class AppColors {
  AppColors._();
  static const bg = Color(0xFF0A0A0C);
  static const surface = Color(0xFF131316);
  static const surfaceHi = Color(0xFF1B1B20);
  static const crimson = Color(0xFFB3202F);
  static const emerald = Color(0xFF0F7A5A);
  static const gold = Color(0xFFD4AF5A);
  static const text = Color(0xFFE8E4DC);
  static const textDim = Color(0xFF8D8A84);

  /// Ambient glow colour for a node's mood.
  static Color glow(Mood m) => switch (m) {
        Mood.crimson => crimson,
        Mood.emerald => emerald,
        Mood.gold => gold,
        Mood.neutral => const Color(0xFF3A3A48),
      };

  static Color byName(String n) => switch (n) {
        'crimson' => crimson,
        'emerald' => emerald,
        _ => gold,
      };
}

class AppTheme {
  AppTheme._();

  /// Eerie display face for titles/buttons, readable serif for the story.
  static TextStyle display({double size = 18, Color? color}) =>
      GoogleFonts.cinzel(
        fontSize: size,
        color: color ?? AppColors.text,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      );

  static TextStyle body({double size = 19, Color? color, bool italic = false}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        height: 1.55,
        color: color ?? AppColors.text,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: FontWeight.w500,
      );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.crimson,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.cormorantGaramondTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
      ),
    );
  }
}
