import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Light-mode theme. The designs are light mode only.
ThemeData buildWheelioTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: WColors.primary,
      primary: WColors.primary,
      onPrimary: WColors.white,
      secondary: WColors.success,
      error: WColors.destructive,
      surface: WColors.white,
      onSurface: WColors.heading,
    ),
    scaffoldBackgroundColor: WColors.white,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.robotoTextTheme(base.textTheme).apply(
      bodyColor: WColors.body,
      displayColor: WColors.heading,
    ),
    dividerColor: WColors.divider,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: WColors.primary),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: WColors.inverse,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}
