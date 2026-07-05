import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../../../domain/models/app_settings.dart' show VisualizerStyle;
import '../../../domain/models/artist.dart';
import '../../../domain/models/bookmark.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/playback.dart';
import '../../../domain/models/song.dart';
import '../../../data/audio/waveform_analysis_service.dart' show WaveformAnalysisService;
import '../../providers/ab_repeat_provider.dart';
import '../../providers/bookmarks_provider.dart';
import '../../providers/cover_palette_provider.dart';
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

/// Whether the portrait Now Playing surface is in **Lyrics Mode** (artwork
/// shrunk to a header thumbnail, time-synced lyrics expanded) instead of the
/// default **Artwork Mode** (large centred album art). A single shared flag so
/// the screen's drag gestures, the lyrics toggle, and the morphing body all
/// agree. Reset to Artwork Mode every time the screen is opened.
final nowPlayingLyricsModeProvider = StateProvider<bool>((ref) => false);

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage>
    with TickerProviderStateMixin {
  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 70),
  );

  // Second drift controller with a period incommensurate with _ambientCtrl
  // (70 and 113 are coprime → combined period ≈ 7910 s, well beyond perception).
  // It slowly modulates orbital radii and adds angular precession so consecutive
  // loops of _ambientCtrl feel visually distinct — the dance never quite repeats.
  late final AnimationController _driftCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 113),
  );

  // 0 = orbs expanded (playing), 1 = orbs converged & faded (paused).
  late final AnimationController _pauseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Pulses on every detected beat: forward(from:0) restarts the 0→1 ramp, and
  // the painter turns it into a gentle flow = (1 - value)^1.8 that nudges the
  // orbs further along their swirl and breathes their size a touch — the rhythm
  // shaping the dance, not a hard throb.
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    value: 1.0, // rest at 1 → flow = (1 - value)^1.8 = 0 (calm between beats)
  );

  // ── Beat scheduler ─────────────────────────────────────────────────────────
  // The position stream only ticks a few times a second, far too coarse to fire
  // beats on time. So a Ticker advances an *estimated* position between stream
  // updates (last reported position + wall-clock elapsed × speed) and triggers
  // the pulse whenever that estimate crosses the next beat timestamp.
  Ticker? _beatTicker;
  List<int> _beatsMs = const [];
  String? _beatsSongId;
  int _nextBeat = 0;
  int _lastPosMs = 0;
  int _lastPosWallMs = 0;
  double _speed = 1.0;
  bool _playing = false;
  bool _reduceMotion = false;

  // ── Continuous loudness energy ──────────────────────────────────────────────
  // The per-song peak-normalised envelope (0..1, one sample every
  // WaveformAnalysisService.msPerSample). [_energy] is a smoothed read of it at
  // the interpolated playback position — fast attack, slow release — so the
  // visualizers swell with the music's loudness frame-by-frame (not just on
  // discrete beats). It rests at 0 when paused or before analysis completes.
  List<double> _envMs = const [];
  String? _envSongId;
  double _energy = 0.0;

  // Tracks which song we last kicked off analysis for (dedup guard).
  Song? _analyzedSong;

  // Tracks skip direction for the cover art slide animation.
  // +1 = forward (skip-next), -1 = backward (skip-prev), 0 = initial / unknown.
  int _artSlideDir = 0;

  @override
  void initState() {
    super.initState();
    _beatTicker = createTicker(_onBeatTick)..start();
    // Always open in Artwork Mode; the shared flag persists across opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(nowPlayingLyricsModeProvider.notifier).state = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAmbient();
    final isPlaying = ref.read(playbackStateProvider).valueOrNull?.playing ?? true;
    _playing = isPlaying;
    _pauseCtrl.value = isPlaying ? 0.0 : 1.0;
    if (ref.read(settingsProvider).visualizerStyle != VisualizerStyle.off) {
      _kickAnalysis(ref.read(currentSongProvider));
    }
  }

  void _syncAmbient() {
    if (_reduceMotion) {
      _ambientCtrl.stop();
      _driftCtrl.stop();
    } else {
      if (!_ambientCtrl.isAnimating) _ambientCtrl.repeat();
      if (!_driftCtrl.isAnimating) _driftCtrl.repeat();
    }
  }

  /// Starts background beat analysis for [song] if not already done.
  void _kickAnalysis(Song? song) {
    if (song == null || song.id == _analyzedSong?.id) return;
    _analyzedSong = song;
    ref.read(waveformAnalysisServiceProvider).analyze(song.id, song.filePath);
  }

  /// Records a fresh position sample and re-aligns the beat cursor. Called on
  /// every position-stream tick (and after seeks), so [_onBeatTick] can
  /// interpolate accurately between samples.
  void _syncBeatCursor(String songId, int posMs) {
    final svc = ref.read(waveformAnalysisServiceProvider);
    final beats = svc.getCachedBeats(songId);
    if (beats != null && _beatsSongId != songId) {
      _beatsMs = beats;
      _beatsSongId = songId;
    } else if (beats == null && _beatsSongId != songId) {
      // Analysis still running for a freshly-changed track — keep the old grid
      // cleared so we don't pulse to the previous song's beats.
      _beatsMs = const [];
      _beatsSongId = null;
    }
    // Load the loudness envelope the moment analysis finishes (independent of
    // the beat grid above so either can arrive first).
    if (_envSongId != songId) {
      final env = svc.getCachedEnvelope(songId);
      if (env != null) {
        _envMs = env;
        _envSongId = songId;
      } else {
        _envMs = const [];
        _envSongId = null;
      }
    }
    _lastPosMs = posMs;
    _lastPosWallMs = DateTime.now().millisecondsSinceEpoch;
    _nextBeat = _lowerBound(_beatsMs, posMs);
  }

  /// First index in ascending [list] whose value is > [target].
  int _lowerBound(List<int> list, int target) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] <= target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _onBeatTick(Duration _) {
    if (_reduceMotion) return;
    final estMs = _lastPosMs +
        ((DateTime.now().millisecondsSinceEpoch - _lastPosWallMs) * _speed)
            .round();

    // ── Continuous loudness energy ────────────────────────────────────────────
    // Sample the envelope at the interpolated position, then smooth it with a
    // fast attack / slow release so the visuals jump up on a hit and ease back
    // down — a natural "breathing with the music" feel. Decays toward 0 when
    // paused or when no envelope is available yet.
    var target = 0.0;
    if (_playing && _envMs.isNotEmpty) {
      final idx = (estMs / WaveformAnalysisService.msPerSample).floor();
      if (idx >= 0 && idx < _envMs.length) target = _envMs[idx];
    }
    final k = target > _energy ? 0.45 : 0.06;
    _energy += (target - _energy) * k;

    // ── Discrete beat pulse (sharp accent on each onset) ──────────────────────
    if (!_playing || _beatsMs.isEmpty) return;
    var fired = false;
    while (_nextBeat < _beatsMs.length && _beatsMs[_nextBeat] <= estMs) {
      fired = true;
      _nextBeat++;
    }
    if (fired) _pulseCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _beatTicker?.dispose();
    _ambientCtrl.dispose();
    _driftCtrl.dispose();
    _pauseCtrl.dispose();
    _pulseCtrl.dispose();
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

    // Drive orb convergence on play/pause; kick beat analysis on song change.
    ref.listen<AsyncValue<PlaybackState>>(playbackStateProvider,
        (prev, next) {
      final wasPlaying = prev?.valueOrNull?.playing ?? true;
      final isPlaying = next.valueOrNull?.playing ?? true;
      _playing = isPlaying;
      if (wasPlaying && !isPlaying) {
        _pauseCtrl.forward();
      } else if (!wasPlaying && isPlaying) {
        _pauseCtrl.reverse();
      }
      if (ref.read(settingsProvider).visualizerStyle != VisualizerStyle.off) {
        _kickAnalysis(next.valueOrNull?.currentSong);
      }
    });

    // Keep the beat estimator's playback speed in sync so pulses stay on-time
    // when the user changes tempo.
    ref.listen(speedProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null && v > 0) _speed = v;
    });

    // A-B repeat loop enforcement + beat-cursor re-alignment. Uses
    // ref.read(currentSongProvider) rather than the local `song` variable
    // because `song` is declared further down in build() — closures registered
    // with ref.listen execute after build() returns, so we always re-read.
    ref.listen(positionProvider, (_, next) {
      final pos = next.valueOrNull;
      if (pos == null) return;

      final s = ref.read(currentSongProvider);
      if (s == null) return;

      // A-B loop enforcement.
      final ab = ref.read(abRepeatProvider);
      if (ref.read(abRepeatProvider.notifier).shouldLoop(s.id, pos)) {
        ref.read(audioControllerProvider).seek(ab.pointA!);
      }

      // Re-anchor the beat scheduler to the freshly reported position.
      _syncBeatCursor(s.id, pos.inMilliseconds);
    });

    final song = state.currentSong;

    if (song == null) {
      return Scaffold(backgroundColor: colors.background, body: const SizedBox());
    }

    final dynamicColor = ref.watch(settingsProvider.select((s) => s.dynamicColor));

    // Real colours pulled from the album cover (Material Color Utilities),
    // falling back to the deterministic seed palette until extraction completes
    // or when there is no embedded artwork.
    final palette = ref
            .watch(coverPaletteProvider((
              seed: song.artworkSeed,
              hasArtwork: song.hasArtwork,
              artworkId: int.tryParse(song.id),
            )))
            .valueOrNull ??
        CoverPalette.fromSeed(song.artworkSeed);
    final accent = palette.accent;
    final wash = dynamicColor ? palette.wash : colors.background;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    // The liquid-glass intensity from Settings drives both how heavily the
    // backdrop is blurred and how frosted (matte) it reads, so changing the
    // slider visibly changes the Now Playing glass.
    final glass = ref.watch(settingsProvider.select((s) => s.glassIntensity));
    final blurSigma = _glassBlur(glass);
    final frost = _glassFrost(glass);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The background visualizer can be switched off or styled in Settings;
    // beat analysis is only worth running while a visualizer is active.
    final visualizerStyle = ref.watch(settingsProvider.select((s) => s.visualizerStyle));
    if (visualizerStyle != VisualizerStyle.off) _kickAnalysis(song);

    // Swipe gestures (skip / lyrics-mode / dismiss) live on the album cover
    // only — see [_CoverGestures] — so the scrubber, lyrics and empty page
    // space never hijack a drag.
    return Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // ── Layer 1: dark base ───────────────────────────────────────────
            Positioned.fill(
              child: ColoredBox(color: colors.background),
            ),
            // ── Layer 2: background visualizer (style selectable in Settings) ─
            if (visualizerStyle != VisualizerStyle.off)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_ambientCtrl, _driftCtrl, _pauseCtrl, _pulseCtrl]),
                  builder: (_, __) => CustomPaint(
                    painter: switch (visualizerStyle) {
                      VisualizerStyle.off => null,
                      VisualizerStyle.orbs => _AmbientPainter(
                        t: _ambientCtrl.value,
                        t2: _driftCtrl.value,
                        accent: _orbAccent(accent, isDark),
                        wash: _orbWash(wash, isDark),
                        convergence: _pauseCtrl.value,
                        pulse: _pulseCtrl.value,
                        energy: _energy,
                        isDark: isDark,
                      ),
                      VisualizerStyle.coverTwirl => _CoverTwirlPainter(
                        t: _ambientCtrl.value,
                        t2: _driftCtrl.value,
                        accent: _orbAccent(accent, isDark),
                        wash: _orbWash(wash, isDark),
                        convergence: _pauseCtrl.value,
                        pulse: _pulseCtrl.value,
                        energy: _energy,
                        isDark: isDark,
                      ),
                      VisualizerStyle.metaball => _MetaballPainter(
                        t: _ambientCtrl.value,
                        t2: _driftCtrl.value,
                        accent: _orbAccent(accent, isDark),
                        wash: _orbWash(wash, isDark),
                        convergence: _pauseCtrl.value,
                        pulse: _pulseCtrl.value,
                        energy: _energy,
                        isDark: isDark,
                      ),
                      VisualizerStyle.flowField => _FlowFieldPainter(
                        t: _ambientCtrl.value,
                        t2: _driftCtrl.value,
                        accent: _orbAccent(accent, isDark),
                        wash: _orbWash(wash, isDark),
                        convergence: _pauseCtrl.value,
                        pulse: _pulseCtrl.value,
                        energy: _energy,
                        isDark: isDark,
                      ),
                    },
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
    );
  }
}

