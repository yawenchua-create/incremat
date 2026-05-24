import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.2,
  );

  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
    height: 1.3,
  );

  static TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.espresso,
  );

  static TextStyle headlineMedium = GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.espresso,
  );

  static TextStyle headlineSmall = GoogleFonts.playfairDisplay(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.espresso,
  );

  static TextStyle titleLarge = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.espresso,
    letterSpacing: 0.2,
  );

  static TextStyle titleMedium = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.espresso,
    letterSpacing: 0.1,
  );

  static TextStyle bodyLarge = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.espresso,
  );

  static TextStyle bodyMedium = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.espresso,
  );

  static TextStyle bodySmall = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.subtleText,
  );

  static TextStyle labelLarge = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.espresso,
    letterSpacing: 0.5,
  );

  static TextStyle labelMedium = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.subtleText,
    letterSpacing: 0.4,
  );

  static TextStyle caption = GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.subtleText,
    letterSpacing: 0.3,
  );

  static TextStyle overline = GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.subtleText,
    letterSpacing: 1.5,
  );

  static TextStyle statNumber = GoogleFonts.playfairDisplay(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
  );

  static TextStyle statMedium = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
  );

  static TextStyle buttonText = GoogleFonts.montserrat(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );
}
