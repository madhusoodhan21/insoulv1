import 'package:flutter/material.dart';

/// Dark green-black palette with a bright active green accent.
class AppColors {
  AppColors._();
  static const bg = Color(0xFF060D0B);
  static const surface = Color(0xFF0B1612);
  static const surfaceHi = Color(0xFF10221A);
  static const surfaceHigher = Color(0xFF172C22);
  static const surfaceHighest = Color(0xFF20382B);
  static const border = Color(0xFF31513F);
  static const borderSoft = Color(0x1AFFFFFF); // 10% white per spec

  static const green = Color(0xFF39E98A);
  static const greenBright = Color(0xFF62F6A5);
  static const greenDim = Color(0xFF123B27);
  static const onGreen = Color(0xFF062014);

  static const amber = Color(0xFFE0C245); // connecting / calibrating
  static const amberDim = Color(0xFF4A421A);

  static const red = Color(0xFFFFB4AB); // error
  static const redDim = Color(0xFF3A1418);

  static const sky = Color(0xFF9CB9A7);
  static const skyDim = Color(0xFF20352A);

  static const text = Color(0xFFF0F6F0);
  static const textMid = Color(0xFF9DB8A7);
  static const textDim = Color(0xFF587464);

  // Aliases kept for the couple of legacy screens (calibration/diagnostics)
  // that predate this palette and reference the old names directly.
  static const yellow = amber;
  static const yellowDim = amberDim;
}

/// Font roles from the Stitch design system:
///  - metric   -> Space Grotesk 700 (large data readouts: steps, %, cm)
///  - headline -> Public Sans 700/600 (screen titles, card headings)
///  - body     -> Public Sans 400 (paragraph / label text)
///  - label    -> Public Sans 600, small, letter-spaced (eyebrow labels)
class AppFonts {
  AppFonts._();

  static const String _family = 'Horizon';
  static const String _descriptionFamily = 'Antique Olive Std Nord';

  static TextStyle metric({
    double fontSize = 32,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: _family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.text,
    letterSpacing: letterSpacing ?? -0.02 * fontSize,
    height: 1.05,
  );

  static TextStyle headline({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: _family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.text,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: _family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.text,
    height: height,
  );

  static TextStyle description({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: _descriptionFamily,
    fontFamilyFallback: const ['sans-serif'],
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: FontStyle.italic,
    color: color ?? AppColors.textMid,
    height: height,
  );

  static TextStyle label({
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: _family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textMid,
    letterSpacing: letterSpacing ?? (0.05 * fontSize),
  );

  // Kept for the couple of legacy screens (calibration/diagnostics) that
  // still reference AppFonts.display/dot by name.
  static TextStyle display({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => headline(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

  static TextStyle dot({
    double fontSize = 14,
    Color? color,
    double? letterSpacing,
  }) => metric(fontSize: fontSize, color: color, letterSpacing: letterSpacing);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.bg,
      primary: AppColors.green,
      secondary: AppColors.sky,
      error: AppColors.red,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: AppFonts._family,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: AppColors.borderSoft,
  );
}
