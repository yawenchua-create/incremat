import 'package:flutter/material.dart';

/// The caregiver app's brand palette — every colour used in the UI is defined
/// once here and referenced as `AppColors.sageGreen`, so the look stays
/// consistent and re-theming means editing one file.
///
/// `Color(0xFFRRGGBB)` is an ARGB hex literal: the leading `FF` is the alpha
/// (opacity) channel — `FF` = fully opaque — followed by red/green/blue bytes.
class AppColors {
  static const Color sageGreen = Color(0xFF8DA399); // primary brand green (muted)
  static const Color warmCream = Color(0xFFF7F3F0); // app background / canvas
  static const Color terracotta = Color(0xFFD68C7A); // warm accent / secondary
  static const Color espresso = Color(0xFF3E3636);  // main dark text colour
  static const Color lightSage = Color(0xFFD4DDD9); // selected/active tint (nav)
  static const Color mutedSage = Color(0xFFB5C4BC); // softer green for fills
  static const Color cardSurface = Color(0xFFFFFFFF); // white card backgrounds
  static const Color divider = Color(0xFFE8E3DF);   // hairline separators
  static const Color subtleText = Color(0xFF8A7F7F); // muted captions/hints
  static const Color positiveGreen = Color(0xFF6B9B7D); // "good"/success states
  static const Color chartLine = Color(0xFF7A9E8E);  // trend line on graphs
  // The `33` alpha (≈20% opacity) makes this a translucent fill under the
  // chart line — same green as sageGreen but see-through.
  static const Color chartFill = Color(0x338DA399);
}
