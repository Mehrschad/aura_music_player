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
class SongGridTile extends StatelessWidget {
  const SongGridTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.selected,
  });

  final Song song;
  final VoidCallback onTap;
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