/// Wraps the album cover with the screen's swipe gestures — horizontal flicks
/// skip tracks, vertical flicks enter/leave Lyrics Mode or dismiss the screen.
/// They live on the cover *only*, so drags anywhere else on the page (the
/// scrubber, the lyrics list, empty space) are never hijacked.
class _CoverGestures extends ConsumerWidget {
  const _CoverGestures({required this.isLandscape, required this.child});

  final bool isLandscape;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(audioControllerProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final lyricsMode = ref.read(nowPlayingLyricsModeProvider);
        if (v > 600) {
          // Swipe down: leave Lyrics Mode first, otherwise dismiss the screen.
          if (lyricsMode && !isLandscape) {
            HapticFeedback.selectionClick();
            ref.read(nowPlayingLyricsModeProvider.notifier).state = false;
          } else {
            Navigator.of(context).maybePop();
          }
        } else if (v < -600 && !lyricsMode && !isLandscape) {
          // Swipe up: reveal lyrics, but only when synced lyrics exist.
          final lyr = ref.read(currentLyricsProvider).valueOrNull;
          if (lyr != null && !lyr.isEmpty && lyr.synced) {
            HapticFeedback.selectionClick();
            ref.read(nowPlayingLyricsModeProvider.notifier).state = true;
          }
        }
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
      child: child,
    );
  }
}

