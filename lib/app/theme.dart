import 'package:flutter/material.dart';

abstract final class ChocoLogColors {
  static const yellow = Color(0xFFFFE62B);
  static const paleYellow = Color(0xFFFFF9D6);
  static const canvas = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF102635);
  static const muted = Color(0xFF6F777D);
  static const border = Color(0xFFDCDCDC);
  static const link = Color(0xFF2687E8);
  static const danger = Color(0xFFF0202A);
}

abstract final class ChocoLogTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: ChocoLogColors.yellow,
          brightness: Brightness.light,
          surface: ChocoLogColors.surface,
        ).copyWith(
          primary: ChocoLogColors.yellow,
          onPrimary: ChocoLogColors.ink,
          primaryContainer: ChocoLogColors.paleYellow,
          onPrimaryContainer: ChocoLogColors.ink,
          secondary: ChocoLogColors.ink,
          onSecondary: ChocoLogColors.surface,
          onSurface: ChocoLogColors.ink,
          surfaceContainerLowest: ChocoLogColors.surface,
          surfaceContainerLow: ChocoLogColors.canvas,
          surfaceContainer: const Color(0xFFF0F0F0),
          outline: ChocoLogColors.border,
          outlineVariant: const Color(0xFFE8E8E8),
          error: ChocoLogColors.danger,
        );

    final textTheme = ThemeData.light().textTheme.apply(
      bodyColor: ChocoLogColors.ink,
      displayColor: ChocoLogColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      scaffoldBackgroundColor: ChocoLogColors.canvas,
      dividerColor: ChocoLogColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: ChocoLogColors.surface,
        foregroundColor: ChocoLogColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ChocoLogColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: ChocoLogColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ChocoLogColors.ink,
          backgroundColor: ChocoLogColors.surface,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          side: const BorderSide(color: ChocoLogColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ChocoLogColors.link,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ChocoLogColors.surface,
        labelStyle: const TextStyle(color: ChocoLogColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ChocoLogColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ChocoLogColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ChocoLogColors.ink, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ChocoLogColors.surface,
        selectedColor: ChocoLogColors.paleYellow,
        side: const BorderSide(color: ChocoLogColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          color: ChocoLogColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ChocoLogColors.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? ChocoLogColors.ink : ChocoLogColors.muted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? ChocoLogColors.ink
                : ChocoLogColors.muted,
            size: 26,
          );
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        height: 78,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ChocoLogColors.paleYellow
                : ChocoLogColors.surface,
          ),
          foregroundColor: const WidgetStatePropertyAll(ChocoLogColors.ink),
          side: const WidgetStatePropertyAll(
            BorderSide(color: ChocoLogColors.border),
          ),
        ),
      ),
    );
  }
}
