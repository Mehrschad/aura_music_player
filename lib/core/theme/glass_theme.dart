/// Liquid Glass configuration.
///
/// Glass is used with restraint — only on the Now Playing overlay, the bottom
/// nav bar, modal sheets, and the queue panel. The intensity maps to the
/// blur sigma so the Settings "Liquid Glass intensity" control (Off / Subtle /
/// Medium / Strong) resolves to a real value here.
enum GlassIntensity {
  off(0),
  subtle(16),
  medium(22),
  strong(32);

  const GlassIntensity(this.sigma);

  /// `BackdropFilter` blur sigma (X and Y).
  final double sigma;
}

abstract final class GlassTokens {
  const GlassTokens._();

  static const GlassIntensity defaultIntensity = GlassIntensity.strong;

  /// Inner-highlight border width on glass edges.
  static const double borderWidth = 1;
}
