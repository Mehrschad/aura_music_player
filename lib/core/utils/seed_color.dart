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

  /// Maximum saturation, per the "clamp saturation to 40%" rule.
  static const double _maxSaturation = 0.40;

  static double hueFor(String seed) => (seed.hashCode % 360).abs().toDouble();

  /// A vivid-but-clamped accent for fills (scrubber progress, active controls).
  static Color accent(String seed) =>
      HSVColor.fromAHSV(1, hueFor(seed), _maxSaturation, 0.82).toColor();

  /// A darker, muted variant for the full-screen background wash. Apply at low
  /// opacity (the Now Playing screen uses ~18%).
  static Color wash(String seed) =>
      HSVColor.fromAHSV(1, hueFor(seed), _maxSaturation, 0.50).toColor();
}
