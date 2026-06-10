import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/theme/color_scheme.dart';

/// Renders album/track artwork.
///
/// When [artworkId] is provided (the integer media-store ID), the widget loads
/// the real embedded art via [QueryArtworkWidget] and falls back to the
/// deterministic placeholder gradient when no art is found.
class AuraArtwork extends StatelessWidget {
  const AuraArtwork({
    super.key,
    required this.seed,
    this.size = 48,
    this.borderRadius = RadiusTokens.brXs,
    this.hasArtwork = false,
    this.artworkId,
    this.isAlbum = false,
  });

  final String seed;
  final double size;
  final BorderRadius borderRadius;
  final bool hasArtwork;

  /// Integer media-store ID from [on_audio_query]. When non-null, real artwork
  /// is requested; null falls back to the placeholder.
  final int? artworkId;

  /// True when this represents album art (uses [ArtworkType.ALBUM]); false
  /// (default) for individual track art ([ArtworkType.AUDIO]).
  final bool isAlbum;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(
      seed: seed,
      size: size,
      hasArtwork: hasArtwork,
    );

    // Load artwork at the physical pixel resolution so it looks sharp on
    // high-DPI screens — requesting only the logical-pixel size would cause
    // the bitmap to be upscaled (e.g. 3× on a dense display) and look blurry.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final physSize = (size * dpr).ceilToDouble();

    final child = artworkId != null
        ? QueryArtworkWidget(
            id: artworkId!,
            type: isAlbum ? ArtworkType.ALBUM : ArtworkType.AUDIO,
            artworkWidth: physSize,
            artworkHeight: physSize,
            artworkBorder: BorderRadius.zero,
            artworkFit: BoxFit.cover,
            artworkQuality: FilterQuality.high,
            keepOldArtwork: true,
            nullArtworkWidget: placeholder,
          )
        : placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF181820),
        child: child,
      ),
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
