import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/theme/color_scheme.dart';

/// Renders album/track artwork.
///
/// Until real artwork bytes are available (device scan + Isar thumbnail cache,
/// step 2 on-device), this draws a deterministic, on-brand placeholder: a
/// muted two-stop gradient whose hue is derived from [seed], saturation kept
/// low (~0.22) and value modest so it never turns garish on AMOLED — the same
/// restraint the dynamic-color wash will follow. A faint note glyph sits
/// centred so empty art still reads as "music".
///
/// The hue is stable per [seed] (an album id), so every track on an album
/// shares one placeholder — exactly how real album art would behave.
class AuraArtwork extends StatelessWidget {
  const AuraArtwork({
    super.key,
    required this.seed,
    this.size = 48,
    this.borderRadius = RadiusTokens.brXs,
    this.hasArtwork = false,
  });

  final String seed;
  final double size;
  final BorderRadius borderRadius;

  /// When true, a real image would be shown. We don't have bytes in this
  /// scaffold, so we still render the placeholder but tint it slightly richer
  /// to distinguish "art exists, not yet loaded" from "no art".
  final bool hasArtwork;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hue = (seed.hashCode % 360).abs().toDouble();
    final base = HSVColor.fromAHSV(1, hue, hasArtwork ? 0.26 : 0.16, 0.42).toColor();
    final lighter =
        HSVColor.fromAHSV(1, (hue + 18) % 360, hasArtwork ? 0.22 : 0.12, 0.30)
            .toColor();

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [lighter, base],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.42,
              color: colors.onSurface.withOpacity(0.18),
            ),
          ),
        ),
      ),
    );
  }
}
