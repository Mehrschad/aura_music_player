import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/playback.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sleep_timer_provider.dart';
import '../lyrics/lyrics_page.dart';
import '../../widgets/player/breathing_artwork.dart';
import '../../widgets/player/play_pause_button.dart';
import '../../widgets/player/queue_sheet.dart';
import '../../widgets/waveform/waveform_scrubber.dart';

/// The full-screen, immersive player. Album art is the canvas; everything else
/// recedes. Background is a muted wash derived from the art (a `palette_dart`
/// stand-in — see [SeedPalette]).
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  static const Duration _seekStep = Duration(seconds: 10);

  void _seekBy(WidgetRef ref, Duration delta, Duration trackDuration) {
    final controller = ref.read(audioControllerProvider);
    var target = controller.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > trackDuration) target = trackDuration;
    controller.seek(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(playbackStateProvider).valueOrNull ?? PlaybackState.empty;
    final song = state.currentSong;

    if (song == null) {
      return Scaffold(backgroundColor: colors.background, body: const SizedBox());
    }

    final controller = ref.read(audioControllerProvider);
    final accent = SeedPalette.accent(song.artworkSeed);
    final dynamicColor = ref.watch(settingsProvider.select((s) => s.dynamicColor));
    final wash = dynamicColor ? SeedPalette.wash(song.artworkSeed) : colors.background;
    final artSize = MediaQuery.sizeOf(context).width * 0.72;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 600) Navigator.of(context).maybePop();
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -600) controller.skipToNext();
        if (v > 600) controller.skipToPrevious();
      },
      child: Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Muted dynamic-colour wash behind everything.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [wash.withOpacity(0.18), colors.background],
                  stops: const [0, 0.55],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
              child: Column(
                children: [
                  _TopBar(
                    title: l10n.nowPlaying,
                    onOpenLyrics: () => openLyrics(context),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onDoubleTapDown: (details) {
                      final left = details.localPosition.dx < artSize / 2;
                      _seekBy(ref, left ? -_seekStep : _seekStep, song.duration);
                    },
                    onDoubleTap: () {}, // double-tap recognised via the down hit
                    child: Semantics(
                      image: true,
                      label: l10n.a11yAlbumArt,
                      child: BreathingArtwork(
                        seed: song.artworkSeed,
                        size: artSize,
                        playing: state.playing,
                        hasArtwork: song.hasArtwork,
                        artworkId: int.tryParse(song.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  _InlineLyrics(accent: accent),
                  const SizedBox(height: SpacingTokens.lg),
                  _TrackText(title: song.title, subtitle: '${song.artist} \u00b7 ${song.album}'),
                  const SizedBox(height: SpacingTokens.lg),
                  Row(
                    children: [
                      _FavoriteButton(songId: song.id, accent: accent),
                      Expanded(
                        child: WaveformScrubber(
                          duration: song.duration,
                          accent: accent,
                          seed: song.artworkSeed,
                        ),
                      ),
                      const SizedBox(width: 48), // balance the favourite button
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  _TransportRow(
                    state: state,
                    onPrevious: controller.skipToPrevious,
                    onNext: state.hasNext ? controller.skipToNext : null,
                    onSeekBack: () => _seekBy(ref, -_seekStep, song.duration),
                    onSeekForward: () => _seekBy(ref, _seekStep, song.duration),
                    onPlayPause: controller.togglePlayPause,
                  ),
                  const Spacer(),
                  _BottomRow(state: state, accent: accent),
                  const SizedBox(height: SpacingTokens.lg),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onOpenLyrics,
  });
  final String title;
  final VoidCallback onOpenLyrics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurface),
          iconSize: 28,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextTheme.caption.copyWith(color: colors.onSurfaceMuted),
          ),
        ),
        IconButton(
          tooltip: l10n.lyrics,
          onPressed: onOpenLyrics,
          icon: Icon(Icons.lyrics_outlined, color: colors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _TrackText extends StatelessWidget {
  const _TrackText({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.heroTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.xs),
        Text(
          subtitle,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.songId, required this.accent});
  final String songId;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final isFav = ref.watch(isFavoriteProvider(songId));
    return IconButton(
      tooltip: isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(songId),
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? accent : colors.onSurfaceMuted,
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onPlayPause,
  });

  final PlaybackState state;
  final Future<void> Function() onPrevious;
  final Future<void> Function()? onNext;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final Future<void> Function() onPlayPause;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: l10n.previousTrack,
          onPressed: () => onPrevious(),
          icon: Icon(Icons.skip_previous, color: colors.onSurface),
          iconSize: 32,
        ),
        IconButton(
          onPressed: onSeekBack,
          icon: Icon(Icons.replay_10, color: colors.onSurfaceMuted),
          iconSize: 28,
        ),
        PlayPauseButton(
          playing: state.playing,
          onTap: onPlayPause,
          semanticLabel: state.playing ? l10n.pause : l10n.play,
        ),
        IconButton(
          onPressed: onSeekForward,
          icon: Icon(Icons.forward_10, color: colors.onSurfaceMuted),
          iconSize: 28,
        ),
        IconButton(
          tooltip: l10n.nextTrack,
          onPressed: onNext == null ? null : () => onNext!(),
          icon: Icon(Icons.skip_next, color: colors.onSurface),
          iconSize: 32,
        ),
      ],
    );
  }
}

