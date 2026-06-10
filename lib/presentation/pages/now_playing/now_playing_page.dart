import 'dart:math' as math;
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

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  static const Duration _seekStep = Duration(seconds: 10);

  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  void _seekBy(Duration delta, Duration trackDuration) {
    final ctrl = ref.read(audioControllerProvider);
    var target = ctrl.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > trackDuration) target = trackDuration;
    ctrl.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(playbackStateProvider).valueOrNull ?? PlaybackState.empty;
    final song = state.currentSong;

    if (song == null) {
      return Scaffold(backgroundColor: colors.background, body: const SizedBox());
    }

    final ctrl = ref.read(audioControllerProvider);
    final accent = SeedPalette.accent(song.artworkSeed);
    final dynamicColor = ref.watch(settingsProvider.select((s) => s.dynamicColor));
    final wash = dynamicColor ? SeedPalette.wash(song.artworkSeed) : colors.background;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 600) Navigator.of(context).maybePop();
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -600) ctrl.skipToNext();
        if (v > 600) ctrl.skipToPrevious();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // ── Layer 1: blurred album-art wash ─────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [wash.withOpacity(0.22), colors.background],
                    stops: const [0.0, 0.60],
                  ),
                ),
              ),
            ),
            // ── Layer 2: ambient animated orbs ───────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambientCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _AmbientPainter(
                    t: _ambientCtrl.value,
                    accent: accent,
                  ),
                ),
              ),
            ),
            // ── Layer 3: frosted-glass scrim over the orbs ──────────────────
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: const SizedBox.expand(),
              ),
            ),
            // ── Layer 4: content ─────────────────────────────────────────────
            SafeArea(
              child: isLandscape
                  ? _LandscapeBody(
                      state: state,
                      song: song,
                      accent: accent,
                      seekStep: _seekStep,
                      onSeekBy: _seekBy,
                    )
                  : _PortraitBody(
                      state: state,
                      song: song,
                      accent: accent,
                      seekStep: _seekStep,
                      onSeekBy: _seekBy,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Portrait layout ─────────────────────────────────────────────────────────

class _PortraitBody extends ConsumerWidget {
  const _PortraitBody({
    required this.state,
    required this.song,
    required this.accent,
    required this.seekStep,
    required this.onSeekBy,
  });

  final PlaybackState state;
  final dynamic song; // Song
  final Color accent;
  final Duration seekStep;
  final void Function(Duration, Duration) onSeekBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final ctrl = ref.read(audioControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final artSize = size.width * 0.76;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      child: Column(
        children: [
          _TopBar(
            title: l10n.nowPlaying,
            onOpenLyrics: () => openLyrics(context),
          ),
          const Spacer(flex: 2),

          // ── Artwork with glow shadow ────────────────────────────────────
          _ArtworkWithGlow(
            song: song,
            size: artSize,
            accent: accent,
            state: state,
          ),

          const Spacer(flex: 2),

          // ── Lyrics single-line capsule ──────────────────────────────────
          _LyricsCapsule(accent: accent),
          const SizedBox(height: SpacingTokens.md),

          // ── Track title & artist ────────────────────────────────────────
          _TrackInfo(title: song.title, subtitle: '${song.artist} · ${song.album}', accent: accent),
          const SizedBox(height: SpacingTokens.lg),

          // ── Scrubber row (heart + scrubber + balance) ───────────────────
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
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),

          // ── Transport ───────────────────────────────────────────────────
          _TransportRow(
            state: state,
            onPrevious: ctrl.skipToPrevious,
            onNext: state.hasNext ? ctrl.skipToNext : null,
            onSeekBack: () => onSeekBy(-seekStep, song.duration),
            onSeekForward: () => onSeekBy(seekStep, song.duration),
            onPlayPause: ctrl.togglePlayPause,
          ),
          const Spacer(flex: 1),

          // ── Bottom row ──────────────────────────────────────────────────
          _BottomRow(state: state, accent: accent),
          const SizedBox(height: SpacingTokens.md),
        ],
      ),
    );
  }
}

