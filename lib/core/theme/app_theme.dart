import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NariRakshak design tokens — extracted from the JSX wireframe mockup.
class AppColors {
  AppColors._();

  static const Color bgDeep = Color(0xFF1B2430);
  static const Color bg = Color(0xFFF8F4FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF1E8F8);
  static const Color border = Color(0x171B2430); // rgba(27,36,48,0.09)
  static const Color amber = Color(0xFFE0993A);
  static const Color amberDim = Color(0xFFB98426);
  static const Color coral = Color(0xFFFF5A5F);
  static const Color green = Color(0xFF3FAE6E);
  static const Color text = Color(0xFF1B2430);
  static const Color muted = Color(0xFF5B6472);
  static const Color faint = Color(0xFF8B94A3);
}

/// Text styles using the three typefaces from the wireframe.
class AppTextStyles {
  AppTextStyles._();

  // — Display / heading (Fraunces) —
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.text,
    FontStyle fontStyle = FontStyle.normal,
  }) => GoogleFonts.fraunces(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontStyle: fontStyle,
    letterSpacing: 0.2,
  );

  // — Body / UI text (Manrope) —
  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.text,
  }) => GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  // — Monospace / stats (JetBrains Mono) —
  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.text,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

/// App-wide ThemeData.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.amber,
      secondary: AppColors.coral,
      surface: AppColors.surface,
      onPrimary: AppColors.bgDeep,
      onSurface: AppColors.text,
    ),
    textTheme: TextTheme(
      headlineLarge: AppTextStyles.display(
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: AppTextStyles.display(fontSize: 22),
      headlineSmall: AppTextStyles.display(fontSize: 19),
      bodyLarge: AppTextStyles.body(fontSize: 14),
      bodyMedium: AppTextStyles.body(fontSize: 13),
      bodySmall: AppTextStyles.body(fontSize: 11, color: AppColors.faint),
      labelSmall: AppTextStyles.mono(fontSize: 11),
    ),
  );
}
