import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/artist.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

/// Photo-forward artist cell for the artists grid: a large circular avatar
/// floating on a soft shadow, with the name and a "N albums · M songs" line
/// centred underneath. A small heart badge marks favourited artists.
///
/// The avatar sizes itself off the cell the grid hands it (via [LayoutBuilder]),
/// so it never overflows regardless of the grid's `mainAxisExtent`.
class ArtistGridTile extends StatelessWidget {
  const ArtistGridTile({
    super.key,
    required this.artist,
    required this.subtitle,
    required this.onTap,
    this.isFavorite = false,
  });

  final Artist artist;
  final VoidCallback onTap;

  /// Pre-formatted "N albums · M songs" string (built with l10n at call site).
  final String subtitle;

  /// When true a small heart badge is drawn on the avatar.
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PressScale(
      onTap: onTap,
      semanticLabel: artist.name,
      child: LayoutBuilder(
        builder: (context, c) {
          // Reserve room for the two-line caption; the avatar takes the rest,
          // capped to the cell width so it stays a circle.
          const textBlock = 46.0;
          final maxAvatar = (c.maxHeight - textBlock).clamp(0.0, c.maxWidth);
          final avatarSize = c.maxWidth.clamp(0.0, maxAvatar).toDouble();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
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
                        seed: artist.artworkSeed,
                        size: avatarSize,
                        borderRadius: RadiusTokens.brPill,
                        hasArtwork: artist.hasArtwork,
                        artworkId: artist.firstSongId,
                      ),
                    ),
                    if (isFavorite)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: colors.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite,
                            size: 13,
                            color: colors.favorite,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextTheme.body.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
              ),
            ],
          );
        },
      ),
    );
  }
}
