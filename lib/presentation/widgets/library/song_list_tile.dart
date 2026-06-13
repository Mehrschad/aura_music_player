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
///
/// When [selected] is non-null the row is in **selection mode**: it shows a
/// check circle instead of the overflow button, [onTap] toggles the pick, and
/// [onLongPress] extends a range. The now-playing halo is suppressed so the
/// selection state reads cleanly.
class SongListTile extends ConsumerWidget {
  const SongListTile({
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

  /// Null = not in selection mode. true/false = selected state in selection mode.
  final bool? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selecting = selected != null;
    final isSelected = selected ?? false;

    final isCurrent = !selecting &&
        ref.watch(currentSongProvider.select((s) => s?.id == song.id));
    final playing = isCurrent &&
        ref.watch(playbackStateProvider
            .select((st) => st.valueOrNull?.playing ?? false));
    final accent = SeedPalette.accent(song.artworkSeed);

    final highlight = isSelected || isCurrent;
    final highlightColor = isSelected ? colors.accent : accent;

    return PressScale(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.97,
      semanticLabel: '${song.title}, ${song.artist}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          borderRadius: RadiusTokens.brMd,
          color: highlight ? highlightColor.withOpacity(0.07) : Colors.transparent,
          border: Border.all(
            color: highlight
                ? highlightColor.withOpacity(0.22)
                : Colors.transparent,
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
              if (selecting) ...[
                _SelectCheck(selected: isSelected),
                const SizedBox(width: SpacingTokens.sm),
              ],
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
              if (!selecting && onMore != null)
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

/// The leading check circle shown in selection mode.
class _SelectCheck extends StatelessWidget {
  const _SelectCheck({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? colors.accent : colors.onSurfaceFaint,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 16, color: colors.background)
          : null,
    );
  }
}
