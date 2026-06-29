import 'package:flutter/material.dart';

import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/genre.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

/// A genre row mirroring [ArtistListTile], but with a square-rounded thumbnail
/// (genres aren't people) seeded from a representative track's artwork.
class GenreListTile extends StatelessWidget {
  const GenreListTile({
    super.key,
    required this.genre,
    required this.subtitle,
    required this.onTap,
  });

  final Genre genre;
  final VoidCallback onTap;

  /// Pre-formatted "N songs" string (built with l10n at the call site).
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final label = genre.isUnknown ? l10n.genreUnknown : genre.name;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xs,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: RadiusTokens.brXs,
              child: AuraArtwork(
                seed: genre.artworkSeed,
                size: 48,
                borderRadius: RadiusTokens.brXs,
                hasArtwork: genre.hasArtwork,
                artworkId: genre.firstSongId,
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.title.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: SpacingTokens.xxs),
                  Text(
                    subtitle,
                    style: AppTextTheme.caption
                        .copyWith(color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: IconSizes.md, color: colors.onSurfaceFaint),
          ],
        ),
      ),
    );
  }
}