// ── Glass intensity → full-screen blur / frost mapping ───────────────────────

/// Backdrop blur sigma for the Now Playing glass at each [GlassIntensity].
/// Kept moderate so the orbs bleed through as soft light rather than being
/// buried behind a heavy frost — lighter blur lets the colour read more vividly.
double _glassBlur(GlassIntensity g) => switch (g) {
      GlassIntensity.off => 0.0,
      GlassIntensity.subtle => 14.0,
      GlassIntensity.medium => 24.0,
      GlassIntensity.strong => 36.0,
      GlassIntensity.ultra => 52.0,
    };

/// How matte (frosted) the glass reads. Kept deliberately sheer — Liquid Glass
/// is translucent like water, not an opaque frosted panel — so the colour orbs
/// read clearly through it while the lyrics stay legible above.
double _glassFrost(GlassIntensity g) => switch (g) {
      GlassIntensity.off => 0.05,
      GlassIntensity.subtle => 0.07,
      GlassIntensity.medium => 0.10,
      GlassIntensity.strong => 0.13,
      GlassIntensity.ultra => 0.18,
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

class _PortraitBody extends ConsumerStatefulWidget {
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
  ConsumerState<_PortraitBody> createState() => _PortraitBodyState();
}

/// The adaptive portrait surface. A single [_modeCtrl] (0 = Artwork Mode,
/// 1 = Lyrics Mode) morphs three things together so the two modes read as one
/// fluid surface — the iOS-grade shared-element transition:
///   • the album art shrinks + flies from a large centred square to a small
///     header thumbnail,
///   • the title/artist block reflows from beneath the art to beside the thumb,
///   • the time-synced lyrics fade and rise to fill the vacated space.
/// The glass control deck stays docked at the bottom in both modes.
class _PortraitBodyState extends ConsumerState<_PortraitBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _modeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 380),
  );
  // M3 "emphasized" ease: quick to commit, long soft settle — the morph feels
  // responsive the instant it starts yet lands with no visible snap.
  late final Animation<double> _mode = CurvedAnimation(
    parent: _modeCtrl,
    curve: Curves.easeInOutCubicEmphasized,
    reverseCurve: Curves.easeInOutCubicEmphasized.flipped,
  );

  @override
  void initState() {
    super.initState();
    _modeCtrl.value = ref.read(nowPlayingLyricsModeProvider) ? 1.0 : 0.0;
  }

  @override
  void dispose() {
    _modeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final accent = widget.accent;
    final state = widget.state;

    // Drive the morph from the shared mode flag.
    ref.listen<bool>(nowPlayingLyricsModeProvider, (_, next) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _modeCtrl.value = next ? 1.0 : 0.0;
      } else if (next) {
        _modeCtrl.forward();
      } else {
        _modeCtrl.reverse();
      }
    });

    // No synced lyrics for this track → force Artwork Mode and keep it there.
    final lyrics =
        ref.watch(currentLyricsProvider).unwrapPrevious().valueOrNull;
    final canLyrics = lyrics != null && !lyrics.isEmpty && lyrics.synced;
    if (!canLyrics && ref.read(nowPlayingLyricsModeProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(nowPlayingLyricsModeProvider.notifier).state = false;
        }
      });
    }

    // ── Control-deck data (bookmarks + A-B markers) ───────────────────────
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

    return Column(
      children: [
        // ── Top bar (always) ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xl),
          child: _NpTopRow(song: song, accent: accent),
        ),
        SleepTimerChip(accent: accent),

        // ── Morph region: artwork ⇄ lyrics ────────────────────────────────
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            final w = c.maxWidth;
            final hm = c.maxHeight;
            const sideMargin = SpacingTokens.xl;
            const thumbSide = 52.0;
            const thumbTop = 6.0;
            const titleBlockH = 58.0;

            // Big artwork: deliberately smaller than edge-to-edge (~78% of the
            // available width) so the page breathes, centred in the region
            // above the bottom-anchored title block.
            final bigSide = math
                .min((w - sideMargin * 2) * 0.78, hm - titleBlockH - 40)
                .clamp(96.0, w - sideMargin * 2)
                .toDouble();
            final bigLeft = (w - bigSide) / 2;
            final bigTop =
                math.max(0.0, ((hm - titleBlockH - 12) - bigSide) / 2);

            // Built once per layout (its props don't depend on the morph), so
            // referencing this identical instance inside the per-frame builder
            // lets Flutter skip rebuilding the lyrics list during the morph.
            final lyricsChild = _NpLyricsHero(
              accent: accent,
              song: song,
              state: state,
              slideDirection: widget.slideDirection,
            );

            return AnimatedBuilder(
              animation: _mode,
              builder: (_, __) {
                final m = _mode.value;
                final artRect = Rect.lerp(
                  Rect.fromLTWH(bigLeft, bigTop, bigSide, bigSide),
                  const Rect.fromLTWH(sideMargin, thumbTop, thumbSide, thumbSide),
                  m,
                )!;
                // Artwork Mode anchors the title to the very bottom of the
                // morph region — directly above the progress bar in the deck.
                final titleRect = Rect.lerp(
                  Rect.fromLTWH(
                      sideMargin, hm - titleBlockH, w - sideMargin * 2, titleBlockH),
                  Rect.fromLTWH(sideMargin + thumbSide + 12, thumbTop,
                      w - sideMargin * 2 - thumbSide - 12, thumbSide),
                  m,
                )!;
                const lyricsTop = thumbTop + thumbSide + 14;

                return Stack(
                  children: [
                    // Lyrics — fade + rise in as the art seats into the thumb.
                    if (m > 0.001)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: lyricsTop,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: m < 0.5,
                          child: Opacity(
                            opacity: Curves.easeIn.transform(m.clamp(0.0, 1.0)),
                            child: lyricsChild,
                          ),
                        ),
                      ),
                    // Album art — the shared element that shrinks + travels.
                    // The swipe gestures live here, on the cover alone.
                    Positioned.fromRect(
                      rect: artRect,
                      child: _CoverGestures(
                        isLandscape: false,
                        child: _ArtworkWithGlow(
                          song: song,
                          size: artRect.width,
                          accent: accent,
                          state: state,
                          slideDirection: widget.slideDirection,
                        ),
                      ),
                    ),
                    // Title / artist (+ like, fading out in Lyrics Mode).
                    Positioned.fromRect(
                      rect: titleRect,
                      child: _MorphHeader(song: song, accent: accent, m: m),
                    ),
                  ],
                );
              },
            );
          }),
        ),

        // ── Control deck (always docked) ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl, 0, SpacingTokens.xl, SpacingTokens.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaveformScrubber(
                duration: song.duration,
                accent: accent,
                // Neutral white rail; the subdermal wave keeps the accent.
                barColor: context.colors.onSurface,
                seed: song.artworkSeed,
                isPlaying: state.playing,
                bookmarkFractions: bookmarkFracs,
                abPointA: abFracA,
                abPointB: abFracB,
                onLongPress: (position) => _cycleAbRepeat(ref, song, position),
              ),
              const SizedBox(height: SpacingTokens.sm),
              _NpTransport(state: state, accent: accent),
              const SizedBox(height: SpacingTokens.xs),
              _NpActionRow(state: state, song: song, accent: accent),
              const SizedBox(height: SpacingTokens.sm),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Now Playing top bar (portrait) ───────────────────────────────────────────

