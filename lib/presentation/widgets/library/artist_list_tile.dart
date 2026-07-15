import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/icon_sizes.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/artist.dart';
import '../../providers/artist_favorites_providers.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';

class ArtistListTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isFav = ref.watch(isArtistFavoriteProvider(artist.id));
    return PressScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: artist.name,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.sm,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          children: [
            // Round artist avatar (DS: 56px · pill radius).
            AuraArtwork(
              seed: artist.artworkSeed,
              size: 56,
              borderRadius: RadiusTokens.brPill,
              hasArtwork: artist.hasArtwork,
              artworkId: artist.firstSongId,
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
                  const SizedBox(height: SpacingTokens.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            if (isFav) ...[
              Icon(Icons.favorite, size: 16, color: colors.favorite),
              const SizedBox(width: SpacingTokens.sm),
            ],
            Icon(Icons.chevron_right,
                size: IconSizes.md, color: colors.onSurfaceFaint),
          ],
        ),
      ),
    );
  }
}
