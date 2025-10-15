import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF00FF88);
  static const Color darkBackground = Color(0xFF0A0E1A);
  static const Color cardBackground = Color(0xFF141823);
  static const Color foreground = Color(0xFFF8F9FA);
  static const Color mutedForeground = Color(0xFFA0A0A0);
  static const Color border = Color(0xFF2A2E3A);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.dark(
        primary: primaryGreen,
        secondary: primaryGreen,
        surface: cardBackground,
        background: darkBackground,
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      iconTheme: IconThemeData(color: mutedForeground),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: mutedForeground),
      ),
    );
  }
}