// ── Landscape layout ─────────────────────────────────────────────────────────

class _LandscapeBody extends ConsumerWidget {
  const _LandscapeBody({
    required this.state,
    required this.song,
    required this.accent,
    required this.seekStep,
    required this.onSeekBy,
  });

  final PlaybackState state;
  final dynamic song;
  final Color accent;
  final Duration seekStep;
  final void Function(Duration, Duration) onSeekBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(audioControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final artSize = size.height * 0.68;

    return Row(
      children: [
        // ── Left: Artwork ─────────────────────────────────────────────────
        SizedBox(
          width: size.width * 0.42,
          child: Center(
            child: _ArtworkWithGlow(
              song: song,
              size: artSize,
              accent: accent,
              state: state,
            ),
          ),
        ),

        // ── Right: Controls ───────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.md, 0, SpacingTokens.xl, 0),
            child: Column(
              children: [
                _TopBar(
                  title: l10n.nowPlaying,
                  onOpenLyrics: () => openLyrics(context),
                ),
                const Spacer(),
                _LyricsCapsule(accent: accent),
                const SizedBox(height: SpacingTokens.sm),
                _TrackInfo(
                  title: song.title,
                  subtitle: '${song.artist} · ${song.album}',
                  accent: accent,
                ),
                const SizedBox(height: SpacingTokens.md),
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
                    const SizedBox(width: 48),
                  ],
                ),
                _TransportRow(
                  state: state,
                  onPrevious: ctrl.skipToPrevious,
                  onNext: state.hasNext ? ctrl.skipToNext : null,
                  onSeekBack: () => onSeekBy(-seekStep, song.duration),
                  onSeekForward: () => onSeekBy(seekStep, song.duration),
                  onPlayPause: ctrl.togglePlayPause,
                ),
                const Spacer(),
                _BottomRow(state: state, accent: accent),
                const SizedBox(height: SpacingTokens.sm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onOpenLyrics});
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
            style: AppTextTheme.caption.copyWith(
                color: colors.onSurfaceMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500),
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

class _ArtworkWithGlow extends StatelessWidget {
  const _ArtworkWithGlow({
    required this.song,
    required this.size,
    required this.accent,
    required this.state,
  });

  final dynamic song;
  final double size;
  final Color accent;
  final PlaybackState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      image: true,
      label: l10n.a11yAlbumArt,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow shadow
          Container(
            width: size * 0.88,
            height: size * 0.22,
            margin: EdgeInsets.only(top: size * 0.82),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(size * 0.44),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.38),
                  blurRadius: size * 0.20,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Artwork
          BreathingArtwork(
            seed: song.artworkSeed,
            size: size,
            playing: state.playing,
            hasArtwork: song.hasArtwork,
            artworkId: int.tryParse(song.id),
          ),
        ],
      ),
    );
  }
}

