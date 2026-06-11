import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/playback.dart';
import '../../../domain/models/song.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/media_actions_provider.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sleep_timer_provider.dart';
import '../albums/album_detail_page.dart';
import '../artists/artist_detail_page.dart';
import '../equalizer/equalizer_page.dart';
import '../lyrics/lyrics_page.dart';
import '../settings/settings_page.dart';
import '../../widgets/glass/glass_surface.dart';
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
  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
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
            // ── Layer 2: ambient animated orbs ──────────────────────────────
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
            // ── Layer 3: content ─────────────────────────────────────────────
            SafeArea(
              child: isLandscape
                  ? _LandscapeBody(state: state, song: song, accent: accent)
                  : _PortraitBody(state: state, song: song, accent: accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Portrait layout ──────────────────────────────────────────────────────────

class _PortraitBody extends ConsumerWidget {
  const _PortraitBody({
    required this.state,
    required this.song,
    required this.accent,
  });

  final PlaybackState state;
  final Song song;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(audioControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      child: Column(
        children: [
          _TopBar(song: song, accent: accent),

          // ── Artwork: flexible — takes whatever height is left so the page
          // never overflows on short screens. Capped at 76% of width.
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  // The glow shadow extends ~4% below the art, so cap at 94%
                  // of the available height to avoid a sub-pixel overflow.
                  final side = math.min(c.maxWidth * 0.76, c.maxHeight * 0.94);
                  return _ArtworkWithGlow(
                    song: song,
                    size: side,
                    accent: accent,
                    state: state,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),

          // ── 3-line lyrics carousel (always present) ─────────────────────
          _Lyrics3LineCarousel(
            accent: accent,
            onTap: () => openLyrics(context),
          ),
          const SizedBox(height: SpacingTokens.sm),

          // ── Track info with trailing like button ────────────────────────
          _TrackInfoRow(song: song, accent: accent),
          const SizedBox(height: SpacingTokens.xs),

          // ── Scrubber (full-width) ───────────────────────────────────────
          WaveformScrubber(
            duration: song.duration,
            accent: accent,
            seed: song.artworkSeed,
          ),

          // ── Transport (prev · play/pause · next) ───────────────────────
          _TransportRow(
            state: state,
            onPrevious: ctrl.skipToPrevious,
            onNext: state.hasNext ? ctrl.skipToNext : null,
            onPlayPause: ctrl.togglePlayPause,
          ),
          const SizedBox(height: SpacingTokens.xs),

          // ── Bottom row ──────────────────────────────────────────────────
          _BottomRow(state: state, accent: accent),
          const SizedBox(height: SpacingTokens.sm),
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
  });

  final PlaybackState state;
  final Song song;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(audioControllerProvider);
    final size = MediaQuery.sizeOf(context);

    return Row(
      children: [
        // ── Left: Artwork — sized to fit whatever height is available ─────
        SizedBox(
          width: size.width * 0.42,
          child: Center(
            child: LayoutBuilder(
              builder: (context, c) {
                final side =
                    math.min(c.maxWidth * 0.86, c.maxHeight * 0.72);
                return _ArtworkWithGlow(
                  song: song,
                  size: side,
                  accent: accent,
                  state: state,
                );
              },
            ),
          ),
        ),

        // ── Right: Controls ───────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.md, 0, SpacingTokens.xl, 0),
            child: LayoutBuilder(builder: (context, c) {
              // Landscape phone heights are tight; drop the carousel when
              // there is no room for it.
              final showCarousel = c.maxHeight >= 440;
              return Column(
                children: [
                  _TopBar(song: song, accent: accent),
                  const Spacer(),
                  if (showCarousel) ...[
                    _Lyrics3LineCarousel(
                      accent: accent,
                      onTap: () => openLyrics(context),
                    ),
                    const SizedBox(height: SpacingTokens.sm),
                  ],
                  _TrackInfoRow(song: song, accent: accent),
                  const SizedBox(height: SpacingTokens.xs),
                  WaveformScrubber(
                    duration: song.duration,
                    accent: accent,
                    seed: song.artworkSeed,
                  ),
                  _TransportRow(
                    state: state,
                    onPrevious: ctrl.skipToPrevious,
                    onNext: state.hasNext ? ctrl.skipToNext : null,
                    onPlayPause: ctrl.togglePlayPause,
                  ),
                  const Spacer(),
                  _BottomRow(state: state, accent: accent),
                  const SizedBox(height: SpacingTokens.sm),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.song, required this.accent});
  final Song song;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    // Stack keeps the title perfectly centered regardless of trailing icons.
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            l10n.nowPlaying,
            textAlign: TextAlign.center,
            style: AppTextTheme.caption.copyWith(
                color: colors.onSurfaceMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              _PressIcon(
                icon: Icons.keyboard_arrow_down,
                size: 28,
                color: colors.onSurface,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              _PressIcon(
                icon: Icons.graphic_eq_rounded,
                tooltip: l10n.equalizer,
                color: colors.onSurfaceMuted,
                onTap: () => openEqualizer(context),
              ),
              _PressIcon(
                icon: Icons.more_vert_rounded,
                tooltip: l10n.moreActions,
                color: colors.onSurfaceMuted,
                onTap: () => showNowPlayingMenu(context, song, accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A circular icon button that springs down on press — Aura's standard tactile
/// feedback applied to the small Now Playing controls.
class _PressIcon extends StatefulWidget {
  const _PressIcon({
    required this.icon,
    required this.onTap,
    required this.color,
    this.size = 24,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final String? tooltip;

  @override
  State<_PressIcon> createState() => _PressIconState();
}

class _PressIconState extends State<_PressIcon> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final icon = AnimatedScale(
      scale: (_down && !reduce) ? 0.82 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    );
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: icon,
      ),
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

// ── 3-line lyrics carousel — current line swells, neighbours fade ────────────

class _Lyrics3LineCarousel extends ConsumerStatefulWidget {
  const _Lyrics3LineCarousel({
    required this.accent,
    required this.onTap,
  });
  final Color accent;
  final VoidCallback onTap;

  @override
  ConsumerState<_Lyrics3LineCarousel> createState() =>
      _Lyrics3LineCarouselState();
}

class _Lyrics3LineCarouselState extends ConsumerState<_Lyrics3LineCarousel>
    with SingleTickerProviderStateMixin {
  static const double _lineH = 42.0;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  // Eased progress so lines glide rather than slide linearly.
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);

  int _anchor = 0;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(currentLyricLineProvider);
    _anchor = initial < 0 ? 0 : initial;
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final next = ref.read(currentLyricLineProvider);
        setState(() {
          _anchor = next < 0 ? _anchor : next;
          _ctrl.value = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(currentLyricsProvider);

    ref.listen<int>(currentLyricLineProvider, (_, next) {
      if (!mounted || next < 0) return;
      if (next == _anchor + 1 && !_ctrl.isAnimating) {
        _ctrl.forward(from: 0);
      } else if (next != _anchor && !_ctrl.isAnimating) {
        setState(() => _anchor = next);
      }
    });

    final lyrics = lyricsAsync.valueOrNull;
    final hasLines = lyrics != null && !lyrics.isEmpty && lyrics.synced;

    if (!hasLines) {
      // No synced lyrics yet — a calm placeholder keeps the slot reserved so the
      // layout doesn't jump the moment lyrics arrive.
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _lineH * 3,
          child: Center(child: _DotsPlaceholder(accent: widget.accent)),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: _lineH * 3,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, __) {
              final v = _t.value;
              return Transform.translate(
                offset: Offset(0, -v * _lineH),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = _anchor - 1; i <= _anchor + 2; i++)
                      SizedBox(
                        height: _lineH,
                        child: Center(
                          child: _CarouselLine(
                            text: _lineText(lyrics!.lines, i),
                            // Signed distance from the centre slot: 0 = focused.
                            distance: (i - _anchor - v).toDouble(),
                            accent: widget.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String? _lineText(List<LyricsLine> lines, int i) {
    if (i < 0 || i >= lines.length) return null;
    return lines[i].text;
  }
}

/// A single carousel line. [distance] is the signed offset from the focused
/// centre slot (0 = focused, ±1 = a neighbour). The focused line is larger,
/// bolder and accent-coloured; neighbours shrink and fade with distance.
class _CarouselLine extends StatelessWidget {
  const _CarouselLine({
    required this.text,
    required this.distance,
    required this.accent,
  });
  final String? text;
  final double distance;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    final colors = context.colors;
    final t = distance.abs().clamp(0.0, 1.0);

    final fontSize = lerpDouble(19.0, 13.0, t)!;
    final opacity = lerpDouble(1.0, 0.38, t)!;
    final color = Color.lerp(accent, colors.onSurfaceMuted, t)!;
    final weight = t < 0.4 ? FontWeight.w700 : FontWeight.w400;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        child: Text(
          text!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextTheme.body.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _DotsPlaceholder extends StatelessWidget {
  const _DotsPlaceholder({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      '· · ·',
      style: AppTextTheme.body.copyWith(
        color: colors.onSurfaceFaint,
        letterSpacing: 8,
        fontSize: 14,
      ),
    );
  }
}

// ── Track info row: title/artist left, like button right (modern standard) ───

class _TrackInfoRow extends ConsumerWidget {
  const _TrackInfoRow({required this.song, required this.accent});
  final Song song;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.heroTitle.copyWith(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              // Artist · album, each independently tappable.
              Row(
                children: [
                  Flexible(
                    child: _LinkText(
                      label: song.artist,
                      onTap: () => openArtistForSong(context, ref, song),
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: AppTextTheme.body.copyWith(
                        color: colors.onSurfaceFaint, fontSize: 13),
                  ),
                  Flexible(
                    child: _LinkText(
                      label: song.album,
                      onTap: () => openAlbumForSong(context, ref, song),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: SpacingTokens.sm),
        _LikeButton(songId: song.id, accent: accent),
      ],
    );
  }
}

/// A muted, tappable inline label (artist / album) with a brief press fade.
class _LinkText extends StatefulWidget {
  const _LinkText({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 140),
        style: AppTextTheme.body.copyWith(
          color: _down ? colors.onSurface : colors.onSurfaceMuted,
          fontSize: 13,
        ),
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Like button — spring bounce + expanding ripple ────────────────────────────

class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.songId, required this.accent});
  final String songId;
  final Color accent;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 580),
  );

  // Icon spring: grows → overshoots → settles
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 28),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.82), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.0), weight: 42),
  ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  // Ripple: expands outward during first 62% of animation
  late final Animation<double> _rippleScale =
      Tween<double>(begin: 0.0, end: 2.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.62, curve: Curves.easeOut),
  ));

  // Ripple fades out as it expands
  late final Animation<double> _rippleOpacity =
      Tween<double>(begin: 0.50, end: 0.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.58),
  ));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final isFav = ref.watch(isFavoriteProvider(widget.songId));

    return Semantics(
      label: isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(favoritesProvider.notifier).toggle(widget.songId);
          _ctrl.forward(from: 0);
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Ripple circle expands and fades from center
                Transform.scale(
                  scale: _rippleScale.value,
                  child: Opacity(
                    opacity: _rippleOpacity.value,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFav ? widget.accent : colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
                // Heart icon with spring
                Transform.scale(
                  scale: _scale.value,
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? widget.accent : colors.onSurfaceMuted,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Transport row (prev · play/pause · next) ──────────────────────────────────

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  final PlaybackState state;
  final Future<void> Function() onPrevious;
  final Future<void> Function()? onNext;
  final Future<void> Function() onPlayPause;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: l10n.previousTrack,
          onPressed: () => onPrevious(),
          icon: Icon(Icons.skip_previous_rounded, color: colors.onSurface),
          iconSize: 36,
        ),
        PlayPauseButton(
          playing: state.playing,
          onTap: onPlayPause,
          semanticLabel: state.playing ? l10n.pause : l10n.play,
          size: 64,
        ),
        IconButton(
          tooltip: l10n.nextTrack,
          onPressed: onNext == null ? null : () => onNext!(),
          icon: Icon(Icons.skip_next_rounded, color: colors.onSurface),
          iconSize: 36,
        ),
      ],
    );
  }
}

// ── Bottom row ────────────────────────────────────────────────────────────────

class _BottomRow extends ConsumerWidget {
  const _BottomRow({required this.state, required this.accent});
  final PlaybackState state;
  final Color accent;

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToggleIconButton(
          icon: Icons.shuffle_rounded,
          tooltip: l10n.shuffle,
          active: state.shuffleEnabled,
          accent: accent,
          onTap: () => ctrl.setShuffle(!state.shuffleEnabled),
        ),
        _ToggleIconButton(
          icon: state.repeatMode == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          tooltip:
              state.repeatMode == RepeatMode.one ? l10n.repeatOne : l10n.repeat,
          active: state.repeatMode != RepeatMode.off,
          accent: accent,
          onTap: () => ctrl.setRepeat(_nextRepeat(state.repeatMode)),
        ),
        _ToggleIconButton(
          icon: Icons.queue_music_rounded,
          tooltip: l10n.queueTitle,
          active: false,
          accent: accent,
          onTap: () => showQueueSheet(context),
        ),
      ],
    );
  }
}

/// A control that animates a soft accent "pill" behind its icon when active,
/// and bumps the icon with a quick spring on every tap.
class _ToggleIconButton extends StatefulWidget {
  const _ToggleIconButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ToggleIconButton> createState() => _ToggleIconButtonState();
}

class _ToggleIconButtonState extends State<_ToggleIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _bumpScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _bump, curve: Curves.easeOut));

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = widget.active ? widget.accent : colors.onSurfaceMuted;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _bump.forward(from: 0);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.accent.withOpacity(0.14)
                : Colors.transparent,
            borderRadius: RadiusTokens.brPill,
          ),
          child: ScaleTransition(
            scale: _bumpScale,
            child: Icon(widget.icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

// ── Now Playing overflow menu + navigation + sheets ──────────────────────────

/// Resolves the [Album] for [song] and pushes its detail page.
void openAlbumForSong(BuildContext context, WidgetRef ref, Song song) {
  final albums = ref.read(albumsProvider).valueOrNull ?? const <Album>[];
  Album? match;
  for (final a in albums) {
    if (a.id == song.albumId) {
      match = a;
      break;
    }
  }
  if (match == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AlbumDetailPage(album: match!)),
  );
}

/// Resolves the [Artist] for [song] and pushes its detail page.
void openArtistForSong(BuildContext context, WidgetRef ref, Song song) {
  final artists = ref.read(artistsProvider).valueOrNull ?? const <Artist>[];
  Artist? match;
  for (final a in artists) {
    if (a.id == song.artistId || a.name == song.artist) {
      match = a;
      break;
    }
  }
  if (match == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ArtistDetailPage(artist: match!)),
  );
}

/// The three-dot overflow sheet for the playing track.
Future<void> showNowPlayingMenu(
    BuildContext context, Song song, Color accent) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _NowPlayingMenu(song: song, accent: accent),
  );
}

class _NowPlayingMenu extends ConsumerWidget {
  const _NowPlayingMenu({required this.song, required this.accent});
  final Song song;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: l10n.songInfo,
                onTap: () {
                  Navigator.of(context).pop();
                  showSongInfo(context, song);
                },
              ),
              _MenuItem(
                icon: Icons.album_outlined,
                label: l10n.goToAlbum,
                onTap: () {
                  Navigator.of(context).pop();
                  openAlbumForSong(context, ref, song);
                },
              ),
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: l10n.goToArtist,
                onTap: () {
                  Navigator.of(context).pop();
                  openArtistForSong(context, ref, song);
                },
              ),
              _MenuItem(
                icon: Icons.bedtime_outlined,
                label: l10n.sleepTimer,
                onTap: () {
                  Navigator.of(context).pop();
                  showSleepTimerSheet(context, ref);
                },
              ),
              _MenuItem(
                icon: Icons.speed_rounded,
                label: l10n.playbackSpeed,
                onTap: () {
                  Navigator.of(context).pop();
                  showSpeedSheet(context, ref, accent);
                },
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: l10n.settings,
                onTap: () {
                  Navigator.of(context).pop();
                  openSettings(context);
                },
              ),
              Divider(color: colors.divider, height: 1),
              _MenuItem(
                icon: Icons.delete_outline_rounded,
                label: l10n.delete,
                destructive: true,
                onTap: () {
                  Navigator.of(context).pop();
                  confirmAndDeleteSong(context, ref, song);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? Colors.redAccent : colors.onSurface;
    return ListTile(
      leading: Icon(icon,
          color: destructive ? Colors.redAccent : colors.onSurfaceMuted),
      title: Text(label, style: AppTextTheme.body.copyWith(color: color)),
      onTap: onTap,
    );
  }
}

/// A read-only metadata sheet for [song].
Future<void> showSongInfo(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SongInfoSheet(song: song),
  );
}

class _SongInfoSheet extends StatelessWidget {
  const _SongInfoSheet({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final rows = <(String, String)>[
      (l10n.tagTitle, song.title),
      (l10n.tagArtist, song.artist),
      (l10n.tagAlbum, song.album),
      if (song.year != null) (l10n.tagYear, '${song.year}'),
      if (song.genre != null && song.genre!.isNotEmpty)
        (l10n.tagGenre, song.genre!),
      (l10n.infoDuration, song.duration.clock),
      if (song.bitrate != null) (l10n.infoBitrate, '${song.bitrate} kbps'),
      (l10n.infoFilePath, song.filePath),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.songInfo,
                  style: AppTextTheme.title.copyWith(color: colors.onSurface)),
              const SizedBox(height: SpacingTokens.md),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(label,
                            style: AppTextTheme.caption
                                .copyWith(color: colors.onSurfaceFaint)),
                      ),
                      Expanded(
                        child: Text(value,
                            style: AppTextTheme.body
                                .copyWith(color: colors.onSurface)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms, then deletes [song] from the device through the OS delete flow.
/// On success the library is rescanned and playback advances past the file.
Future<void> confirmAndDeleteSong(
    BuildContext context, WidgetRef ref, Song song) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = ctx.colors;
      return AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l10n.deleteSongTitle,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: Text(l10n.deleteSongBody,
            style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  final deleted = await ref.read(mediaDeleteServiceProvider).deleteSong(song.id);
  if (deleted) {
    // Move off the now-missing file, then rescan the library.
    final controller = ref.read(audioControllerProvider);
    await controller.skipToNext();
    await ref.read(rescanProvider)();
    messenger.showSnackBar(SnackBar(content: Text(l10n.songDeleted)));
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
  }
}

/// The sleep-timer picker — reachable from the overflow menu.
Future<void> showSleepTimerSheet(BuildContext context, WidgetRef ref) {
  final active = ref.read(sleepTimerProvider);
  final timerNotifier = ref.read(sleepTimerProvider.notifier);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final colors = sheetCtx.colors;
      final l10n = AppLocalizations.of(sheetCtx);
      const options = [
        Duration(minutes: 15),
        Duration(minutes: 30),
        Duration(minutes: 45),
        Duration(minutes: 60),
        Duration(minutes: 90),
      ];
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.md),
          child: GlassSurface(
            borderRadius: RadiusTokens.brLg,
            intensity: GlassIntensity.strong,
            padding: const EdgeInsets.all(SpacingTokens.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.sleepTimer,
                    style:
                        AppTextTheme.title.copyWith(color: colors.onSurface)),
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
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    if (active != null)
                      _TimerChip(
                        label: l10n.cancel,
                        isCancel: true,
                        onTap: () {
                          timerNotifier.cancel();
                          Navigator.pop(sheetCtx);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The playback-speed picker — reachable from the overflow menu.
Future<void> showSpeedSheet(BuildContext context, WidgetRef ref, Color accent) {
  const presets = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final colors = sheetCtx.colors;
      final l10n = AppLocalizations.of(sheetCtx);
      return Consumer(builder: (consumerCtx, sheetRef, _) {
        final current = sheetRef.watch(speedProvider).valueOrNull ?? 1.0;
        final ctrl = sheetRef.read(audioControllerProvider);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: GlassSurface(
              borderRadius: RadiusTokens.brLg,
              intensity: GlassIntensity.strong,
              padding: const EdgeInsets.all(SpacingTokens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.playbackSpeed,
                      style:
                          AppTextTheme.title.copyWith(color: colors.onSurface)),
                  const SizedBox(height: SpacingTokens.md),
                  Wrap(
                    spacing: SpacingTokens.sm,
                    runSpacing: SpacingTokens.sm,
                    children: [
                      for (final p in presets)
                        _TimerChip(
                          label: '${p % 1 == 0 ? p.toInt() : p}×',
                          selected: (current - p).abs() < 0.001,
                          accent: accent,
                          onTap: () => ctrl.setSpeed(p),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      });
    },
  );
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({
    required this.label,
    required this.onTap,
    this.isCancel = false,
    this.selected = false,
    this.accent,
  });
  final String label;
  final VoidCallback onTap;
  final bool isCancel;
  final bool selected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = selected
        ? (accent ?? colors.accent).withOpacity(0.16)
        : colors.surfaceElevated;
    final fg = isCancel
        ? Colors.redAccent
        : selected
            ? (accent ?? colors.accent)
            : colors.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: RadiusTokens.brSm,
          border: selected
              ? Border.all(color: (accent ?? colors.accent).withOpacity(0.5))
              : null,
        ),
        child: Text(
          label,
          style: AppTextTheme.body.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.12 + 0.76 * _n(math.sin(t * 2 * math.pi * 0.38))),
        size.height * (0.08 + 0.42 * _n(math.cos(t * 2 * math.pi * 0.27))),
      ),
      size.width * 0.62,
      accent.withOpacity(0.09),
    );

    _drawOrb(
      canvas,
      Offset(
        size.width * (0.65 + 0.32 * _n(math.sin(t * 2 * math.pi * 0.22 + 2.1))),
        size.height * (0.50 + 0.32 * _n(math.cos(t * 2 * math.pi * 0.33 + 1.5))),
      ),
      size.width * 0.52,
      accent.withOpacity(0.07),
    );

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

  double _n(double x) => (x + 1.0) / 2.0;

  @override
  bool shouldRepaint(_AmbientPainter o) =>
      o.t != t || o.accent != accent;
}
