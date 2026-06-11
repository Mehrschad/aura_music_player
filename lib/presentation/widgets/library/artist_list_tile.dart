import 'package:flutter/material.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/artist.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

class ArtistListTile extends StatelessWidget {
  const ArtistListTile({
    super.key,
    required this.artist,
    required this.onTap,
    required this.subtitle,
  });

  final Artist artist;
  final VoidCallback onTap;

  /// Pre-formatted "N albums - M songs" string (built with l10n at call site).
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: artist.name,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xs,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          children: [
            ClipOval(
              child: AuraArtwork(
                seed: artist.artworkSeed,
                size: 48,
                borderRadius: RadiusTokens.brXs,
                hasArtwork: artist.hasArtwork,
                artworkId: artist.firstSongId,
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextTheme.title.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.onSurfaceFaint),
          ],
        ),
      ),
    );
  }
}
