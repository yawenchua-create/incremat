import 'package:flutter/material.dart';
// google_fonts downloads/caches web fonts at runtime so we don't have to bundle
// the .ttf files ourselves. playfairDisplay = elegant serif (titles), montserrat
// = clean sans-serif (body) — the two halves of the IncreMat brand pairing.
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central catalogue of every text style in the app. Defining them once here
/// (instead of writing `TextStyle(...)` inline on each screen) keeps typography
/// consistent and means a font/size tweak happens in exactly one place.
///
/// `static` = you use them without creating an object: `AppTextStyles.bodyLarge`.
/// They're grouped by role, largest → smallest:
///   display*  → big hero/serif text   headline* → section headers (serif)
///   title*    → emphasised labels      body*     → normal paragraph text
///   label*/caption/overline → small UI text   stat* → big numbers on cards
class AppTextStyles {
  // --- Display: the largest serif text, for hero moments. height:1.2 sets the
  //     line spacing to 1.2× the font size so multi-line headings aren't cramped.
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

  // --- Headline: serif section headers. w600 = semi-bold weight.
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

  // --- Title: emphasised sans-serif labels (card titles, list headers).
  //     letterSpacing nudges characters apart for a cleaner look at this size.
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

  // --- Body: normal paragraph text. w400 = regular (un-bolded) weight.
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

  // --- Label / caption / overline: the smallest UI text (hints, timestamps,
  //     all-caps section eyebrows). subtleText is the muted grey-brown colour.
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

  // --- Stat: oversized serif numerals for the big numbers on dashboard cards
  //     (rep counts, scores). statNumber is the largest; statMedium a step down.
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