/// Grabber + dismiss + overflow. Sits above the morph region in both modes.
class _NpTopRow extends ConsumerWidget {
  const _NpTopRow({required this.song, required this.accent});

  final Song song;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceFaint.withOpacity(0.36),
              borderRadius: BorderRadius.circular(2),
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

// ── Morphing title / artist block (portrait) ─────────────────────────────────

/// Title + artist (+ like button), left-aligned in both modes. Font sizes lerp
/// down and the like button fades out as [m] → 1 (Lyrics Mode), so the block
/// reads as the same element reflowing from beneath the big art to beside the
/// header thumbnail.
class _MorphHeader extends ConsumerWidget {
  const _MorphHeader({
    required this.song,
    required this.accent,
    required this.m,
  });

  final Song song;
  final Color accent;
  final double m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final titleSize = lerpDouble(22.0, 17.0, m)!;
    final artistSize = lerpDouble(15.0, 13.0, m)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.title.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: titleSize,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openArtistForSong(context, ref, song),
                child: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.body.copyWith(
                    color: colors.onSurfaceMuted,
                    fontSize: artistSize,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (m < 0.99)
          Opacity(
            opacity: (1.0 - m).clamp(0.0, 1.0),
            child: IgnorePointer(
              ignoring: m > 0.5,
              child: _LikeButton(songId: song.id),
            ),
          ),
      ],
    );
  }
}

// ── Full-height lyrics hero (portrait) ───────────────────────────────────────

/// Auto-scrolling lyrics list that fills the center zone. Active line glows
/// in the album accent and scales up; neighbors fade with distance. When no
/// synced lyrics exist the artwork is shown here instead (graceful fallback).
class _NpLyricsHero extends ConsumerStatefulWidget {
  const _NpLyricsHero({
    required this.accent,
    required this.song,
    required this.state,
    required this.slideDirection,
  });

  final Color accent;
  final Song song;
  final PlaybackState state;
  final int slideDirection;

  @override
  ConsumerState<_NpLyricsHero> createState() => _NpLyricsHeroState();
}

class _NpLyricsHeroState extends ConsumerState<_NpLyricsHero> {
  final ScrollController _scroll = ScrollController();
  int _activeLine = 0;
  bool _userScrolling = false;
  Timer? _resumeTimer;

  static const double _lineH = 58.0;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(currentLyricLineProvider);
    if (initial >= 0) _activeLine = initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTo(_activeLine, animated: false);
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(int line, {bool animated = true}) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (!pos.hasContentDimensions) return;
    final vp = pos.viewportDimension;
    final offset = line * _lineH - (vp / 2.0 - _lineH / 2.0);
    final clamped = offset.clamp(0.0, math.max(0.0, pos.maxScrollExtent)).toDouble();
    if (animated) {
      _scroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _scroll.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(currentLyricsProvider).unwrapPrevious();

    ref.listen<int>(currentLyricLineProvider, (_, next) {
      if (!mounted || next < 0) return;
      setState(() => _activeLine = next);
      if (!_userScrolling) _scrollTo(next);
    });

    final lyrics = lyricsAsync.valueOrNull;
    final hasLines = lyrics != null && !lyrics.isEmpty && lyrics.synced;

    if (!hasLines) {
      // The album art is now drawn by the morphing element in _PortraitBody, so
      // the lyrics zone only renders a load/placeholder state. This is rarely
      // seen: Lyrics Mode is gated on synced lyrics existing.
      return Center(
        child: lyricsAsync.isLoading
            ? _DotsPlaceholder(accent: widget.accent)
            : const SizedBox.shrink(),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification && n.dragDetails != null) {
          _userScrolling = true;
          _resumeTimer?.cancel();
        } else if (n is ScrollEndNotification) {
          _resumeTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              _userScrolling = false;
              _scrollTo(_activeLine);
            }
          });
        }
        return false;
      },
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.18, 0.78, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 80),
          itemCount: lyrics.lines.length,
          itemExtent: _lineH,
          itemBuilder: (ctx, i) => _LyricsHeroLine(
            text: lyrics.lines[i].text,
            isActive: i == _activeLine,
            distance: (i - _activeLine).abs(),
            accent: widget.accent,
            onTap: () => ref
                .read(audioControllerProvider)
                .seek(lyrics.lines[i].time),
          ),
        ),
      ),
    );
  }
}

