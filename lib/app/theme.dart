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

    final baseTextTheme = ThemeData.light().textTheme.apply(
      bodyColor: ChocoLogColors.ink,
      displayColor: ChocoLogColors.ink,
    );
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.25,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.3,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.3,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.35,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: ChocoLogColors.canvas,
      canvasColor: ChocoLogColors.surface,
      dividerColor: ChocoLogColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: ChocoLogColors.surface,
        foregroundColor: ChocoLogColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ChocoLogColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
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
      dialogTheme: DialogThemeData(
        backgroundColor: ChocoLogColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ChocoLogColors.surface,
        modalBackgroundColor: ChocoLogColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ChocoLogColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(ChocoLogColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: ChocoLogColors.ink,
          backgroundColor: ChocoLogColors.yellow,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
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
          textStyle: textTheme.labelLarge,
          side: const BorderSide(color: ChocoLogColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ChocoLogColors.link,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ChocoLogColors.surface,
        labelStyle: textTheme.bodySmall?.copyWith(
          color: ChocoLogColors.muted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: ChocoLogColors.ink,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: ChocoLogColors.muted),
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
        labelStyle: textTheme.labelMedium?.copyWith(color: ChocoLogColors.ink),
      ),
      listTileTheme: ListTileThemeData(
        textColor: ChocoLogColors.ink,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: ChocoLogColors.muted,
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
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
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
        height: 84,
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
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(contentTextStyle: textTheme.bodyMedium),
    );
  }
}
