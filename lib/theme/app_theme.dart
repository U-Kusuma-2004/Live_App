import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Daylight instrument-panel palette. Light, calm, structural greys with one
/// cobalt accent for actions. Green / red / amber are reserved for live state
/// and never used as decoration.
class AppColors {
  const AppColors._();

  static const canvas = Color(0xFFF2F4F7); // app background
  static const surface = Color(0xFFFFFFFF); // cards
  static const field = Color(0xFFF6F8FA); // inset inputs

  static const ink = Color(0xFF161C24);
  static const inkSoft = Color(0xFF5C6672);
  static const inkFaint = Color(0xFF98A2B3);
  static const line = Color(0xFFE3E7EC);

  static const brand = Color(0xFF2F5BEA);
  static const brandPressed = Color(0xFF2247C7);
  static const brandWash = Color(0xFFEAF0FE);

  static const go = Color(0xFF0E9F5A);
  static const goPressed = Color(0xFF0B8049);
  static const stop = Color(0xFFE04347);
  static const stopPressed = Color(0xFFBE3438);
  static const caution = Color(0xFFEF9A2E);

  static const console = Color(0xFF1B222C);
  static const consoleHeader = Color(0xFF232C38);
  static const consoleLine = Color(0xFF313C4A);
}

class AppShadows {
  const AppShadows._();

  /// Flat elements that still need to lift off the canvas.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0F1B2A4B), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x121B2A4B), blurRadius: 16, offset: Offset(0, 8)),
  ];

  /// The hero viewfinder — reads as a physical object on the desk.
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x141B2A4B), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1F1B2A4B), blurRadius: 34, offset: Offset(0, 20)),
  ];
}

class AppRadii {
  const AppRadii._();
  static const pill = 999.0;
  static const tile = 12.0;
  static const card = 16.0;
  static const hero = 20.0;
}

/// Monospace stack for numeric readouts and the log console.
const String kMonoFont = 'monospace';

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  // Inter for UI text — clean, neutral, instrument-panel legible. Falls back
  // to the platform font when offline on first launch.
  final textTheme = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  const scheme = ColorScheme.light(
    primary: AppColors.brand,
    onPrimary: Colors.white,
    secondary: AppColors.go,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.stop,
    onError: Colors.white,
    outline: AppColors.line,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.line,
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
        height: 1.4,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.6,
      shadowColor: Color(0x141B2A4B),
      centerTitle: false,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      },
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w400),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.brand, 1.6),
      errorBorder: border(AppColors.stop),
      focusedErrorBorder: border(AppColors.stop, 1.6),
      errorStyle: const TextStyle(color: AppColors.stop, fontWeight: FontWeight.w500),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
