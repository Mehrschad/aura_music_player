import 'package:flutter/material.dart';

/// Aura's type scale — the exact iOS type scale (Liquid Glass / iOS 26-27),
/// rebuilt per the design spec §3.
///
/// Latin runs on **Inter** (a near-SF face); Persian/Arabic fall back to the
/// platform's Arabic face (Vazirmatn once bundled). The family is referenced by
/// name — if the `.ttf` is absent the engine falls back to the platform sans,
/// so the app always renders.
///
/// Two surfaces are exposed:
///   1. the canonical iOS roles — [largeTitle], [title1], … [caption2];
///   2. legacy aliases ([heroTitle], [display], [title], [body], [caption],
///      [navLabel], [action]) kept so existing widgets compile unchanged, each
///      remapped onto the new scale.
///
/// Colour is intentionally left null — applied at the call site from
/// [AppColors] so one style works across every theme.
abstract final class AppTextTheme {
  const AppTextTheme._();

  static const String fontFamily = 'Inter';

  /// Persian/Arabic face. Falls back to the platform Arabic font until the
  /// Vazirmatn `.ttf` weights are bundled.
  static const String fontFamilyFarsi = 'Vazirmatn';

  /// Tabular figures for timers/durations (monospaced digits, spec §3).
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ── Canonical iOS type scale (spec §3) ─────────────────────────────────
  // size · weight · line-height(px) → height factor = lh / size.

  /// 34 / 400 / 41 — the big screen title ("Library") before it morphs to
  /// [headline] pinned in the nav bar on scroll.
  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  /// 28 / 400 / 34.
  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  /// 22 / 400 / 28.
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// 20 / 400 / 25.
  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 25 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// 17 / 600 / 22 — emphasis tier; same size as [body], heavier weight.
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// 17 / 400 / 22 — iOS "body": primary reading line. In Aura's denser layout
  /// this is reserved for genuine primary/reading text; secondary metadata uses
  /// [subhead] (which the legacy [body] alias points at — see below).
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w400,
  );

  /// 16 / 400 / 21.
  static const TextStyle callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 21 / 16,
    fontWeight: FontWeight.w400,
  );

  /// 15 / 400 / 20 — secondary text (artist · album) in a muted colour.
  static const TextStyle subhead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
  );

  /// 13 / 400 / 18.
  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  /// 12 / 400 / 16.
  static const TextStyle caption1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// 11 / 400 / 13 — the floor; never go below this (spec §3).
  static const TextStyle caption2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  /// [headline] / [body] with tabular figures — for the scrubber's
  /// elapsed/remaining timers so digits don't jitter as they tick.
  static const TextStyle timer = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  // ── Legacy aliases (remapped onto the iOS scale) ───────────────────────
  // Kept so the existing presentation layer compiles while it is migrated.

  /// Now-Playing song title hero. → [title2] semibold.
  static const TextStyle heroTitle = title2;

  /// Section / page headers. → [title1] semibold.
  static const TextStyle display = title1;

  /// Secondary / metadata text (artist · album · captions-plus). Historically
  /// Aura's `body` was 14pt secondary text, so it maps onto [subhead] (15),
  /// NOT the iOS 17pt body — that lives in [bodyLarge]. Keeps the ~120 existing
  /// call sites at the right secondary tier.
  static const TextStyle body = subhead;

  /// List item primary line. → 17 / 500 (body weight nudged for emphasis).
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  /// Caption / metadata. → [caption1].
  static const TextStyle caption = caption1;

  /// Tab labels on the glass nav bar. → 11 / 500.
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Primary action / button label. → 15 / 600.
  static const TextStyle action = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Builds the Material [TextTheme] so framework widgets inherit the scale.
  static TextTheme materialTextTheme(Color onSurface) {
    final base = const TextTheme(
      displayLarge: largeTitle,
      displayMedium: title1,
      displaySmall: title2,
      headlineMedium: title3,
      headlineSmall: headline,
      titleLarge: title2,
      titleMedium: title,
      titleSmall: subhead,
      bodyLarge: bodyLarge,
      bodyMedium: bodyLarge,
      bodySmall: footnote,
      labelLarge: action,
      labelMedium: caption1,
      labelSmall: navLabel,
    );
    return base.apply(
      fontFamily: fontFamily,
      bodyColor: onSurface,
      displayColor: onSurface,
    );
  }
}
