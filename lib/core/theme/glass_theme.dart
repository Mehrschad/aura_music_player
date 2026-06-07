/// Liquid Glass configuration.
///
/// Glass is used with restraint — only on the Now Playing overlay, the bottom
/// nav bar, modal sheets, and the queue panel. The intensity maps to the
/// blur sigma so the Settings "Liquid Glass intensity" control (Off / Subtle /
/// Medium / Strong) resolves to a real value here.
enum GlassIntensity {
  off(0),
  subtle(14),
  medium(18),
  strong(24);

  const GlassIntensity(this.sigma);

  /// `BackdropFilter` blur sigma (X and Y).
  final double sigma;
}

abstract final class GlassTokens {
  const GlassTokens._();

  /// Spec range is sigma 18–24; medium is the default resting value.
  static const GlassIntensity defaultIntensity = GlassIntensity.medium;

  /// Inner-highlight border width on glass edges.
  static const double borderWidth = 1;
}
