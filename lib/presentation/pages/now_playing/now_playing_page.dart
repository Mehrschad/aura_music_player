import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/icon_sizes.dart';
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
import '../../../domain/models/bookmark.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/playback.dart';
import '../../../domain/models/song.dart';
import '../../../domain/audio/waveform.dart';
import '../../providers/ab_repeat_provider.dart';
import '../../providers/bookmarks_provider.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/media_actions_provider.dart';
import '../../providers/playback_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/waveform_provider.dart';
import '../../providers/sleep_timer_provider.dart';
import '../../providers/song_ratings_provider.dart';
import '../albums/album_detail_page.dart';
import '../artists/artist_detail_page.dart';
import '../equalizer/equalizer_page.dart';
import '../lyrics/lyrics_page.dart';
import '../settings/settings_page.dart';
import '../../widgets/glass/glass_surface.dart';
import '../../widgets/player/pitch_speed_sheet.dart';
import '../../widgets/player/breathing_artwork.dart';
import '../../widgets/player/play_pause_button.dart';
import '../../widgets/player/queue_drawer.dart';
import '../../widgets/player/queue_sheet.dart';
import '../../widgets/player/sleep_timer_chip.dart';
import '../../widgets/library/star_rating.dart';
import '../../widgets/player/song_actions_sheet.dart';
import '../../widgets/waveform/waveform_scrubber.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage>
    with TickerProviderStateMixin {
  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  // 0 = orbs expanded (playing), 1 = orbs converged & faded (paused).
  late final AnimationController _pauseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Smoothly animated to the amplitude at the current playback position,
  // sampled from a real PCM waveform extracted by WaveformAnalysisService.
  // Falls back to a deterministic synthetic waveform until analysis completes.
  late final AnimationController _energyCtrl = AnimationController(vsync: this);

  // Per-song synthetic waveform cache: populated once on first position tick,
  // discarded when the song changes. Real waveform data from WaveformAnalysis-
  // Service takes over once extraction finishes (< 1 s on most devices).
  final Map<String, List<double>> _synthCache = {};

  // Tracks which song we last kicked off analysis for (dedup guard).
  Song? _analyzedSong;

  // Tracks skip direction for the cover art slide animation.
  // +1 = forward (skip-next), -1 = backward (skip-prev), 0 = initial / unknown.
  int _artSlideDir = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbient();
    final isPlaying = ref.read(playbackStateProvider).valueOrNull?.playing ?? true;
    _pauseCtrl.value = isPlaying ? 0.0 : 1.0;
    _kickAnalysis(ref.read(currentSongProvider));
  }

  void _syncAmbient() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _ambientCtrl.stop();
    } else if (!_ambientCtrl.isAnimating) {
      _ambientCtrl.repeat();
    }
  }

  /// Starts background waveform extraction for [song] if not already done.
  void _kickAnalysis(Song? song) {
    if (song == null || song.id == _analyzedSong?.id) return;
    _analyzedSong = song;
    _synthCache.remove(song.id); // clear stale synthetic entry for new song
    ref.read(waveformAnalysisServiceProvider).getAmplitudes(song.id, song.filePath);
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _pauseCtrl.dispose();
    _energyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(playbackStateProvider).valueOrNull ?? PlaybackState.empty;

    // Detect skip direction so the artwork can slide in from the right side.
    ref.listen(playbackStateProvider, (prev, next) {
      final prevIdx = prev?.valueOrNull?.currentIndex;
      final nextIdx = next.valueOrNull?.currentIndex;
      if (prevIdx != null && nextIdx != null && prevIdx != nextIdx) {
        _artSlideDir = nextIdx > prevIdx ? 1 : -1;
      }
    });

    // Drive orb convergence on play/pause; kick waveform analysis on song change.
    ref.listen<AsyncValue<PlaybackState>>(playbackStateProvider,
        (prev, next) {
      final wasPlaying = prev?.valueOrNull?.playing ?? true;
      final isPlaying = next.valueOrNull?.playing ?? true;
      if (wasPlaying && !isPlaying) {
        _pauseCtrl.forward();
      } else if (!wasPlaying && isPlaying) {
        _pauseCtrl.reverse();
      }
      _kickAnalysis(next.valueOrNull?.currentSong);
    });

    // A-B repeat loop enforcement + audio-energy sampling (drives orb movement).
    // Uses ref.read(currentSongProvider) rather than the local `song` variable
    // because `song` is declared further down in build() — closures registered
    // with ref.listen execute after build() returns, so we always re-read.
    ref.listen(positionProvider, (_, next) {
      final pos = next.valueOrNull;
      if (pos == null) return;

      final s = ref.read(currentSongProvider);

      // A-B loop enforcement.
      if (s != null) {
        final ab = ref.read(abRepeatProvider);
        if (ref.read(abRepeatProvider.notifier).shouldLoop(s.id, pos)) {
          ref.read(audioControllerProvider).seek(ab.pointA!);
        }
      }

      // Energy sampling: real waveform when ready, synthetic envelope fallback.
      if (!mounted || s == null) return;
      final service = ref.read(waveformAnalysisServiceProvider);
      final amps = service.getCachedAmplitudes(s.id)
          ?? (_synthCache[s.id] ??= generateWaveform(s.artworkSeed).amplitudes);
      if (amps.isEmpty) return;
      final totalMs = s.duration.inMilliseconds;
      final fraction = totalMs > 0 ? pos.inMilliseconds / totalMs : 0.0;
      final idx = (fraction.clamp(0.0, 1.0) * (amps.length - 1))
          .round()
          .clamp(0, amps.length - 1);
      _energyCtrl.animateTo(
        amps[idx],
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });

    final song = state.currentSong;

    if (song == null) {
      return Scaffold(backgroundColor: colors.background, body: const SizedBox());
    }

    final ctrl = ref.read(audioControllerProvider);
    final accent = SeedPalette.accent(song.artworkSeed);
    final dynamicColor = ref.watch(settingsProvider.select((s) => s.dynamicColor));
    final wash = dynamicColor ? SeedPalette.wash(song.artworkSeed) : colors.background;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    // The liquid-glass intensity from Settings drives both how heavily the
    // backdrop is blurred and how frosted (matte) it reads, so changing the
    // slider visibly changes the Now Playing glass.
    final glass = ref.watch(settingsProvider.select((s) => s.glassIntensity));
    final blurSigma = _glassBlur(glass);
    final frost = _glassFrost(glass);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 600) Navigator.of(context).maybePop();
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -600) {
          HapticFeedback.selectionClick();
          ctrl.skipToNext();
        }
        if (v > 600) {
          HapticFeedback.selectionClick();
          ctrl.skipToPrevious();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // ── Layer 1: dark base ───────────────────────────────────────────
            Positioned.fill(
              child: ColoredBox(color: colors.background),
            ),
            // ── Layer 2: album-color light sources (dance with audio energy) ─
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_ambientCtrl, _pauseCtrl, _energyCtrl]),
                builder: (_, __) => CustomPaint(
                  painter: _AmbientPainter(
                    t: _ambientCtrl.value,
                    accent: _orbAccent(accent, isDark),
                    wash: _orbWash(wash, isDark),
                    convergence: _pauseCtrl.value,
                    energy: _energyCtrl.value,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            // ── Layer 3: frosted glass (intensity-driven) ────────────────────
            Positioned.fill(
              child: blurSigma > 0
                  ? ClipRect(
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.background.withOpacity(frost),
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.background.withOpacity(frost),
                      ),
                    ),
            ),
            // ── Layer 4: content ─────────────────────────────────────────────
            SafeArea(
              child: isLandscape
                  ? _LandscapeBody(state: state, song: song, accent: accent, slideDirection: _artSlideDir)
                  : _PortraitBody(state: state, song: song, accent: accent, slideDirection: _artSlideDir),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass intensity → full-screen blur / frost mapping ───────────────────────

/// Backdrop blur sigma for the Now Playing glass at each [GlassIntensity].
/// Larger than the panel-level [GlassIntensity.sigma] because this blurs the
/// whole screen behind the controls — the orbs should melt into soft colour.
double _glassBlur(GlassIntensity g) => switch (g) {
      GlassIntensity.off => 0.0,
      GlassIntensity.subtle => 20.0,
      GlassIntensity.medium => 34.0,
      GlassIntensity.strong => 48.0,
      GlassIntensity.ultra => 66.0,
    };

/// How matte (frosted) the glass reads. Deliberately translucent so the
/// album-colour light orbs stay clearly visible through the frost.
double _glassFrost(GlassIntensity g) => switch (g) {
      GlassIntensity.off => 0.10,
      GlassIntensity.subtle => 0.16,
      GlassIntensity.medium => 0.22,
      GlassIntensity.strong => 0.28,
      GlassIntensity.ultra => 0.34,
    };

// ── Orb colour helpers — light-mode contrast fix ─────────────────────────────

/// In dark/AMOLED mode the original [accent] (HSV 38 % sat, 82 % value) is
/// vivid enough on a dark background. In light mode the same colour is nearly
/// invisible against the near-white canvas, so we pump saturation and darken
/// the value before passing it to the painter.
Color _orbAccent(Color accent, bool isDark) {
  if (isDark) return accent;
  final h = HSVColor.fromColor(accent);
  return HSVColor.fromAHSV(
    1.0,
    h.hue,
    (h.saturation + 0.30).clamp(0.0, 1.0).toDouble(),
    (h.value * 0.46).clamp(0.0, 1.0).toDouble(),
  ).toColor();
}

Color _orbWash(Color wash, bool isDark) {
  if (isDark) return wash;
  final h = HSVColor.fromColor(wash);
  return HSVColor.fromAHSV(
    1.0,
    h.hue,
    (h.saturation + 0.30).clamp(0.0, 1.0).toDouble(),
    (h.value * 0.55).clamp(0.0, 1.0).toDouble(),
  ).toColor();
}

// ── Portrait layout ──────────────────────────────────────────────────────────

class _PortraitBody extends ConsumerWidget {
  const _PortraitBody({
    required this.state,
    required this.song,
    required this.accent,
    required this.slideDirection,
  });

  final PlaybackState state;
  final Song song;
  final Color accent;
  final int slideDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkFracs = ref.watch(songBookmarksProvider(song.id)).map((b) {
      final total = song.duration.inMilliseconds;
      return total > 0 ? b.positionMs / total : 0.0;
    }).where((f) => f > 0 && f < 1).toList();

    final ab = ref.watch(abRepeatProvider);
    final isCurrent = ab.songId == song.id;
    final totalMs = song.duration.inMilliseconds;
    final abFracA = isCurrent && ab.hasA && totalMs > 0
        ? (ab.pointA!.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble()
        : null;
    final abFracB = isCurrent && ab.hasB && totalMs > 0
        ? (ab.pointB!.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
      child: Column(
        children: [
          _TopBar(song: song, accent: accent),
          SleepTimerChip(accent: accent),

          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = math.min(c.maxWidth * 0.76, c.maxHeight * 0.94);
                  return _ArtworkWithGlow(
                    song: song,
                    size: side,
                    accent: accent,
                    state: state,
                    slideDirection: slideDirection,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),

          _Lyrics3LineCarousel(
            accent: accent,
            onTap: () => openLyrics(context),
          ),
          const SizedBox(height: SpacingTokens.sm),

          _TrackInfoRow(song: song, accent: accent),
          const SizedBox(height: SpacingTokens.xs),

          // ── Scrubber — long-press cycles A → B → clear (A-B repeat) ────
          WaveformScrubber(
            duration: song.duration,
            accent: accent,
            seed: song.artworkSeed,
            isPlaying: state.playing,
            bookmarkFractions: bookmarkFracs,
            abPointA: abFracA,
            abPointB: abFracB,
            onLongPress: (position) =>
                _cycleAbRepeat(ref, song, position),
          ),

          _TransportRow(state: state, accent: accent),
          const SizedBox(height: SpacingTokens.sm),

          _UtilityRow(song: song),
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
    required this.slideDirection,
  });

  final PlaybackState state;
  final Song song;
  final Color accent;
  final int slideDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final bookmarkFracs = ref.watch(songBookmarksProvider(song.id)).map((b) {
      final total = song.duration.inMilliseconds;
      return total > 0 ? b.positionMs / total : 0.0;
    }).where((f) => f > 0 && f < 1).toList();

    final ab = ref.watch(abRepeatProvider);
    final isCurrent = ab.songId == song.id;
    final totalMs = song.duration.inMilliseconds;
    final abFracA = isCurrent && ab.hasA && totalMs > 0
        ? (ab.pointA!.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble()
        : null;
    final abFracB = isCurrent && ab.hasB && totalMs > 0
        ? (ab.pointB!.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble()
        : null;

    return Row(
      children: [
        // ── Left: Artwork ────────────────────────────────────────────────
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
                  slideDirection: slideDirection,
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
                  SleepTimerChip(accent: accent),
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
                    isPlaying: state.playing,
                    bookmarkFractions: bookmarkFracs,
                    abPointA: abFracA,
                    abPointB: abFracB,
                    onLongPress: (position) =>
                        _cycleAbRepeat(ref, song, position),
                  ),
                  _TransportRow(state: state, accent: accent),
                  const Spacer(),
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
    // Stack keeps the centred source label perfectly centred regardless of the
    // leading / trailing icons. Two lines: an uppercase "Playing from" eyebrow
    // over the album name — Aura's Now Playing top bar (DS Player).
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.playingFrom.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextTheme.caption.copyWith(
                    color: colors.onSurfaceMuted,
                    fontSize: 10.5,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  song.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextTheme.body.copyWith(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _PressIcon(
                icon: PhosphorIconsRegular.caretDown,
                size: IconSizes.xl,
                color: colors.onSurface,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              _PressIcon(
                icon: PhosphorIconsRegular.dotsThreeVertical,
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
    this.slideDirection = 0,
  });

  final dynamic song;
  final double size;
  final Color accent;
  final PlaybackState state;
  final int slideDirection;

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
            slideDirection: slideDirection,
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
    with TickerProviderStateMixin {
  static const double _lineH = 42.0;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);

  // "No lyrics found" fade: after 10 s of no synced lines, dissolves the label.
  late final AnimationController _noLyricsCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _noLyricsTimer;

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
    _noLyricsTimer?.cancel();
    _ctrl.dispose();
    _noLyricsCtrl.dispose();
    super.dispose();
  }

  void _scheduleNoLyricsHide() {
    _noLyricsTimer?.cancel();
    _noLyricsCtrl.value = 0;
    _noLyricsTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _noLyricsCtrl.forward();
      _noLyricsTimer = null;
    });
  }

  void _cancelNoLyricsHide() {
    _noLyricsTimer?.cancel();
    _noLyricsTimer = null;
    _noLyricsCtrl.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(currentLyricsProvider).unwrapPrevious();

    ref.listen<int>(currentLyricLineProvider, (_, next) {
      if (!mounted || next < 0) return;
      if (next == _anchor + 1 && !_ctrl.isAnimating) {
        _ctrl.forward(from: 0);
      } else if (next != _anchor && !_ctrl.isAnimating) {
        setState(() => _anchor = next);
      }
    });

    // When lyrics finish loading: start the hide timer if still empty.
    ref.listen(currentLyricsProvider, (prev, next) {
      if (!mounted) return;
      final wasLoading = prev?.isLoading ?? true;
      if (wasLoading && !next.isLoading) {
        final l = next.valueOrNull;
        final found = l != null && !l.isEmpty && l.synced;
        if (found) {
          _cancelNoLyricsHide();
        } else {
          _scheduleNoLyricsHide();
        }
      }
    });

    final lyrics = lyricsAsync.valueOrNull;
    final hasLines = lyrics != null && !lyrics.isEmpty && lyrics.synced;

    if (!hasLines) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _lineH * 3,
          child: Center(
            child: AnimatedBuilder(
              animation: _noLyricsCtrl,
              builder: (_, __) => Opacity(
                opacity: (1.0 - _noLyricsCtrl.value).clamp(0.0, 1.0),
                child: lyricsAsync.isLoading
                    ? _DotsPlaceholder(accent: widget.accent)
                    : _NoLyricsLabel(accent: widget.accent),
              ),
            ),
          ),
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

    // Active line glows softly in the album accent colour — calmer than aurora.
    final textColor = distance.abs() < 0.05 ? accent : color;
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
            color: textColor,
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
      ),
    );
  }
}

class _NoLyricsLabel extends StatelessWidget {
  const _NoLyricsLabel({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.lyricsNone,
      style: AppTextTheme.body.copyWith(
        color: colors.onSurfaceFaint,
        fontSize: 13,
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
        _LikeButton(songId: song.id),
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
  const _LikeButton({required this.songId});
  final String songId;

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
                        color: isFav ? colors.favorite : colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
                // Heart icon with spring
                Transform.scale(
                  scale: _scale.value,
                  child: Icon(
                    isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                    color: isFav ? colors.favorite : colors.onSurfaceMuted,
                    size: IconSizes.lg,
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

// ── Transport row: shuffle · prev · play/pause · next · repeat ────────────────

class _TransportRow extends ConsumerWidget {
  const _TransportRow({required this.state, required this.accent});
  final PlaybackState state;
  final Color accent;

  RepeatMode _nextRepeat(RepeatMode m) => switch (m) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(audioControllerProvider);
    final repeatOne = state.repeatMode == RepeatMode.one;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PlayerToggle(
          icon: PhosphorIconsRegular.shuffle,
          tooltip: l10n.shuffle,
          active: state.shuffleEnabled,
          accent: accent,
          onTap: () => ctrl.setShuffle(!state.shuffleEnabled),
        ),
        _SkipButton(
          icon: PhosphorIconsRegular.skipBack,
          tooltip: l10n.previousTrack,
          onTap: state.hasPrevious ? ctrl.skipToPrevious : null,
        ),
        PlayPauseButton(
          playing: state.playing,
          onTap: ctrl.togglePlayPause,
          semanticLabel: state.playing ? l10n.pause : l10n.play,
          size: 68,
        ),
        _SkipButton(
          icon: PhosphorIconsRegular.skipForward,
          tooltip: l10n.nextTrack,
          onTap: state.hasNext ? ctrl.skipToNext : null,
        ),
        _PlayerToggle(
          icon: repeatOne ? PhosphorIconsRegular.repeatOnce : PhosphorIconsRegular.repeat,
          tooltip: repeatOne ? l10n.repeatOne : l10n.repeat,
          active: state.repeatMode != RepeatMode.off,
          accent: accent,
          onTap: () => ctrl.setRepeat(_nextRepeat(state.repeatMode)),
        ),
      ],
    );
  }
}

/// Prev / next skip control with a quick press-spring and a dimmed disabled
/// state — matched in feel to the toggles flanking the row.
class _SkipButton extends StatefulWidget {
  const _SkipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onTap;

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
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
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.80 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              widget.icon,
              size: 38,
              color: enabled ? colors.onSurface : colors.onSurfaceFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular shuffle / repeat toggle. When active it lifts onto a soft accent
/// disc with an outer glow; every tap fires a springy bump with overshoot.
class _PlayerToggle extends StatefulWidget {
  const _PlayerToggle({
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
  State<_PlayerToggle> createState() => _PlayerToggleState();
}

class _PlayerToggleState extends State<_PlayerToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  late final Animation<double> _bump = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.24)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 36,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.24, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 64,
    ),
  ]).animate(_press);

  @override
  void dispose() {
    _press.dispose();
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
          _press.forward(from: 0);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.active
                ? widget.accent.withOpacity(0.16)
                : Colors.transparent,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: widget.accent.withOpacity(0.30),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: ScaleTransition(
            scale: _bump,
            child: Icon(widget.icon, color: color, size: 23),
          ),
        ),
      ),
    );
  }
}

// ── Utility row: EQ · Lyrics · Queue · Sleep (DS Player footer) ───────────────

class _UtilityRow extends ConsumerWidget {
  const _UtilityRow({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasLyrics = song.hasLyrics;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _UtilTile(
          icon: PhosphorIconsRegular.equalizer,
          label: l10n.npEq,
          onTap: () => openEqualizer(context),
        ),
        _UtilTile(
          icon: PhosphorIconsRegular.quotes,
          label: l10n.lyrics,
          highlight: hasLyrics,
          onTap: () => openLyrics(context),
        ),
        _UtilTile(
          icon: PhosphorIconsRegular.queue,
          label: l10n.queueTitle,
          onTap: () => showQueueSheet(context),
        ),
        _UtilTile(
          icon: PhosphorIconsRegular.moon,
          label: l10n.npSleep,
          onTap: () => showSleepTimerSheet(context, ref),
        ),
      ],
    );
  }
}

/// A single icon-over-label tile in the Now Playing utility row. Springs on
/// press like the other Now Playing controls.
class _UtilTile extends StatefulWidget {
  const _UtilTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  State<_UtilTile> createState() => _UtilTileState();
}

class _UtilTileState extends State<_UtilTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final color =
        widget.highlight ? colors.onSurface : colors.onSurfaceMuted;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: (_down && !reduce) ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.sm, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 21, color: color),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.caption.copyWith(
                    color: colors.onSurfaceFaint,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
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

/// Cycles the A-B repeat state on long-press: no-A → set-A → set-B → clear.
void _cycleAbRepeat(WidgetRef ref, Song song, Duration position) {
  final notifier = ref.read(abRepeatProvider.notifier);
  final ab = ref.read(abRepeatProvider);
  final isCurrent = ab.songId == song.id;
  if (!isCurrent || !ab.hasA) {
    notifier.setA(song.id, position);
    HapticFeedback.selectionClick();
  } else if (!ab.hasB) {
    if (position > ab.pointA!) {
      notifier.setB(song.id, position);
      HapticFeedback.mediumImpact();
    } else {
      notifier.setA(song.id, position);
      HapticFeedback.selectionClick();
    }
  } else {
    notifier.clear();
    HapticFeedback.selectionClick();
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
                icon: PhosphorIconsRegular.info,
                label: l10n.songInfo,
                onTap: () {
                  Navigator.of(context).pop();
                  showSongInfo(context, song);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.vinylRecord,
                label: l10n.goToAlbum,
                onTap: () {
                  Navigator.of(context).pop();
                  openAlbumForSong(context, ref, song);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.user,
                label: l10n.goToArtist,
                onTap: () {
                  Navigator.of(context).pop();
                  openArtistForSong(context, ref, song);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.plusCircle,
                label: l10n.addToPlaylist,
                onTap: () {
                  Navigator.of(context).pop();
                  showAddToPlaylist(context, song);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.star,
                label: l10n.rateSong,
                onTap: () {
                  Navigator.of(context).pop();
                  _showRatingDialog(context, ref, song.id);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.bookmark,
                label: l10n.bookmarks,
                onTap: () {
                  Navigator.of(context).pop();
                  showBookmarksSheet(context, ref, song);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.moon,
                label: l10n.sleepTimer,
                onTap: () {
                  Navigator.of(context).pop();
                  showSleepTimerSheet(context, ref);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.gauge,
                label: l10n.speedAndPitch,
                onTap: () {
                  Navigator.of(context).pop();
                  showPitchSpeedSheet(context, ref, accent);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.queue,
                label: l10n.queues,
                onTap: () {
                  Navigator.of(context).pop();
                  showQueueDrawer(context);
                },
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.gear,
                label: l10n.settings,
                onTap: () {
                  Navigator.of(context).pop();
                  openSettings(context);
                },
              ),
              Divider(color: colors.divider, height: 1),
              _MenuItem(
                icon: PhosphorIconsRegular.trash,
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
    final color = destructive ? colors.danger : colors.onSurface;
    return ListTile(
      leading: Icon(icon,
          color: destructive ? colors.danger : colors.onSurfaceMuted),
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
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  HapticFeedback.mediumImpact(); // weighty confirm for a destructive commit
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
/// Supports timed presets, end-of-track, end-of-N-tracks, and fade-out config.
Future<void> showSleepTimerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends ConsumerStatefulWidget {
  const _SleepTimerSheet();
  @override
  ConsumerState<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends ConsumerState<_SleepTimerSheet> {
  int _fadeSecs = 10;

  static const _minutePresets = [5, 10, 15, 30, 45, 60, 90, 120];
  static const _trackPresets = [1, 2, 3, 5, 10];

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.md,
          SpacingTokens.md,
          SpacingTokens.md,
          SpacingTokens.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Icon(PhosphorIconsRegular.moon,
                    size: IconSizes.sm, color: colors.onSurfaceMuted),
                const SizedBox(width: SpacingTokens.xs),
                Text(l10n.sleepTimer,
                    style:
                        AppTextTheme.title.copyWith(color: colors.onSurface)),
              ]),
              const SizedBox(height: SpacingTokens.md),

              // Active-timer status + extend/cancel
              if (mode.isActive) ...[
                _ActiveStatus(mode: mode),
                const SizedBox(height: SpacingTokens.sm),
                Row(children: [
                  if (mode is SleepTimerCountdown) ...[
                    Expanded(
                      child: _TimerChip(
                        label: l10n.sleepExtend,
                        onTap: () {
                          notifier.extend();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                  ],
                  Expanded(
                    child: _TimerChip(
                      label: l10n.cancel,
                      isCancel: true,
                      onTap: () {
                        notifier.cancel();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ]),
                Divider(
                    color: colors.divider,
                    height: SpacingTokens.lg + SpacingTokens.md),
              ],

              // Timed presets
              Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: [
                  for (final m in _minutePresets)
                    _TimerChip(
                      label: '$m min',
                      selected: mode is SleepTimerCountdown &&
                          mode.remaining.inMinutes == m,
                      onTap: () {
                        notifier.startCountdown(Duration(minutes: m),
                            fadeSecs: _fadeSecs);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.sm),

              // Track-based presets
              Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: [
                  _TimerChip(
                    label: l10n.sleepEndOfTrack,
                    selected: mode is SleepTimerEndOfTrack,
                    onTap: () {
                      notifier.startEndOfTrack();
                      Navigator.pop(context);
                    },
                  ),
                  for (final n in _trackPresets)
                    _TimerChip(
                      label: l10n.sleepAfterNTracks(n),
                      selected: mode is SleepTimerEndOfNTracks &&
                          mode.tracksLeft == n,
                      onTap: () {
                        notifier.startEndOfNTracks(n);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.sm),

              // Fade-out duration slider
              Row(children: [
                Icon(PhosphorIconsRegular.speakerLow,
                    size: 16, color: colors.onSurfaceMuted),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  '${l10n.sleepFadeOut}: ${_fadeSecs}s',
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurfaceMuted),
                ),
              ]),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _fadeSecs.toDouble(),
                  min: 0,
                  max: 30,
                  divisions: 6,
                  onChanged: (v) => setState(() => _fadeSecs = v.round()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the current timer mode in readable form inside the sheet.
class _ActiveStatus extends StatelessWidget {
  const _ActiveStatus({required this.mode});
  final SleepTimerMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final text = switch (mode) {
      SleepTimerOff() => '',
      SleepTimerCountdown(:final remaining) => remaining.clock,
      SleepTimerEndOfTrack() => l10n.sleepEndOfTrack,
      SleepTimerEndOfNTracks(:final tracksLeft) =>
        l10n.sleepTracksLeft(tracksLeft),
    };
    return Row(children: [
      Icon(PhosphorIconsRegular.moon, size: 16, color: colors.accent),
      const SizedBox(width: 6),
      Text(text,
          style: AppTextTheme.body.copyWith(
              color: colors.accent, fontWeight: FontWeight.w600)),
    ]);
  }
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
        ? colors.danger
        : selected
            ? (accent ?? colors.accent)
            : colors.onSurface;
    return GestureDetector(
      onTap: () {
        // Cancel/clear gets a weightier tap; setting a timer is a light select.
        if (isCancel) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
        onTap();
      },
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

/// A small star-rating dialog bound to [songRatingsProvider].
Future<void> _showRatingDialog(
    BuildContext context, WidgetRef ref, String songId) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final colors = ctx.colors;
      return AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l10n.rateSong,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: Consumer(builder: (c, r, _) {
          return StarRating(
            rating: r.watch(songRatingProvider(songId)) ?? 0,
            size: 34,
            onRate: (v) =>
                r.read(songRatingsProvider.notifier).setRating(songId, v),
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}

// ── Bookmarks sheet ──────────────────────────────────────────────────────────

/// Shows the bookmarks list for [song]. Tapping a bookmark seeks to it.
Future<void> showBookmarksSheet(
    BuildContext context, WidgetRef ref, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Consumer(builder: (ctx, sheetRef, _) {
      final colors = ctx.colors;
      final l10n = AppLocalizations.of(ctx);
      final bmarks = sheetRef.watch(songBookmarksProvider(song.id));
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
                Text(l10n.bookmarks,
                    style:
                        AppTextTheme.title.copyWith(color: colors.onSurface)),
                const SizedBox(height: SpacingTokens.md),
                if (bmarks.isEmpty)
                  Text(l10n.noBookmarks,
                      style: AppTextTheme.body
                          .copyWith(color: colors.onSurfaceMuted))
                else
                  for (final bm in bmarks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(PhosphorIconsRegular.bookmark,
                          color: colors.onSurfaceMuted, size: IconSizes.md),
                      title: Text(bm.label,
                          style: AppTextTheme.body
                              .copyWith(color: colors.onSurface)),
                      trailing: IconButton(
                        icon: Icon(PhosphorIconsRegular.x,
                            color: colors.onSurfaceMuted, size: IconSizes.sm),
                        onPressed: () async {
                          await sheetRef
                              .read(bookmarksProvider.notifier)
                              .removeBookmark(song.id, bm.positionMs);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.bookmarkDeleted)),
                            );
                          }
                        },
                      ),
                      onTap: () {
                        ctrl.seek(bm.position);
                        Navigator.pop(sheetCtx);
                      },
                    ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

/// Dialog to label a new bookmark at [position] and save it.
Future<void> _showAddBookmarkDialog(
    BuildContext context, WidgetRef ref, Song song, Duration position) async {
  final l10n = AppLocalizations.of(context);
  final ctrl = TextEditingController(text: position.clock);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = ctx.colors;
      return AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l10n.addBookmark,
            style: AppTextTheme.title.copyWith(color: colors.onSurface)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.bookmarkLabelHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;
  final label = ctrl.text.trim().isEmpty ? position.clock : ctrl.text.trim();
  await ref.read(bookmarksProvider.notifier).addBookmark(
        Bookmark(songId: song.id, positionMs: position.inMilliseconds, label: label),
      );
  if (context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.bookmarkAdded)));
  }
}

// ── Ambient painter — three drifting light sources driven by audio energy ────

/// Three radial-gradient orbs that orbit slowly under the frosted glass and
/// MOVE outward from the artwork centre in proportion to the current audio
/// energy — loud passages scatter the orbs, quiet passages pull them back.
///
/// [energy] is the normalised amplitude at the playback position (0.0–1.0),
/// sampled from a real PCM waveform analysis. While that analysis is pending
/// a synthetic waveform is used as a fallback.
///
/// [isDark] controls the base opacity multiplier: light-mode backgrounds need
/// ~2.5× the opacity to achieve equivalent visual contrast.
///
/// When [convergence] → 1 (paused), the orbs gather toward the artwork
/// centre and fade — the lights "collecting" under the cover.
class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.t,
    required this.accent,
    required this.wash,
    required this.isDark,
    this.convergence = 0.0,
    this.energy = 0.0,
  });

  final double t;
  final Color accent;
  final Color wash;
  final bool isDark;
  final double convergence;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    // Artwork centre lives at ~38 % from the top in portrait mode.
    final artCentre = Offset(size.width * 0.5, size.height * 0.38);
    final fade = (1.0 - convergence).clamp(0.0, 1.0).toDouble();

    // In light mode, the accent colours are pale against the near-white
    // background. We therefore apply a ~2.5× opacity boost so the orbs
    // read with equivalent visual weight across all three themes.
    final boost = isDark ? 1.0 : 2.5;

    // Soft power curve so even quiet passages register gentle scatter, not zero.
    final e = math.pow(energy.clamp(0.0, 1.0), 0.55).toDouble();

    // Orbs are pushed radially away from the artwork centre proportionally to
    // the energy — loud moments scatter them outward, silence pulls them back.
    final scatter = e * size.width * 0.14;

    // ── Orb 1: main accent, upper area ────────────────────────────────────────
    final base1 = Offset(
      size.width * (0.10 + 0.68 * _n(math.sin(t * 2 * math.pi * 0.38))),
      size.height * (0.06 + 0.38 * _n(math.cos(t * 2 * math.pi * 0.27))),
    );
    _drawOrb(
      canvas,
      _converge(_push(base1, artCentre, scatter), artCentre),
      size.width * 0.72 * (1.0 - convergence * 0.45),
      accent.withOpacity(
          (0.30 * boost * fade * (0.65 + 0.35 * e)).clamp(0.0, 0.88).toDouble()),
    );

    // ── Orb 2: complementary wash/tint, lower-right ───────────────────────────
    final base2 = Offset(
      size.width * (0.66 + 0.28 * _n(math.sin(t * 2 * math.pi * 0.22 + 2.1))),
      size.height * (0.50 + 0.34 * _n(math.cos(t * 2 * math.pi * 0.33 + 1.5))),
    );
    _drawOrb(
      canvas,
      _converge(_push(base2, artCentre, scatter * 0.85), artCentre),
      size.width * 0.60 * (1.0 - convergence * 0.55),
      Color.lerp(accent, wash, isDark ? 0.45 : 0.2)!.withOpacity(
          (0.28 * boost * fade * (0.65 + 0.35 * e)).clamp(0.0, 0.88).toDouble()),
    );

    // ── Orb 3: accent, lower-left ─────────────────────────────────────────────
    final base3 = Offset(
      size.width * (0.14 + 0.34 * _n(math.cos(t * 2 * math.pi * 0.19 + 4.2))),
      size.height * (0.68 + 0.20 * _n(math.sin(t * 2 * math.pi * 0.44 + 0.9))),
    );
    _drawOrb(
      canvas,
      _converge(_push(base3, artCentre, scatter * 1.1), artCentre),
      size.width * 0.48 * (1.0 - convergence * 0.65),
      accent.withOpacity(
          (0.24 * boost * fade * (0.65 + 0.35 * e)).clamp(0.0, 0.88).toDouble()),
    );
  }

  /// Pushes [orb] radially away from [centre] by [radius] pixels.
  Offset _push(Offset orb, Offset centre, double radius) {
    if (radius < 1) return orb;
    final dx = orb.dx - centre.dx;
    final dy = orb.dy - centre.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return orb;
    return Offset(orb.dx + dx / dist * radius, orb.dy + dy / dist * radius);
  }

  Offset _converge(Offset orb, Offset centre) =>
      Offset.lerp(orb, centre, Curves.easeInOut.transform(convergence))!;

  void _drawOrb(Canvas canvas, Offset pos, double radius, Color color) {
    if (radius <= 0 || color.alpha < 2) return;
    final rect = Rect.fromCenter(center: pos, width: radius * 2, height: radius * 2);
    canvas.drawCircle(
      pos,
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
      o.t != t ||
      o.accent != accent ||
      o.wash != wash ||
      o.isDark != isDark ||
      o.convergence != convergence ||
      o.energy != energy;
}
