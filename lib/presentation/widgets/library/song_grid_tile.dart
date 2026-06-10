import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

/// Artwork tile for the grid display mode: square art, title + artist below.
class SongGridTile extends StatelessWidget {
  const SongGridTile({super.key, required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      semanticLabel: '${song.title}, ${song.artist}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, c) => AuraArtwork(
                seed: song.artworkSeed,
                size: c.maxWidth,
                borderRadius: RadiusTokens.brMd,
                hasArtwork: song.hasArtwork,
                artworkId: int.tryParse(song.id),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextTheme.title.copyWith(color: colors.onSurface),
          ),
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
