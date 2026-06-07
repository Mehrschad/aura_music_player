/// Spacing scale for Aura.
///
/// Every gap, padding, and margin in the app resolves to one of these.
/// Widgets must never use raw numeric spacing values.
abstract final class SpacingTokens {
  const SpacingTokens._();

  /// 2.0 — hairline gaps (e.g. waveform bar spacing).
  static const double xxs = 2;

  /// 4.0
  static const double xs = 4;

  /// 8.0
  static const double sm = 8;

  /// 12.0
  static const double md = 12;

  /// 16.0 — the default screen edge inset.
  static const double lg = 16;

  /// 20.0
  static const double xl = 20;

  /// 24.0
  static const double xxl = 24;

  /// 32.0
  static const double xxxl = 32;

  /// 48.0 — large vertical rhythm between major sections.
  static const double huge = 48;
}
