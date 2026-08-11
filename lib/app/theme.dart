import 'package:flutter/material.dart';

abstract final class ChocoLogColors {
  static const yellow = Color(0xFFFFD600);
  static const canvas = Color(0xFFF8F8F5);
  static const ink = Color(0xFF202020);
  static const muted = Color(0xFF666666);
  static const border = Color(0xFFE4E4DE);
}

abstract final class ChocoLogTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: ChocoLogColors.yellow,
          brightness: Brightness.light,
          surface: Colors.white,
        ).copyWith(
          primary: ChocoLogColors.yellow,
          onPrimary: ChocoLogColors.ink,
          onSurface: ChocoLogColors.ink,
          outline: ChocoLogColors.border,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ChocoLogColors.canvas,
      dividerColor: ChocoLogColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: ChocoLogColors.canvas,
        foregroundColor: ChocoLogColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ChocoLogColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: ChocoLogColors.ink,
          backgroundColor: ChocoLogColors.yellow,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: ChocoLogColors.yellow.withValues(alpha: 0.3),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        height: 68,
      ),
    );
  }
}
