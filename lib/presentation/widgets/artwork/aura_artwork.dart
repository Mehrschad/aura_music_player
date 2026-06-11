import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import 'artwork_image_provider.dart';

/// Renders album/track artwork.
///
/// When [artworkId] is provided (the integer song media-store ID), the widget
/// loads the embedded cover art via [ArtworkImageProvider] (reads directly from
/// the audio file at up to 2048 px, cached once per song across all sizes) and
/// falls back to the deterministic placeholder gradient when no art is found.
class AuraArtwork extends StatelessWidget {
  const AuraArtwork({
    super.key,
    required this.seed,
    this.size = 48,
    this.borderRadius = RadiusTokens.brXs,
    this.hasArtwork = false,
    this.artworkId,
  });

  final String seed;
  final double size;
  final BorderRadius borderRadius;
  final bool hasArtwork;

  /// Integer media-store song ID from [on_audio_query]. When non-null, real
  /// artwork is requested; null falls back to the placeholder.
  final int? artworkId;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(
      seed: seed,
      size: size,
      hasArtwork: hasArtwork,
    );

    final child = artworkId != null
        ? Image(
            image: ArtworkImageProvider(id: artworkId!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            // Show placeholder until the first decoded frame arrives.
            frameBuilder: (context, child, frame, _) =>
                frame == null ? placeholder : child,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.seed,
    required this.size,
    required this.hasArtwork,
  });

  final String seed;
  final double size;
  final bool hasArtwork;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hue = (seed.hashCode % 360).abs().toDouble();
    final sat = hasArtwork ? 0.26 : 0.16;
    final sat2 = hasArtwork ? 0.22 : 0.12;
    final base = HSVColor.fromAHSV(1, hue, sat, 0.42).toColor();
    final lighter = HSVColor.fromAHSV(1, (hue + 18) % 360, sat2, 0.30).toColor();

    return DecoratedBox(
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
    );
  }
}
