import 'package:flutter/material.dart';

const Color primaryBlue = Color(0xFF2563EB);
const Color paleBlue = Color(0xFFEFF6FF);
const Color darkBlue = Color(0xFF0F2744);
const Color backgroundColor = Color(0xFFF8FAFC);

class AppColors {
  static const Color primary = primaryBlue;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color pale = paleBlue;
  static const Color dark = darkBlue;
  static const Color background = backgroundColor;
}

extension WashCareColors on BuildContext {
  ColorScheme get _scheme => Theme.of(this).colorScheme;
  bool get isDarkTheme => _scheme.brightness == Brightness.dark;

  Color get pageSurface => isDarkTheme ? _scheme.surface : backgroundColor;
  Color get cardSurface => isDarkTheme ? _scheme.surfaceContainer : Colors.white;
  Color get insetSurface =>
      isDarkTheme ? _scheme.surfaceContainerHigh : const Color(0xFFF4F7FB);
  Color get cardOutline =>
      isDarkTheme ? _scheme.outlineVariant : const Color(0xFFE4ECF5);
  Color get headingColor => isDarkTheme ? _scheme.onSurface : darkBlue;
  Color get detailColor => isDarkTheme ? _scheme.onSurface : Colors.black87;
  Color get mutedColor => isDarkTheme ? _scheme.onSurfaceVariant : Colors.black54;
  Color get accentColor => isDarkTheme ? _scheme.primary : primaryBlue;
  Color get accentSurface =>
      isDarkTheme ? _scheme.primaryContainer : paleBlue;
}