class _LyricsHeroLine extends StatelessWidget {
  const _LyricsHeroLine({
    required this.text,
    required this.isActive,
    required this.distance,
    required this.accent,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final int distance;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = distance.clamp(0, 4);
    final opacity = isActive
        ? 1.0
        : lerpDouble(0.55, 0.20, (d - 1).clamp(0, 3) / 3.0)!;
    final fontSize = isActive
        ? 22.0
        : lerpDouble(17.0, 13.0, (d - 1).clamp(0, 3) / 3.0)!;
    final color = isActive ? accent : colors.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.xl, vertical: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 420),
          style: TextStyle(
            color: color.withOpacity(opacity),
            fontSize: fontSize,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.3,
            height: 1.38,
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ── Simplified transport (portrait: prev · play/pause · next) ─────────────────

/// Portrait-only transport: skip-back · play/pause · skip-forward.
/// Shuffle and repeat move to [_NpActionRow] below so the row is easy to
/// reach one-handed and visually uncluttered.
class _NpTransport extends ConsumerWidget {
  const _NpTransport({required this.state, required this.accent});

  final PlaybackState state;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctrl = ref.read(audioControllerProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkipButton(
          icon: PhosphorIconsRegular.skipBack,
          tooltip: l10n.previousTrack,
          onTap: state.hasPrevious ? ctrl.skipToPrevious : null,
        ),
        const SizedBox(width: 38),
        PlayPauseButton(
          playing: state.playing,
          onTap: ctrl.togglePlayPause,
          semanticLabel: state.playing ? l10n.pause : l10n.play,
          size: 68,
        ),
        const SizedBox(width: 38),
        _SkipButton(
          icon: PhosphorIconsRegular.skipForward,
          tooltip: l10n.nextTrack,
          onTap: state.hasNext ? ctrl.skipToNext : null,
        ),
      ],
    );
  }
}

// ── Action row (portrait: shuffle · repeat · queue · lyrics) ─────────────────

/// Secondary action row below the transport. Shuffle/repeat live here (moved
/// from the transport so the main controls stay minimal) alongside quick
/// access to the queue and lyrics page.
class _NpActionRow extends ConsumerWidget {
  const _NpActionRow({
    required this.state,
    required this.song,
    required this.accent,
  });

  final PlaybackState state;
  final Song song;
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

