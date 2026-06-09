import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/album.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

class AlbumGridTile extends StatelessWidget {
  const AlbumGridTile({super.key, required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              builder: (context, c) => AuraArtwork(
                seed: album.artworkSeed,
                size: c.maxWidth,
                borderRadius: RadiusTokens.brMd,
                hasArtwork: album.hasArtwork,
                artworkId: int.tryParse(album.id),
                isAlbum: true,
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextTheme.title.copyWith(color: colors.onSurface),
          ),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
