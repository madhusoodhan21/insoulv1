import 'package:flutter/material.dart';

/// Responsive scaling utility for mobile-first design.
/// Scales font sizes and dimensions based on screen width.
class ResponsiveScale {
  static const double mobileBreakpoint = 600;
  static const double mobileScale = 0.95; // 5% reduction for small screens
  static const double tabletScale = 1.0; // No change for larger screens

  /// Get the device scale factor based on screen width
  static double getScaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < mobileBreakpoint ? mobileScale : tabletScale;
  }

  /// Scale a font size based on device width
  static double scaleFontSize(BuildContext context, double baseSize) {
    return baseSize * getScaleFactor(context);
  }

  /// Scale padding/spacing based on device width
  static double scaleSpacing(BuildContext context, double baseSize) {
    final scale = getScaleFactor(context);
    return baseSize * scale;
  }
}