    // Lyrics toggle: when synced lyrics exist the quote tile flips the screen
    // between Artwork and Lyrics Mode (and highlights while in Lyrics Mode);
    // otherwise it falls back to opening the full lyrics page.
    final lyricsMode = ref.watch(nowPlayingLyricsModeProvider);
    final lyrics =
        ref.watch(currentLyricsProvider).unwrapPrevious().valueOrNull;
    final canLyrics = lyrics != null && !lyrics.isEmpty && lyrics.synced;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PlayerToggle(
          icon: PhosphorIconsRegular.shuffle,
          tooltip: l10n.shuffle,
          active: state.shuffleEnabled,
          accent: accent,
          onTap: () => ctrl.setShuffle(!state.shuffleEnabled),
        ),
        _PlayerToggle(
          icon: repeatOne
              ? PhosphorIconsRegular.repeatOnce
              : PhosphorIconsRegular.repeat,
          tooltip: repeatOne ? l10n.repeatOne : l10n.repeat,
          active: state.repeatMode != RepeatMode.off,
          accent: accent,
          onTap: () => ctrl.setRepeat(_nextRepeat(state.repeatMode)),
        ),
        _UtilTile(
          icon: PhosphorIconsRegular.queue,
          label: l10n.queueTitle,
          onTap: () => showQueueSheet(context),
        ),
        _UtilTile(
          icon: PhosphorIconsRegular.quotes,
          label: l10n.lyrics,
          highlight: canLyrics ? lyricsMode : song.hasLyrics,
          onTap: canLyrics
              ? () => ref.read(nowPlayingLyricsModeProvider.notifier).state =
                  !lyricsMode
              : () => openLyrics(context),
        ),
      ],
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
                return _CoverGestures(
                  isLandscape: true,
                  child: _ArtworkWithGlow(
                    song: song,
                    size: side,
                    accent: accent,
                    state: state,
                    slideDirection: slideDirection,
                  ),
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
                    barColor: context.colors.onSurface,
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

class _ArtworkWithGlow extends StatefulWidget {
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
  State<_ArtworkWithGlow> createState() => _ArtworkWithGlowState();
}

class _ArtworkWithGlowState extends State<_ArtworkWithGlow>
    with SingleTickerProviderStateMixin {
  // A slow halo "breath": while playing the glow drifts very gently in and out
  // (the soft motion the user asked for); on pause it eases back to rest so the
  // halo settles inward around the cover.
  late final AnimationController _halo =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHalo();
  }

  @override
  void didUpdateWidget(_ArtworkWithGlow old) {
    super.didUpdateWidget(old);
    if (old.state.playing != widget.state.playing) _syncHalo();
  }

  void _syncHalo() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.state.playing && !reduce) {
      if (!_halo.isAnimating) _halo.repeat(reverse: true);
    } else {
      _halo.stop();
      _halo.animateTo(0, duration: const Duration(milliseconds: 700));
    }
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = widget.size;
    final accent = widget.accent;
    return Semantics(
      image: true,
      label: l10n.a11yAlbumArt,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo: a soft accent glow that wraps evenly *around* the whole cover
          // (not a bar beneath it), breathing subtly while playing.
          AnimatedBuilder(
            animation: _halo,
            builder: (_, __) {
              final b = _halo.value; // 0 at rest → ~1 at the top of the breath
              return Container(
                width: size * 0.94,
                height: size * 0.94,
                decoration: BoxDecoration(
                  borderRadius: RadiusTokens.brLg,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.28 + 0.10 * b),
                      blurRadius: size * (0.20 + 0.05 * b),
                      spreadRadius: size * (0.004 + 0.012 * b),
                    ),
                  ],
                ),
              );
            },
          ),
          // Artwork
          BreathingArtwork(
            seed: widget.song.artworkSeed,
            size: size,
            playing: widget.state.playing,
            hasArtwork: widget.song.hasArtwork,
            artworkId: int.tryParse(widget.song.id),
            slideDirection: widget.slideDirection,
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
          // Translucent glass circle so the skip controls read as Liquid Glass.
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? colors.onSurface.withOpacity(0.06)
                  : Colors.transparent,
              border: Border.all(
                color: enabled
                    ? Colors.white.withOpacity(0.10)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 30,
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
        // Bare icon — no encircling disc. Active state reads through the
        // accent colour plus a small dot beneath, keeping the row light.
        child: SizedBox(
          width: 46,
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _bump,
                child: Icon(widget.icon, color: color, size: 23),
              ),
              const SizedBox(height: 3),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.active ? 1.0 : 0.0,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    shape: BoxShape.circle,
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

// ── Utility row: EQ · Lyrics · Queue · Sleep (DS Player footer) ───────────────

class _UtilityRow extends ConsumerWidget {
  const _UtilityRow({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasLyrics = song.hasLyrics;
    // The four utilities sit as bare icon-tiles directly on the ambient
    // background — no glass capsule — so they feel light and uncluttered.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xs),
      child: Row(
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
      ),
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

/// The three-dot overflow sheet for the playing track. Scroll-controlled so
/// the full action list is reachable — it opens at up to ~82% of the screen
/// and scrolls inside the glass card rather than being clipped at half height.
Future<void> showNowPlayingMenu(
    BuildContext context, Song song, Color accent) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: GlassSurface(
          borderRadius: RadiusTokens.brLg,
          intensity: GlassIntensity.strong,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: SingleChildScrollView(
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

// ── Ambient painter — colour orbs swirling like bubbles in oil ───────────────

/// Three soft radial-gradient orbs that slowly orbit a shared centre on
/// different elliptical paths and directions — like coloured bubbles drifting
/// through oil.
///
/// **Two-controller design to prevent looping feel:**
/// [t] drives the primary orbital speed (70 s loop); [t2] drives a secondary
/// drift on a 113 s loop. Because 70 and 113 are coprime, the combined motion
/// has a theoretical period of 7 910 s — far beyond what a listener perceives as
/// repeating. Each revolution of [t] starts at a slightly different phase thanks
/// to [t2] slowly precessing the ellipse shape and angular offset.
///
/// [pulse] runs 0→1 after every detected beat; the painter turns it into a
/// gentle `flow = (1 - pulse)^1.8` that nudges each orb a little further along
/// its orbit and breathes its size a touch — the rhythm shaping the swirl.
class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.t,
    required this.t2,
    required this.accent,
    required this.wash,
    required this.isDark,
    this.convergence = 0.0,
    this.pulse = 1.0,
    this.energy = 0.0,
  });

  final double t;
  final double t2; // secondary drift, 113 s loop (incommensurate with 70 s primary)
  final Color accent;
  final Color wash;
  final bool isDark;
  final double convergence;
  final double pulse;

  /// Smoothed loudness 0..1; brightens the orbs continuously with the music.
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1.0 - convergence).clamp(0.0, 1.0).toDouble();
    final lvl = energy.clamp(0.0, 1.0).toDouble() * fade;
    final boost = (isDark ? 1.0 : 2.4) * (1.0 + 0.40 * lvl);
    final flow = math.pow(1.0 - pulse.clamp(0.0, 1.0), 1.8).toDouble() * fade;

    final tau = t * 2 * math.pi;   // primary orbit phase  (0 → 2π over 70 s)
    final tau2 = t2 * 2 * math.pi; // secondary drift phase (0 → 2π over 113 s)

    // Centre wanders gently so the whole dance drifts around the artwork rather
    // than orbiting a fixed point — adds organic life at near-zero cost.
    final centre = Offset(
      size.width * (0.50 + 0.04 * math.sin(tau2 * 0.67)),
      size.height * (0.40 + 0.03 * math.cos(tau2 * 0.43)),
    );

    // Orb 1 — forward primary orbit; ellipse breathes on the secondary cycle.
    _drawBubble(
      canvas, centre, fade, boost, flow,
      rx: size.width  * 0.26 * (1.0 + 0.18 * math.sin(tau2 * 0.53 + 0.7)),
      ry: size.height * 0.16 * (1.0 + 0.12 * math.cos(tau2 * 0.37)),
      angle: tau * 0.055 + tau2 * 0.12 + flow * 0.5,
      wobble: 0.06 * math.sin(tau * 0.13),
      radius: size.width * 0.66,
      baseOpacity: 0.26,
      color: accent,
    );
    // Orb 2 — counter-rotating primary; secondary drift also reversed.
    _drawBubble(
      canvas, centre, fade, boost, flow,
      rx: size.width  * 0.22 * (1.0 + 0.14 * math.cos(tau2 * 0.41 + 1.2)),
      ry: size.height * 0.21 * (1.0 + 0.16 * math.sin(tau2 * 0.71)),
      angle: -tau * 0.043 + 2.1 - tau2 * 0.09 - flow * 0.4,
      wobble: 0.07 * math.sin(tau * 0.11 + 1.5),
      radius: size.width * 0.58,
      baseOpacity: 0.24,
      color: Color.lerp(accent, wash, isDark ? 0.45 : 0.2)!,
    );
    // Orb 3 — slowest forward orbit; independent secondary drift direction.
    _drawBubble(
      canvas, centre, fade, boost, flow,
      rx: size.width  * 0.30 * (1.0 + 0.20 * math.sin(tau2 * 0.59 + 2.3)),
      ry: size.height * 0.13 * (1.0 + 0.10 * math.cos(tau2 * 0.83)),
      angle: tau * 0.034 + 4.0 + tau2 * 0.11 + flow * 0.55,
      wobble: 0.05 * math.sin(tau * 0.17 + 0.8),
      radius: size.width * 0.48,
      baseOpacity: 0.22,
      color: accent,
    );
  }

  void _drawBubble(
    Canvas canvas,
    Offset centre,
    double fade,
    double boost,
    double flow, {
    required double rx,
    required double ry,
    required double angle,
    required double wobble,
    required double radius,
    required double baseOpacity,
    required Color color,
  }) {
    final orbit = (1.0 + wobble + 0.05 * flow) * fade;
    final pos = Offset(
      centre.dx + math.cos(angle) * rx * orbit,
      centre.dy + math.sin(angle) * ry * orbit,
    );
    final r = radius * (1.0 - (1.0 - fade) * 0.5) * (1.0 + 0.06 * flow);
    final opacity =
        (baseOpacity * boost * fade * (1.0 + 0.22 * flow)).clamp(0.0, 0.85).toDouble();
    _drawOrb(canvas, pos, r, color.withOpacity(opacity));
  }

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

  @override
  bool shouldRepaint(_AmbientPainter o) =>
      o.t != t ||
      o.t2 != t2 ||
      o.accent != accent ||
      o.wash != wash ||
      o.isDark != isDark ||
      o.convergence != convergence ||
      o.pulse != pulse ||
      o.energy != energy;
}

// ── Cover Twirl — Apple Music style: album-color layers spinning & twisting ──

/// Four elongated colour swathes derived from the album art (accent & wash),
/// each rotating at a distinct speed and direction. The overlapping translucent
/// layers create an organic, watercolour-wash motion — the same technique Apple
/// Music uses, rendered via pure Flutter Canvas (no fragment shaders required).
class _CoverTwirlPainter extends CustomPainter {
  const _CoverTwirlPainter({
    required this.t,
    required this.t2,
    required this.accent,
    required this.wash,
    required this.isDark,
    this.convergence = 0.0,
    this.pulse = 1.0,
    this.energy = 0.0,
  });

  final double t;
  final double t2;
  final Color accent;
  final Color wash;
  final bool isDark;
  final double convergence;
  final double pulse;

  /// Smoothed loudness 0..1; swells brightness, scale and spin with the music.
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1.0 - convergence).clamp(0.0, 1.0).toDouble();
    final flow = math.pow(1.0 - pulse.clamp(0.0, 1.0), 1.8).toDouble() * fade;
    final lvl = energy.clamp(0.0, 1.0).toDouble() * fade;
    final tau = t * 2 * math.pi;
    final tau2 = t2 * 2 * math.pi;
    final cx = size.width * 0.5;
    final cy = size.height * 0.47;
    final diag = math.sqrt(size.width * size.width + size.height * size.height);

    // Continuous loudness brightens & enlarges the layers; each beat adds a
    // brief lift and a small rotational kick (the "twist" surging on hits).
    final glow = 1.0 + 0.55 * lvl + 0.25 * flow;
    final grow = 1.0 + 0.12 * lvl;
    final spin = flow * 0.6;

    // Four album-colour swathes, Apple Music layer sizes: 125 %, 80 %, 50 %, 25 %.
    // The two large ones spin in place; the two small ones orbit while spinning.
    final a1 = accent;
    final a2 = Color.lerp(accent, wash, 0.35)!;
    final a3 = Color.lerp(accent, wash, 0.65)!;
    final a4 = wash;

    // Layer 1 — 125 % diagonal, slowest spin, in place
    _swathe(canvas, cx: cx, cy: cy,
      w: diag * 1.25 * grow, h: diag * 0.55 * grow,
      angle: tau * 0.035 + tau2 * 0.06 + spin,
      color: a4, opacity: 0.30 * glow * fade);

    // Layer 2 — 80 %, counter-spin, in place
    _swathe(canvas, cx: cx, cy: cy,
      w: diag * 0.85 * grow, h: diag * 0.42 * grow,
      angle: -tau * 0.050 + 1.8 - tau2 * 0.08 - spin,
      color: a3, opacity: 0.34 * glow * fade);

    // Layer 3 — 50 %, orbiting
    final r3 = size.width * 0.13 * (1.0 + 0.18 * math.sin(tau2 * 0.47));
    _swathe(canvas,
      cx: cx + math.cos(tau * 0.070 + 1.2) * r3,
      cy: cy + math.sin(tau * 0.070 + 1.2) * r3 * 0.55,
      w: diag * 0.52 * grow, h: diag * 0.26 * grow,
      angle: tau * 0.065 + tau2 * 0.10 + spin,
      color: a2, opacity: 0.40 * glow * fade);

    // Layer 4 — 25 %, fastest orbit
    final r4 = size.width * 0.21 * (1.0 + 0.22 * math.cos(tau2 * 0.63));
    _swathe(canvas,
      cx: cx + math.cos(-tau * 0.095 + 2.7) * r4,
      cy: cy + math.sin(-tau * 0.095 + 2.7) * r4 * 0.45,
      w: diag * 0.30 * grow, h: diag * 0.15 * grow,
      angle: -tau * 0.085 + 3.4 + tau2 * 0.13 - spin,
      color: a1, opacity: 0.48 * glow * fade);
  }

  /// Draws one elongated colour swathe, rotated [angle] radians around ([cx],[cy]).
  void _swathe(Canvas canvas, {
    required double cx,
    required double cy,
    required double w,
    required double h,
    required double angle,
    required Color color,
    required double opacity,
  }) {
    if (opacity <= 0) return;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawOval(rect, Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity.clamp(0.0, 0.9).toDouble()), color.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      ).createShader(rect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverTwirlPainter o) =>
      o.t != t || o.t2 != t2 || o.accent != accent || o.wash != wash ||
      o.isDark != isDark || o.convergence != convergence ||
      o.pulse != pulse || o.energy != energy;
}

