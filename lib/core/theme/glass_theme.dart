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
  strong(32),

  /// The deepest, most liquid setting — a heavier blur with a richer tint
  /// boost so surfaces read as thick frosted crystal floating over content.
  ultra(48);

  const GlassIntensity(this.sigma);

  /// `BackdropFilter` blur sigma (X and Y).
  final double sigma;

  /// Extra white tint opacity layered on top of the theme's base glass tint.
  /// Only [ultra] adds any — it deepens the frosted look at the highest blur.
  double get extraTint => this == GlassIntensity.ultra ? 0.06 : 0.0;
}

abstract final class GlassTokens {
  const GlassTokens._();

  static const GlassIntensity defaultIntensity = GlassIntensity.strong;

  /// Inner-highlight border width on glass edges.
  static const double borderWidth = 1;
}
