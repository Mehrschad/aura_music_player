import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/album.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

/// Artwork-forward album card: generously rounded art floating on a soft
/// shadow, with a tight two-line caption underneath.
class AlbumGridTile extends StatelessWidget {
  const AlbumGridTile({super.key, required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = [
      album.artist,
      if (album.year != null) '${album.year}',
    ].join(' · ');

    return PressScale(
      onTap: onTap,
      semanticLabel: '${album.name}, ${album.artist}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, c) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: RadiusTokens.brLg,
                  boxShadow: [
                    BoxShadow(
                      color: colors.scrim.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: AuraArtwork(
                  seed: album.artworkSeed,
                  size: c.maxWidth,
                  borderRadius: RadiusTokens.brLg,
                  hasArtwork: album.hasArtwork,
                  artworkId: album.firstSongId,
                ),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.sm + 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xxs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.body.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurfaceMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
