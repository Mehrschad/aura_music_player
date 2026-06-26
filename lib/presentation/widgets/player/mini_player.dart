import 'dart:ui' show lerpDouble;

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
import '../../providers/cover_palette_provider.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../../shell/nav_provider.dart';
import '../artwork/aura_artwork.dart';
import '../glass/glass_surface.dart';
import '../player_bar_inset.dart';
import 'now_playing_route.dart';

/// One shared timing for the whole collapse morph (size, position, artwork and
/// corner radius), so the mini player contracts to the screen edge as a single
/// fluid piece the way an iOS 26 Liquid-Glass bar does — never a set of
/// independently-timed jumps.
const Duration _kCollapseDuration = Duration(milliseconds: 440);
const Curve _kCollapseCurve = Curves.easeInOutCubic;

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

    // When the nav bar collapses on scroll, the mini player slims down and
    // drops to the very bottom edge (iOS-style), clearing the system inset
    // itself since the nav bar that normally handles it is gone.
    final compact = song != null && ref.watch(navMinimizedProvider);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return AnimatedSize(
      duration: _kCollapseDuration,
      curve: _kCollapseCurve,
      alignment: Alignment.bottomCenter,
      child: song == null
          ? const SizedBox(width: double.infinity)
          : AnimatedPadding(
              duration: _kCollapseDuration,
              curve: _kCollapseCurve,
              padding: EdgeInsets.only(
                left: compact
                    ? SpacingTokens.sm
                    : MiniPlayerMetrics.horizontalMargin,
                right: compact
                    ? SpacingTokens.sm
                    : MiniPlayerMetrics.horizontalMargin,
                bottom: compact
                    ? (safeBottom + 6)
                    : MiniPlayerMetrics.gapToNavBar,
              ),
              child: _Card(state: state, compact: compact),
            ),
    );
  }
}

class _Card extends ConsumerStatefulWidget {
  const _Card({required this.state, this.compact = false});

  final PlaybackState state;

  /// Slim variant shown while the nav bar is collapsed (scrolling).
  final bool compact;

  @override
  ConsumerState<_Card> createState() => _CardState();
}