/// Single-line liquid-glass lyrics capsule with reflection highlight.
class _LyricsCapsule extends ConsumerWidget {
  const _LyricsCapsule({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentLyricsProvider);
    final currentIndex = ref.watch(currentLyricLineProvider);
    final colors = context.colors;

    final lyrics = lyricsAsync.valueOrNull;
    if (lyrics == null || lyrics.isEmpty || !lyrics.synced) {
      return const SizedBox.shrink();
    }

    final currentLine = currentIndex >= 0 && currentIndex < lyrics.lines.length
        ? lyrics.lines[currentIndex].text
        : null;

    if (currentLine == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => openLyrics(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Stack(
            children: [
              // Glass body
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.13),
                      accent.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: accent.withOpacity(0.22), width: 0.8),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 480),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.0, 0.65),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: Center(
                    key: ValueKey(currentLine),
                    child: Text(
                      currentLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextTheme.body.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ),
              ),
              // Reflection highlight — top edge shimmer
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.55),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
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

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.heroTitle.copyWith(
            color: colors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTextTheme.body.copyWith(
            color: colors.onSurfaceMuted,
            fontSize: 13.5,
          ),
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
          icon: Icon(Icons.skip_previous_rounded, color: colors.onSurface),
          iconSize: 34,
        ),
        IconButton(
          onPressed: onSeekBack,
          icon: Icon(Icons.replay_10_rounded, color: colors.onSurfaceMuted),
          iconSize: 28,
        ),
        PlayPauseButton(
          playing: state.playing,
          onTap: onPlayPause,
          semanticLabel: state.playing ? l10n.pause : l10n.play,
          size: 68,
        ),
        IconButton(
          onPressed: onSeekForward,
          icon: Icon(Icons.forward_10_rounded, color: colors.onSurfaceMuted),
          iconSize: 28,
        ),
        IconButton(
          tooltip: l10n.nextTrack,
          onPressed: onNext == null ? null : () => onNext!(),
          icon: Icon(Icons.skip_next_rounded, color: colors.onSurface),
          iconSize: 34,
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
    final ctrl = ref.read(audioControllerProvider);
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
          onPressed: () => ctrl.setShuffle(!state.shuffleEnabled),
          icon: Icon(
            Icons.shuffle_rounded,
            color: state.shuffleEnabled ? accent : colors.onSurfaceMuted,
          ),
        ),
        IconButton(
          tooltip:
              state.repeatMode == RepeatMode.one ? l10n.repeatOne : l10n.repeat,
          onPressed: () => ctrl.setRepeat(_nextRepeat(state.repeatMode)),
          icon: Icon(
            repeatIcon,
            color: repeatActive ? accent : colors.onSurfaceMuted,
          ),
        ),
        GestureDetector(
          onTap: () {
            final idx = _speedPresets.indexOf(speed);
            final next = _speedPresets[(idx + 1) % _speedPresets.length];
            ctrl.setSpeed(next);
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
              : Icon(Icons.bedtime_outlined,
                  color: colors.onSurfaceMuted, size: 24),
        ),
        IconButton(
          tooltip: l10n.queueTitle,
          onPressed: () => showQueueSheet(context),
          icon: Icon(Icons.queue_music_rounded, color: colors.onSurfaceMuted),
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
  const _TimerChip(
      {required this.label, required this.onTap, this.isCancel = false});
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
          color: colors.surfaceElevated,
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

// ── Ambient painter — three soft drifting orbs ──────────────────────────────

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Orb 1 — large, slow, upper half
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.12 + 0.76 * _n(math.sin(t * 2 * math.pi * 0.38))),
        size.height * (0.08 + 0.42 * _n(math.cos(t * 2 * math.pi * 0.27))),
      ),
      size.width * 0.62,
      accent.withOpacity(0.09),
    );

    // Orb 2 — medium, offset phase, lower half
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.65 + 0.32 * _n(math.sin(t * 2 * math.pi * 0.22 + 2.1))),
        size.height * (0.50 + 0.32 * _n(math.cos(t * 2 * math.pi * 0.33 + 1.5))),
      ),
      size.width * 0.52,
      accent.withOpacity(0.07),
    );

    // Orb 3 — smaller, faster, bottom-left
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.18 + 0.40 * _n(math.cos(t * 2 * math.pi * 0.19 + 4.2))),
        size.height * (0.68 + 0.20 * _n(math.sin(t * 2 * math.pi * 0.44 + 0.9))),
      ),
      size.width * 0.40,
      accent.withOpacity(0.06),
    );
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ).createShader(rect),
    );
  }

  // Normalize sin/cos from -1..1 to 0..1
  double _n(double x) => (x + 1.0) / 2.0;

  @override
  bool shouldRepaint(_AmbientPainter o) =>
      o.t != t || o.accent != accent;
}