// ── Metaball — organic lava-lamp blobs that merge and separate ───────────────

/// Five soft radial-gradient blobs moving on distinct organic paths (circles,
/// figure-8s, Lissajous). Overlapping blobs visually merge because their
/// translucent fills add together — approximating true SDF metaballs on the
/// CPU without a fragment shader.
class _MetaballPainter extends CustomPainter {
  const _MetaballPainter({
    required this.t,
    required this.t2,
    required this.accent,
    required this.wash,
    required this.isDark,
    this.convergence = 0.0,
    this.pulse = 1.0,
    this.energy = 0.0,
  });

  final double t;
  final double t2;
  final Color accent;
  final Color wash;
  final bool isDark;
  final double convergence;
  final double pulse;

  /// Smoothed loudness 0..1; expands and brightens the blobs with the music.
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1.0 - convergence).clamp(0.0, 1.0).toDouble();
    final flow = math.pow(1.0 - pulse.clamp(0.0, 1.0), 1.8).toDouble();
    final lvl = energy.clamp(0.0, 1.0).toDouble();
    final tau = t * 2 * math.pi;
    final tau2 = t2 * 2 * math.pi;

    final w = size.width;
    final h = size.height;
    // Blobs swell with loudness and surge briefly on every beat.
    final baseR = w * (0.30 + 0.12 * lvl + 0.05 * flow);

    final blobs = [
      // (cx, cy, radius-scale, color-lerp)
      (
        w * (0.50 + 0.32 * math.sin(tau * 0.78 + 0.0)),
        h * (0.45 + 0.28 * math.cos(tau * 0.91)),
        1.00,
        0.00, // accent
      ),
      (
        w * (0.50 + 0.26 * math.cos(tau * 0.63 + 2.1)),
        h * (0.52 + 0.33 * math.sin(tau * 0.71 + 2.1)),
        0.88,
        0.25,
      ),
      // Figure-8
      (
        w * (0.50 + 0.38 * math.sin(tau * 0.52 + 4.2)),
        h * (0.48 + 0.22 * math.sin(tau * 1.04 + 4.2)),
        0.80,
        0.50,
      ),
      (
        w * (0.50 + 0.20 * math.sin(tau2 * 0.84 + 1.0)),
        h * (0.44 + 0.38 * math.cos(tau * 0.87 + 1.0)),
        0.72,
        0.75,
      ),
      // Near-centre slow drift via t2
      (
        w * (0.50 + 0.12 * math.cos(tau2 * 0.55)),
        h * (0.50 + 0.10 * math.sin(tau2 * 0.67)),
        0.60,
        1.00, // wash
      ),
    ];

    for (final (cx, cy, rScale, lerp) in blobs) {
      final color = Color.lerp(accent, wash, lerp)!;
      final r = baseR * rScale;
      final opacity = (isDark ? 0.34 : 0.62) * (1.0 + 0.50 * lvl) * fade;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2);
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withOpacity(opacity.clamp(0.0, 0.9).toDouble()), color.withOpacity(0.0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_MetaballPainter o) =>
      o.t != t || o.t2 != t2 || o.accent != accent || o.wash != wash ||
      o.isDark != isDark || o.convergence != convergence ||
      o.pulse != pulse || o.energy != energy;
}

