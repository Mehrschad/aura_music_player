import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/song.dart';
import '../../providers/playback_providers.dart';
import '../artwork/aura_artwork.dart';
import '../press_scale.dart';
import 'now_playing_indicator.dart';

/// Standard library row: thumbnail · title / artist · album · duration · menu.
///
/// The row that is currently playing is set apart with a soft accent halo
/// around it and a small dancing-bars indicator beside the duration, so it's
/// always obvious which track is live as you browse.
class SongListTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isCurrent =
        ref.watch(currentSongProvider.select((s) => s?.id == song.id));
    final playing = isCurrent &&
        ref.watch(playbackStateProvider
            .select((st) => st.valueOrNull?.playing ?? false));
    final accent = SeedPalette.accent(song.artworkSeed);

    return PressScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: '${song.title}, ${song.artist}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          borderRadius: RadiusTokens.brMd,
          color: isCurrent ? accent.withOpacity(0.07) : Colors.transparent,
          border: Border.all(
            color:
                isCurrent ? accent.withOpacity(0.22) : Colors.transparent,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.16),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
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
                      style: AppTextTheme.title.copyWith(
                        color: isCurrent ? accent : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} · ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              if (isCurrent) ...[
                NowPlayingIndicator(color: accent, animating: playing),
                const SizedBox(width: SpacingTokens.sm),
              ],
              Text(
                song.duration.clock,
                style:
                    AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
              ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert,
                      size: 20, color: colors.onSurfaceFaint),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
