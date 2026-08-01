import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/song.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

/// Artwork tile for the grid display mode: square art, title + artist below.
///
/// When [selected] is non-null the tile is in selection mode: a check badge
/// overlays the artwork, [onTap] toggles, and [onLongPress] extends a range.
/// Outside selection mode [onMore] puts the overflow button on the artwork, so a
/// track offers the same actions in grid mode as in a list.
class SongGridTile extends StatelessWidget {
  const SongGridTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMore,
    this.onLongPress,
    this.selected,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selecting = selected != null;
    final isSelected = selected ?? false;
    return PressScale(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: '${song.title}, ${song.artist}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: RadiusTokens.brMd,
                      border: Border.all(
                        color: isSelected
                            ? colors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AuraArtwork(
                      seed: song.artworkSeed,
                      size: c.maxWidth,
                      borderRadius: RadiusTokens.brMd,
                      hasArtwork: song.hasArtwork,
                      artworkId: int.tryParse(song.id),
                    ),
                  ),
                  if (selecting)
                    Positioned(
                      top: SpacingTokens.xs,
                      right: SpacingTokens.xs,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected ? colors.accent : Colors.white,
                        size: 22,
                      ),
                    )
                  else if (onMore != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onMore,
                          customBorder: const CircleBorder(),
                          child: Container(
                            margin: const EdgeInsets.all(SpacingTokens.xs),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              // Scrim keeps the glyph legible over any artwork.
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.more_vert,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
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
