import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/motion_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/playback.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../artwork/aura_artwork.dart';
import '../glass/glass_surface.dart';
import '../player_bar_inset.dart';
import 'now_playing_route.dart';

/// The mini player: a Liquid Glass card above the nav bar whenever a track is
/// loaded, with artwork, title/artist, play-pause and skip, and a thin progress
/// line. It collapses away when nothing is playing.
///
/// Gestures: tap (anywhere but the buttons) expands to Now Playing via a
/// shared-element transition; swipe left/right skips with haptic feedback;
/// swipe down dismisses the player. Position rides its own stream so only the
/// progress line repaints as playback advances.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(playbackStateProvider);
    final state = stateAsync.valueOrNull ?? PlaybackState.empty;
    final song = state.currentSong;

    return AnimatedSize(
      duration: MotionTokens.micro,
      curve: MotionTokens.emphasized,
      alignment: Alignment.bottomCenter,
      child: song == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(
                left: MiniPlayerMetrics.horizontalMargin,
                right: MiniPlayerMetrics.horizontalMargin,
                bottom: MiniPlayerMetrics.gapToNavBar,
              ),
              child: _Card(state: state),
            ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final song = state.currentSong!;
    final controller = ref.read(audioControllerProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openNowPlaying(context),
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200 && state.hasNext) {
          HapticFeedback.selectionClick();
          controller.skipToNext();
        } else if (v > 200 && state.hasPrevious) {
          HapticFeedback.selectionClick();
          controller.skipToPrevious();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) {
          HapticFeedback.lightImpact();
          controller.stop();
        }
      },
      child: GlassSurface(
        borderRadius: RadiusTokens.brMd,
        intensity: ref.watch(settingsProvider.select((s) => s.glassIntensity)),
        child: SizedBox(
          height: MiniPlayerMetrics.height,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.sm,
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: kNowPlayingHeroTag,
                      child: AuraArtwork(
                        seed: song.artworkSeed,
                        size: 42,
                        borderRadius: RadiusTokens.brXs,
                        hasArtwork: song.hasArtwork,
                        artworkId: int.tryParse(song.id),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextTheme.title
                                .copyWith(color: colors.onSurface),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextTheme.caption
                                .copyWith(color: colors.onSurfaceMuted),
                          ),
                        ],
                      ),
                    ),
                    _PlayPauseButton(
                      playing: state.playing,
                      onTap: controller.togglePlayPause,
                    ),
                    IconButton(
                      onPressed: state.hasNext ? controller.skipToNext : null,
                      icon: Icon(Icons.skip_next, color: colors.onSurface),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProgressLine(duration: state.duration),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});

  final bool playing;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return IconButton(
      onPressed: () => onTap(),
      tooltip: playing ? l10n.pause : l10n.play,
      icon: AnimatedSwitcher(
        duration: context.motion(MotionTokens.micro),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          key: ValueKey(playing),
          color: colors.onSurface,
        ),
      ),
    );
  }
}

/// A 2px progress line. Watches [positionProvider] in isolation so only this
/// sliver repaints as the position advances — the rest of the card is static.
class _ProgressLine extends ConsumerWidget {
  const _ProgressLine({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final total = duration.inMilliseconds;
    final fraction =
        total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);

    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: colors.divider)),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction,
            child: ColoredBox(color: colors.accent),
          ),
        ],
      ),
    );
  }
}
