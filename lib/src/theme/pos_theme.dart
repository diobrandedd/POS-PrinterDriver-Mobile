import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dense Swiss-style POS tokens. Pyx forest brand + emerald charge CTA (Square-like).
abstract final class PosColors {
  static const forest = Color(0xFF145C45);
  static const forestDeep = Color(0xFF0B3D2E);
  static const forestSoft = Color(0xFFE4F0EA);
  static const charge = Color(0xFF059669);
  static const chargeDeep = Color(0xFF047857);
  static const gold = Color(0xFFC8900A);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);
  static const line = Color(0xFFE2E8F0);
  static const surface = Color(0xFFF8FAFC);
  static const mutedFill = Color(0xFFF1F5F9);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEE2E2);
}

ThemeData buildPosTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: PosColors.forest,
    onPrimary: Colors.white,
    primaryContainer: PosColors.forestSoft,
    onPrimaryContainer: PosColors.forestDeep,
    secondary: PosColors.charge,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD1FAE5),
    onSecondaryContainer: Color(0xFF064E3B),
    tertiary: PosColors.gold,
    onTertiary: Colors.white,
    error: PosColors.danger,
    onError: Colors.white,
    errorContainer: PosColors.dangerSoft,
    onErrorContainer: PosColors.danger,
    surface: PosColors.surface,
    onSurface: PosColors.ink,
    onSurfaceVariant: PosColors.muted,
    outline: PosColors.line,
    outlineVariant: Color(0xFFEEF2F6),
    shadow: Color(0x330F172A),
    scrim: Color(0x660F172A),
    inverseSurface: PosColors.ink,
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFF86EFAC),
    surfaceTint: PosColors.forest,
  );

  final heading = GoogleFonts.rubikTextTheme();
  final body = GoogleFonts.nunitoSansTextTheme();
  final merged = body.copyWith(
    headlineMedium: heading.headlineMedium?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.15,
      color: PosColors.ink,
    ),
    titleLarge: heading.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: PosColors.ink,
    ),
    titleMedium: heading.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: PosColors.ink,
    ),
    bodyLarge: body.bodyLarge?.copyWith(fontSize: 15, height: 1.35, color: PosColors.ink),
    bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.4, color: PosColors.ink),
    bodySmall: body.bodySmall?.copyWith(fontSize: 12.5, height: 1.35, color: PosColors.muted),
    labelLarge: body.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: PosColors.ink),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PosColors.surface,
    splashFactory: InkRipple.splashFactory,
    textTheme: merged,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: PosColors.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: heading.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: PosColors.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: PosColors.forestSoft,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PosColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PosColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PosColors.forest, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PosColors.danger),
      ),
      labelStyle: const TextStyle(color: PosColors.muted, fontWeight: FontWeight.w600, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: PosColors.forest, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PosColors.forest,
        foregroundColor: Colors.white,
        disabledBackgroundColor: PosColors.line,
        disabledForegroundColor: PosColors.muted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PosColors.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: const BorderSide(color: PosColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PosColors.forest,
        minimumSize: const Size(48, 40),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PosColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: PosColors.line, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PosColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: heading.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: PosColors.ink,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
  );
}

SystemUiOverlayStyle get posSystemUi => const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