class _CardState extends ConsumerState<_Card>
    with TickerProviderStateMixin {
  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  // 0 = expanded (resting above the nav bar), 1 = collapsed (slim, dropped to
  // the screen edge). A single controller drives height, padding, artwork size
  // and the progress inset together, so the whole card morphs as one piece.
  late final AnimationController _collapseCtrl = AnimationController(
    vsync: this,
    duration: _kCollapseDuration,
    value: widget.compact ? 1.0 : 0.0,
  );
  late final Animation<double> _collapse =
      CurvedAnimation(parent: _collapseCtrl, curve: _kCollapseCurve);

  // Bounce sequence: the mini player "catches" the Now Playing page as it
  // collapses back into it — compressing under the impact, then springing
  // back past its resting size with an elastic overshoot before settling.
  late final Animation<double> _bounceScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.91)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.91, end: 1.05)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 44,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.05, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 40,
    ),
  ]).animate(_bounceCtrl);

  // A whisper of vertical give, so the catch reads as a real settling motion
  // rather than a pure scale pulse.
  late final Animation<double> _bounceLift = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 4.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 4.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 84,
    ),
  ]).animate(_bounceCtrl);

  @override
  void didUpdateWidget(_Card old) {
    super.didUpdateWidget(old);
    if (widget.compact != old.compact) {
      if (widget.compact) {
        _collapseCtrl.forward();
      } else {
        _collapseCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _collapseCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNowPlaying(BuildContext context) async {
    await openNowPlaying(context);
    // NowPlaying was closed — trigger the impact bounce.
    if (mounted) _bounceCtrl.forward(from: 0);
  }

  /// Morphs the shared-element cover between a soft-rounded square (Now Playing)
  /// and a full disc (mini player) over the flight: leaving Now Playing the
  /// artwork stays a gently-rounded square for most of the trip, then rounds
  /// the rest of the way and settles as a circle in the mini player. A single
  /// builder serves both push and pop (Flutter reuses it in both directions).
  Widget _artworkFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final song = widget.state.currentSong;
    if (song == null) return const SizedBox.shrink();
    final id = int.tryParse(song.id);
    final isPush = direction == HeroFlightDirection.push;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // miniWeight: 0 at the Now Playing end, 1 at the mini-player end.
        final miniWeight =
            (isPush ? 1.0 - animation.value : animation.value).clamp(0.0, 1.0);
        // Corner radius as a fraction of the live (Hero-sized) box: a gently
        // rounded square (~0.14) held for most of the trip, easing up to a full
        // circle (0.5) only at the very end — easeInCubic keeps it square-ish
        // until the cover is nearly seated in the mini player.
        final frac =
            lerpDouble(0.14, 0.5, Curves.easeInCubic.transform(miniWeight))!;
        return LayoutBuilder(
          builder: (ctx, c) {
            final side = c.biggest.shortestSide.isFinite &&
                    c.biggest.shortestSide > 0
                ? c.biggest.shortestSide
                : RadiusTokens.lg * 2;
            return AuraArtwork(
              seed: song.artworkSeed,
              fill: true,
              borderRadius: BorderRadius.circular(side * frac),
              hasArtwork: song.hasArtwork,
              artworkId: id,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final song = widget.state.currentSong!;
    final controller = ref.read(audioControllerProvider);
    final l10n = AppLocalizations.of(context);
    // The glass shell refracts the current track's dominant hue (spec §4).
    final tint = ref
        .watch(coverPaletteProvider((
          seed: song.artworkSeed,
          hasArtwork: song.hasArtwork,
          artworkId: int.tryParse(song.id),
        )))
        .valueOrNull
        ?.accent;
    // Read settings here (in build) — never inside the AnimatedBuilder, which
    // re-fires every frame and must not re-subscribe to providers.
    final glassIntensity =
        ref.watch(settingsProvider.select((s) => s.glassIntensity));

    return AnimatedBuilder(
      animation: Listenable.merge([_bounceCtrl, _collapse]),
      builder: (context, _) {
        final t = _collapse.value; // 0 expanded → 1 collapsed
        final cardHeight = lerpDouble(MiniPlayerMetrics.height, 50.0, t)!;
        final artSize = lerpDouble(44.0, 32.0, t)!;
        final vPad = lerpDouble(SpacingTokens.sm, 5.0, t)!;
        // The artist line dissolves first as the card slims, leaving the title.
        final artistOpacity = (1.0 - t * 1.7).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, _bounceLift.value),
          child: Transform.scale(
            scale: _bounceScale.value,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openNowPlaying(context),
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -200 && widget.state.hasNext) {
                  HapticFeedback.selectionClick();
                  controller.skipToNext();
                } else if (v > 200 && widget.state.hasPrevious) {
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
                // Fully-rounded stadium shell — matched to the nav bar below it.
                borderRadius: RadiusTokens.brPill,
                level: GlassLevel.thin, // mini player = thin material (spec §2)
                tint: tint,
                intensity: glassIntensity,
                child: SizedBox(
                  height: cardHeight,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          left: SpacingTokens.md,
                          right: SpacingTokens.xs,
                          top: vPad,
                          bottom: vPad,
                        ),
                        child: Row(
                          children: [
                            // Circular cover — the disc the Now Playing art
                            // settles into when the page collapses (Hero morph).
                            Hero(
                              tag: kNowPlayingHeroTag,
                              flightShuttleBuilder: _artworkFlightShuttle,
                              child: AuraArtwork(
                                seed: song.artworkSeed,
                                size: artSize,
                                borderRadius:
                                    BorderRadius.circular(artSize / 2),
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
                                  if (artistOpacity > 0.01)
                                    Opacity(
                                      opacity: artistOpacity,
                                      child: Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextTheme.caption.copyWith(
                                            color: colors.onSurfaceMuted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _MiniIconButton(
                              icon: Icons.skip_previous_rounded,
                              tooltip: l10n.previousTrack,
                              onTap: widget.state.hasPrevious
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      controller.skipToPrevious();
                                    }
                                  : null,
                            ),
                            _PlayPauseButton(
                              playing: widget.state.playing,
                              onTap: controller.togglePlayPause,
                            ),
                            _MiniIconButton(
                              icon: Icons.skip_next_rounded,
                              tooltip: l10n.nextTrack,
                              onTap: widget.state.hasNext
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      controller.skipToNext();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      // A slim, inset rounded progress capsule that sits cleanly
                      // within the pill — clear of the rounded ends.
                      Positioned(
                        left: SpacingTokens.xl,
                        right: SpacingTokens.xl,
                        bottom: lerpDouble(6.0, 4.0, t)!,
                        child: _ProgressLine(duration: widget.state.duration),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

/// A compact transport icon that springs down on press and dims when disabled.
class _MiniIconButton extends StatefulWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_MiniIconButton> createState() => _MiniIconButtonState();
}

class _MiniIconButtonState extends State<_MiniIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.80 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 38,
            height: 44,
            child: Icon(
              widget.icon,
              size: 24,
              color: enabled ? colors.onSurface : colors.onSurfaceFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim rounded progress capsule. Watches [positionProvider] in isolation so
/// only this sliver repaints as the position advances — the rest is static.
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

    // No track background — only the accent fill is rendered, so the bar is
    // invisible at fraction=0 and grows as the track plays. This removes the
    // "divider line" artifact that the full-width track color produced.
    if (fraction <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(1.5),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fraction,
        child: SizedBox(
          height: 2,
          child: ColoredBox(color: colors.accent),
        ),
      ),
    );
  }
}