class _BottomRow extends ConsumerWidget {
  const _BottomRow({required this.state, required this.accent});
  final PlaybackState state;
  final Color accent;

  static const _speedPresets = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  RepeatMode _nextRepeat(RepeatMode m) => switch (m) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(audioControllerProvider);
    final speed = ref.watch(speedProvider).valueOrNull ?? 1.0;
    final sleepRemaining = ref.watch(sleepTimerProvider);

    final repeatIcon =
        state.repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat;
    final repeatActive = state.repeatMode != RepeatMode.off;
    final isNormalSpeed = speed == 1.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: l10n.shuffle,
          onPressed: () => controller.setShuffle(!state.shuffleEnabled),
          icon: Icon(
            Icons.shuffle,
            color: state.shuffleEnabled ? accent : colors.onSurfaceMuted,
          ),
        ),
        IconButton(
          tooltip:
              state.repeatMode == RepeatMode.one ? l10n.repeatOne : l10n.repeat,
          onPressed: () => controller.setRepeat(_nextRepeat(state.repeatMode)),
          icon: Icon(
            repeatIcon,
            color: repeatActive ? accent : colors.onSurfaceMuted,
          ),
        ),
        // Speed button — cycles through presets on tap.
        GestureDetector(
          onTap: () {
            final idx = _speedPresets.indexOf(speed);
            final next = _speedPresets[(idx + 1) % _speedPresets.length];
            controller.setSpeed(next);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(
                color: isNormalSpeed ? colors.onSurfaceMuted : accent,
                width: 1.5,
              ),
              borderRadius: RadiusTokens.brXs,
            ),
            child: Text(
              '${speed % 1 == 0 ? speed.toInt() : speed}×',
              style: AppTextTheme.caption.copyWith(
                color: isNormalSpeed ? colors.onSurfaceMuted : accent,
                fontWeight: isNormalSpeed ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ),
        // Sleep timer button — shows countdown when active.
        GestureDetector(
          onTap: () => _showSleepTimerSheet(context, ref, sleepRemaining),
          child: sleepRemaining != null
              ? Text(
                  _formatRemaining(sleepRemaining),
                  style: AppTextTheme.caption.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(Icons.bedtime_outlined, color: colors.onSurfaceMuted, size: 24),
        ),
        IconButton(
          tooltip: l10n.queueTitle,
          onPressed: () => showQueueSheet(context),
          icon: Icon(Icons.queue_music, color: colors.onSurfaceMuted),
        ),
      ],
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSleepTimerSheet(
      BuildContext context, WidgetRef ref, Duration? active) {
    final colors = context.colors;
    final timerNotifier = ref.read(sleepTimerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        const options = [
          Duration(minutes: 15),
          Duration(minutes: 30),
          Duration(minutes: 45),
          Duration(minutes: 60),
          Duration(minutes: 90),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Timer',
                  style: AppTextTheme.title.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: SpacingTokens.md),
                Wrap(
                  spacing: SpacingTokens.sm,
                  runSpacing: SpacingTokens.sm,
                  children: [
                    for (final opt in options)
                      _TimerChip(
                        label: '${opt.inMinutes} min',
                        onTap: () {
                          timerNotifier.start(opt);
                          Navigator.pop(context);
                        },
                      ),
                    if (active != null)
                      _TimerChip(
                        label: 'Cancel',
                        isCancel: true,
                        onTap: () {
                          timerNotifier.cancel();
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.label, required this.onTap, this.isCancel = false});
  final String label;
  final VoidCallback onTap;
  final bool isCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCancel ? colors.surfaceElevated : colors.surfaceElevated,
          borderRadius: RadiusTokens.brSm,
        ),
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(
            color: isCancel ? Colors.redAccent : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _InlineLyrics extends ConsumerWidget {
  const _InlineLyrics({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentLyricsProvider);
    final currentIndex = ref.watch(currentLyricLineProvider);
    final colors = context.colors;

    final lyrics = lyricsAsync.valueOrNull;
    if (lyrics == null || lyrics.isEmpty || !lyrics.synced || currentIndex < 0) {
      return const SizedBox.shrink();
    }

    final lines = lyrics.lines;
    final prevLine = currentIndex > 0 ? lines[currentIndex - 1].text : '';
    final currentLine = lines[currentIndex].text;
    final nextLine =
        currentIndex + 1 < lines.length ? lines[currentIndex + 1].text : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.onSurface.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.onSurface.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Previous line
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  prevLine,
                  key: ValueKey('prev_$currentIndex'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceFaint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Current line
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  currentLine,
                  key: ValueKey('curr_$currentIndex'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Next line
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  nextLine,
                  key: ValueKey('next_$currentIndex'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