// ── Flow Field — domain-warped aurora fabric flowing with the beat ────────────

/// Layered sine-wave bands whose phase advances with time, creating a
/// flowing aurora-borealis curtain in the album's accent colours.
/// Each band is a filled curved path; overlapping translucent bands
/// build depth. Beat pulse accelerates the flow speed momentarily.
class _FlowFieldPainter extends CustomPainter {
  const _FlowFieldPainter({
    required this.t,
    required this.t2,
    required this.accent,
    required this.wash,
    required this.isDark,
    this.convergence = 0.0,
    this.pulse = 1.0,
    this.energy = 0.0,
  });

  final double t;
  final double t2;
  final Color accent;
  final Color wash;
  final bool isDark;
  final double convergence;
  final double pulse;

  /// Smoothed loudness 0..1; the bands grow taller and brighter as the music
  /// gets louder — the clearest "reacting to the rhythm" of all the styles.
  final double energy;

  static const _bands = 14;
  static const _step = 8.0; // x resolution (px between path points)

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1.0 - convergence).clamp(0.0, 1.0).toDouble();
    // Beat speeds up the flow momentarily; loudness grows the wave height.
    final flowBoost = math.pow(1.0 - pulse.clamp(0.0, 1.0), 2.0).toDouble();
    final lvl = energy.clamp(0.0, 1.0).toDouble() * fade;
    final tau = t * 2 * math.pi + flowBoost * 0.25;
    final tau2 = t2 * 2 * math.pi;

    final w = size.width;
    final h = size.height;

    for (var i = 0; i < _bands; i++) {
      final progress = i / (_bands - 1); // 0 → 1
      final baseY = h * (0.05 + progress * 0.90);
      // Domain warp: two-octave sine approximation
      final freq1 = 0.0025 + 0.0010 * (i % 4);
      final freq2 = freq1 * 1.61; // golden-ratio secondary
      final speed1 = 0.40 + 0.25 * ((i % 3) / 2.0);
      final speed2 = speed1 * 0.53;
      // Loudness lifts the crest height up to ~2.2× and beats add a quick jolt.
      final amp = h *
          (0.04 + 0.05 * math.sin(progress * math.pi)) *
          (1.0 + 1.2 * lvl) +
          h * 0.02 * flowBoost;
      final phase = i * 0.53 + tau2 * 0.15 * ((i % 2 == 0) ? 1 : -1);

      final bandH = h / _bands * 1.4;

      // Top curve
      final top = Path()..moveTo(0, _y(0, baseY, freq1, freq2, tau, speed1, speed2, amp, phase));
      for (var x = _step; x <= w + _step; x += _step) {
        top.lineTo(x, _y(x, baseY, freq1, freq2, tau, speed1, speed2, amp, phase));
      }
      // Bottom curve (close the band)
      final phaseB = phase + 0.35;
      for (var x = w; x >= -_step; x -= _step) {
        top.lineTo(x, _y(x, baseY + bandH, freq1, freq2, tau, speed1, speed2, amp * 0.8, phaseB));
      }
      top.close();

      final color = Color.lerp(accent, wash, progress)!;
      final opacity = ((isDark ? 0.18 : 0.22) + 0.10 * lvl +
              0.05 * math.sin(tau * 0.4 + i * 0.7)) *
          fade;

      canvas.drawPath(
        top,
        Paint()
          ..color = color.withOpacity(opacity.clamp(0.0, 0.9).toDouble())
          ..style = PaintingStyle.fill,
      );
    }
  }

  double _y(double x, double baseY, double f1, double f2, double tau,
      double s1, double s2, double amp, double phase) {
    return baseY +
        amp * math.sin(x * f1 + tau * s1 + phase) +
        amp * 0.45 * math.sin(x * f2 + tau * s2 + phase * 1.3);
  }

  @override
  bool shouldRepaint(_FlowFieldPainter o) =>
      o.t != t || o.t2 != t2 || o.accent != accent || o.wash != wash ||
      o.isDark != isDark || o.convergence != convergence ||
      o.pulse != pulse || o.energy != energy;
}
