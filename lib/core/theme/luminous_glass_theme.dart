import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuminousTheme {
  static const Color primary = Color(0xFF0058bc);
  static const Color surface = Color(0xFFfaf9fe);
  static const Color glassWhite = Color(0xFFFFFFFF);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        surface: surface,
        primary: primary,
      ),
      // Typography implementation based on Luminous Glass system
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -0.02),
        headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
      ),
    );
  }
}