import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Derives a calm, muted colour from an artwork [seed] (an album id).
///
/// This stands in for runtime dominant-colour extraction: on device, once real
/// artwork bytes exist, `palette_dart` replaces [accent] / [wash] with a colour
/// pulled from the image. Until then this keeps the Now Playing wash and accent
/// stable, harmonious with [AuraArtwork] (which derives its gradient from the
/// same hue), and — crucially — never garish: saturation is clamped to 40% and
/// value kept moderate, exactly as the design spec requires.
abstract final class SeedPalette {
  const SeedPalette._();

  /// Maximum saturation. Kept slightly below 0.40 so that the HSV→RGB→HSV
  /// round-trip never exceeds the 40% design cap (8-bit RGB quantisation
  /// can inflate saturation by ~0.002).
  static const double _maxSaturation = 0.38;

  static double hueFor(String seed) => (seed.hashCode % 360).abs().toDouble();

  /// A vivid-but-clamped accent for fills (scrubber progress, active controls).
  static Color accent(String seed) =>
      HSVColor.fromAHSV(1, hueFor(seed), _maxSaturation, 0.82).toColor();

  /// A darker, muted variant for the full-screen background wash. Apply at low
  /// opacity (the Now Playing screen uses ~18%).
  static Color wash(String seed) =>
      HSVColor.fromAHSV(1, hueFor(seed), _maxSaturation, 0.50).toColor();
}

/// A vivid accent + darker wash pair for the Now Playing ambient lights.
///
/// Prefers colours pulled from the *real* album cover (see
/// [coverPaletteProvider], which feeds the dominant colour here), falling back
/// to the deterministic [SeedPalette] when no artwork is available or extraction
/// fails. Unlike [SeedPalette] the saturation cap is relaxed so cover-derived
/// colours read as rich rather than washed-out, as the Now Playing redesign asks.
@immutable
class CoverPalette {
  const CoverPalette(this.accent, this.wash);

  final Color accent;
  final Color wash;

  /// Deterministic fallback from an album [seed].
  factory CoverPalette.fromSeed(String seed) =>
      CoverPalette(SeedPalette.accent(seed), SeedPalette.wash(seed));

  /// Builds a harmonious accent/wash pair from a single dominant cover [color].
  /// Saturation is lifted into a tasteful band (35–72 %) so even a muted cover
  /// yields a colour with presence, while a neon cover is reined in.
  factory CoverPalette.fromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    final sat = hsv.saturation.clamp(0.35, 0.72).toDouble();
    final hue = hsv.hue;
    return CoverPalette(
      HSVColor.fromAHSV(1, hue, sat, 0.84).toColor(),
      HSVColor.fromAHSV(1, hue, sat, 0.50).toColor(),
    );
  }
}
