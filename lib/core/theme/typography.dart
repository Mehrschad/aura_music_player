import 'package:flutter/material.dart';

/// Aura's type scale.
///
/// One family (Inter), disciplined weights:
///   300 metadata · 400 body · 500 emphasis · 600 primary actions only.
/// Widgets must reference these named styles, never inline a [TextStyle].
///
/// Colour is intentionally left null here — it is applied at the call site
/// from [AppColors] so the same style works across themes.
abstract final class AppTextTheme {
  const AppTextTheme._();

  static const String fontFamily = 'Inter';

  /// Now-Playing song title — the hero. 22 / 500.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  /// Section / page headers. 28 / 600.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  /// List item primary line (e.g. song title in a row). 16 / 500.
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  /// Body / artist · album. 14 / 400.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  /// Metadata, timestamps, captions. 12 / 300.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.1,
  );

  /// Tab labels on the glass nav bar. 11 / 500.
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Primary action / button label. 15 / 600 — the only place 600 is used
  /// outside of display headers.
  static const TextStyle action = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Builds the Material [TextTheme] so framework widgets inherit Inter.
  static TextTheme materialTextTheme(Color onSurface) {
    final base = const TextTheme(
      displayLarge: display,
      headlineMedium: heroTitle,
      titleMedium: title,
      bodyMedium: body,
      labelSmall: navLabel,
      bodySmall: caption,
    );
    return base.apply(
      fontFamily: fontFamily,
      bodyColor: onSurface,
      displayColor: onSurface,
    );
  }
}
