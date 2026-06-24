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

/// The Liquid-Glass **material levels** (spec §2, §4.6). Where [GlassIntensity]
/// is the user's global preference (a settings slider), [GlassLevel] is the
/// per-surface role: an overlay on artwork is `ultraThin`, the mini player is
/// `thin`, the nav bar / sheets are `regular`, a text-heavy panel is `thick`.
///
/// Each level carries a base blur sigma and a base white-fill opacity (dark
/// mode). The actual sigma a surface renders at is the level's sigma scaled by
/// the user's [GlassIntensity] (see [GlassLevel.sigmaFor]), so the global
/// control still attenuates every surface — and `off` collapses to opaque.
enum GlassLevel {
  ultraThin(6, 0.04),
  thin(10, 0.06),
  regular(14, 0.08),
  thick(20, 0.10);

  const GlassLevel(this.sigma, this.fillOpacity);

  /// Base `BackdropFilter` blur sigma for this material (spec §2).
  final double sigma;

  /// Base white-fill opacity in dark mode (light mode lifts this in the theme).
  final double fillOpacity;

  /// The effective sigma once the user's global [intensity] is applied. The
  /// intensity acts as a multiplier around the `strong` reference so existing
  /// behaviour is preserved; `off` yields 0 (opaque fallback).
  double sigmaFor(GlassIntensity intensity) {
    if (intensity == GlassIntensity.off) return 0;
    return sigma * (intensity.sigma / GlassIntensity.strong.sigma);
  }
}

abstract final class GlassTokens {
  const GlassTokens._();

  static const GlassIntensity defaultIntensity = GlassIntensity.strong;

  /// Default material role when a surface doesn't specify one.
  static const GlassLevel defaultLevel = GlassLevel.regular;

  /// Inner-highlight border width on glass edges.
  static const double borderWidth = 1;

  /// The "refracted glass edge" hairline opacity (spec §2 / §4.6).
  static const double edgeOpacity = 0.18;

  /// Width of the refracted-edge hairline.
  static const double edgeWidth = 0.5;
}
