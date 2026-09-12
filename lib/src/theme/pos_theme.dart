import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pyx POS visual tokens — restrained Operate palette for shop-floor Android.
abstract final class PosColors {
  static const forest = Color(0xFF145C45);
  static const forestDeep = Color(0xFF0B3D2E);
  static const forestSoft = Color(0xFFE6F0EB);
  static const gold = Color(0xFFC8900A);
  static const goldDeep = Color(0xFFA67508);
  static const ink = Color(0xFF14201C);
  static const muted = Color(0xFF5A6B63);
  static const line = Color(0xFFD5DDD8);
  static const surface = Color(0xFFF3F5F4);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFF8E8E6);
}

ThemeData buildPosTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: PosColors.forest,
    onPrimary: Colors.white,
    primaryContainer: PosColors.forestSoft,
    onPrimaryContainer: PosColors.forestDeep,
    secondary: PosColors.gold,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF7EDD4),
    onSecondaryContainer: Color(0xFF5C4500),
    tertiary: PosColors.forestDeep,
    onTertiary: Colors.white,
    error: PosColors.danger,
    onError: Colors.white,
    errorContainer: PosColors.dangerSoft,
    onErrorContainer: PosColors.danger,
    surface: PosColors.surface,
    onSurface: PosColors.ink,
    onSurfaceVariant: PosColors.muted,
    outline: PosColors.line,
    outlineVariant: Color(0xFFE4EAE6),
    shadow: Color(0x3314201C),
    scrim: Color(0x6614201C),
    inverseSurface: PosColors.forestDeep,
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFF8BCFB4),
    surfaceTint: PosColors.forest,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PosColors.surface,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: PosColors.surface,
      foregroundColor: PosColors.ink,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: PosColors.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: PosColors.forestSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? PosColors.forest : PosColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? PosColors.forest : PosColors.muted,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PosColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PosColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PosColors.forest, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PosColors.danger),
      ),
      labelStyle: const TextStyle(color: PosColors.muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: PosColors.forest, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PosColors.forest,
        foregroundColor: Colors.white,
        disabledBackgroundColor: PosColors.line,
        disabledForegroundColor: PosColors.muted,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PosColors.forestDeep,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: PosColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PosColors.forest,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PosColors.forestDeep,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: PosColors.line, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 4),
      iconColor: PosColors.muted,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: PosColors.ink,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.15,
        color: PosColors.ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: PosColors.ink,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: PosColors.ink,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.35, color: PosColors.ink),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.4, color: PosColors.ink),
      bodySmall: const TextStyle(fontSize: 12.5, height: 1.35, color: PosColors.muted),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PosColors.ink),
    ),
  );
}

SystemUiOverlayStyle get posSystemUi => const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
