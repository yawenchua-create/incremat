import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.sageGreen,
        secondary: AppColors.terracotta,
        surface: AppColors.warmCream,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.espresso,
      ),
      scaffoldBackgroundColor: AppColors.warmCream,
      textTheme: GoogleFonts.montserratTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: AppColors.espresso,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.espresso,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.espresso,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.espresso,
        ),
        bodyLarge: GoogleFonts.montserrat(
          fontSize: 16,
          color: AppColors.espresso,
        ),
        bodyMedium: GoogleFonts.montserrat(
          fontSize: 14,
          color: AppColors.espresso,
        ),
        bodySmall: GoogleFonts.montserrat(
          fontSize: 12,
          color: AppColors.subtleText,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.espresso),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.espresso,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.warmCream,
        indicatorColor: AppColors.lightSage,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.sageGreen, size: 22);
          }
          return const IconThemeData(color: AppColors.subtleText, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.sageGreen,
            );
          }
          return GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.subtleText,
          );
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sageGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          textStyle: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5),
        ),
        errorStyle: GoogleFonts.montserrat(
          fontSize: 12,
          color: AppColors.terracotta,
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: AppColors.subtleText,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.warmCream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.espresso,
        ),
        contentTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: AppColors.subtleText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
