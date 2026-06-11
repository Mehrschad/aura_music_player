import 'package:flutter/material.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

/// Standard library row: thumbnail · title / artist · album · duration · menu.
class SongListTile extends StatelessWidget {
  const SongListTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMore,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: '${song.title}, ${song.artist}',
      child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.xs,
            vertical: SpacingTokens.sm,
          ),
          child: Row(
            children: [
              AuraArtwork(
            seed: song.artworkSeed,
            size: 48,
            hasArtwork: song.hasArtwork,
            artworkId: int.tryParse(song.id),
          ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.title.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} \u00b7 ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                song.duration.clock,
                style: AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
              ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert, size: 20, color: colors.onSurfaceFaint),
                ),
            ],
          ),
        ),
    );
  }
}
