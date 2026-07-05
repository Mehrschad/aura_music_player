import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/constants/motion_tokens.dart';
import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/motion.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/lyrics.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/lyrics_view/karaoke_line.dart';
import '../../widgets/press_scale.dart';
import 'sync_editor_page.dart';

Future<void> openLyrics(BuildContext context) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: context.motion(MotionTokens.screen),
    reverseTransitionDuration: context.motion(MotionTokens.screen),
    pageBuilder: (_, __, ___) => const LyricsPage(),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MotionTokens.standard),
      child: child,
    ),
  ));
}

/// Lyric font sizes (current line / secondary lines / translation), keyed by
/// the user's [LyricsFontSize] preference. Feature-local layout config rather
/// than the global type scale, since lyric sizing is user-adjustable. Defaults
/// (medium) match the Aura DS: 30px current, 22px neighbour.
class _LyricMetrics {
  const _LyricMetrics._();
  static const Map<LyricsFontSize, double> current = {
    LyricsFontSize.small: 26,
    LyricsFontSize.medium: 30,
    LyricsFontSize.large: 36,
  };
  static const Map<LyricsFontSize, double> secondary = {
    LyricsFontSize.small: 19,
    LyricsFontSize.medium: 22,
    LyricsFontSize.large: 26,
  };
  static const Map<LyricsFontSize, double> translation = {
    LyricsFontSize.small: 13,
    LyricsFontSize.medium: 15,
    LyricsFontSize.large: 17,
  };
}

class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  final _scrollController = ScrollController();
  List<GlobalKey> _keys = const [];
  int _keyCount = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureKeys(int count) {
    if (_keyCount == count) return;
    _keyCount = count;
    _keys = List.generate(count, (_) => GlobalKey());
  }

  bool _didInitialJump = false;

  /// Re-runs the lookup for the current track. Because failed lookups aren't
  /// cached, invalidating the provider forces a fresh pass through every source
  /// (with the composite's own retry) — the "Try again" affordance.
  void _retry() {
    ref.invalidate(currentLyricsProvider);
  }

  void _scrollTo(int index, {bool instant = false}) {
    if (index < 0 || index >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.42, // current line sits a touch above centre
        // Gentle eased glide so lines drift into focus rather than snapping;
        // collapses to instant under reduced motion.
        duration: instant ? Duration.zero : context.motion(MotionTokens.albumArt),
        curve: MotionTokens.emphasized,
      );
    });
  }

  TextDirection _directionFor(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final song = ref.watch(currentSongProvider);
    // unwrapPrevious: don't render the previous track's lyrics while the new
    // track's lookup is still in flight (or when it finds nothing).
    final lyricsAsync = ref.watch(currentLyricsProvider).unwrapPrevious();
    final fontSize = ref.watch(lyricsFontSizeProvider);
    final dual = ref.watch(dualLanguageProvider);
    final seed = song?.artworkSeed ?? 'lyrics';
    final palette = song == null
        ? null
        : ref.watch(coverPaletteProvider((
            seed: song.artworkSeed,
            hasArtwork: song.hasArtwork,
            artworkId: int.tryParse(song.id),
          ))).valueOrNull;
    final accent = palette?.accent ?? SeedPalette.accent(seed);
    final wash = palette?.wash ?? SeedPalette.wash(seed);

    // Auto-scroll on line change.
    ref.listen<int>(currentLyricLineProvider, (_, next) => _scrollTo(next));

    // On open, jump straight to the line that's playing right now so the user
    // lands exactly where the song is — no scroll-from-top animation.
    if (!_didInitialJump) {
      final line = ref.read(currentLyricLineProvider);
      if (line >= 0) {
        _didInitialJump = true;
        _scrollTo(line, instant: true);
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Calm, immersive background ──────────────────────────────────
          // Blurred album art, scaled out so the blur doesn't reveal edges.
          if (song != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: Transform.scale(
                  scale: 1.3,
                  child: ImageFiltered(
                    imageFilter:
                        ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                    child: AuraArtwork(
                      seed: seed,
                      size: MediaQuery.sizeOf(context).width,
                      hasArtwork: song.hasArtwork,
                    ),
                  ),
                ),
              ),
            ),
          // Wash gradient: album tint up top, fading to true bg at the foot.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    wash.withOpacity(0.55),
                    Colors.transparent,
                    Colors.transparent,
                    colors.background.withOpacity(0.55),
                  ],
                  stops: const [0.0, 0.40, 0.60, 1.0],
                ),
              ),
            ),
          ),
          // Background scrim keeps the lyric text legible over any artwork.
          Positioned.fill(
            child: ColoredBox(color: colors.background.withOpacity(0.42)),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: song?.title ?? l10n.lyrics,
                  artist: song?.artist,
                  onOpenSync: () => openSyncEditor(context),
                ),
                Expanded(
                  child: lyricsAsync.when(
                    skipLoadingOnRefresh: false,
                    loading: () => _LyricsStatus(
                      icon: Icons.lyrics_outlined,
                      message: l10n.lyricsLoading,
                      loading: true,
                      accent: accent,
                    ),
                    error: (_, __) => _LyricsStatus(
                      icon: Icons.cloud_off_rounded,
                      message: l10n.errorGeneric,
                      accent: accent,
                      onRetry: _retry,
                      retryLabel: l10n.retry,
                    ),
                    data: (lyrics) => (lyrics == null || lyrics.isEmpty)
                        ? _LyricsStatus(
                            icon: Icons.lyrics_outlined,
                            message: l10n.lyricsNone,
                            accent: accent,
                            onRetry: _retry,
                            retryLabel: l10n.retry,
                            onAdd: () => openSyncEditor(context),
                            addLabel: l10n.syncTitle,
                          )
                        : Stack(
                            children: [
                              _LyricsBody(
                                lyrics: lyrics,
                                controller: _scrollController,
                                keys: () {
                                  _ensureKeys(lyrics.lines.length);
                                  return _keys;
                                }(),
                                fontSize: fontSize,
                                dual: dual,
                                directionFor: _directionFor,
                              ),
                              // Fade masks so lines melt in/out at the edges.
                              const _EdgeFade(top: true),
                              const _EdgeFade(top: false),
                            ],
                          ),
                  ),
                ),
                _MiniTransport(accent: accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar — down-chevron (close) · centred title + artist · sync-editor icon.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.artist,
    required this.onOpenSync,
  });

  final String title;
  final String? artist;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    // Stack centres the title regardless of the flanking icon widths.
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextTheme.title.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              if (artist != null && artist!.isNotEmpty)
                Text(
                  artist!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTheme.caption.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurface),
              iconSize: 28,
            ),
            const Spacer(),
            IconButton(
              tooltip: l10n.syncTitle,
              onPressed: onOpenSync,
              icon: Icon(Icons.edit_note, color: colors.onSurfaceMuted),
              iconSize: 24,
            ),
          ],
        ),
      ],
    );
  }
}

/// The centred state shown while lyrics are loading, missing, or failed. Unlike
/// a bare empty label, the missing/error states offer a "Try again" (re-runs the
/// whole source chain) and, when nothing is found, an "Add lyrics" shortcut into
/// the sync editor — so a dry lookup is a starting point, not a dead end.
class _LyricsStatus extends StatelessWidget {
  const _LyricsStatus({
    required this.icon,
    required this.message,
    required this.accent,
    this.loading = false,
    this.onRetry,
    this.retryLabel,
    this.onAdd,
    this.addLabel,
  });

  final IconData icon;
  final String message;
  final Color accent;
  final bool loading;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            else
              Icon(icon, size: 40, color: colors.onSurfaceFaint),
            const SizedBox(height: SpacingTokens.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextTheme.body.copyWith(color: colors.onSurfaceMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: SpacingTokens.xl),
              _StatusButton(
                icon: Icons.refresh_rounded,
                label: retryLabel ?? '',
                filled: true,
                accent: accent,
                onTap: onRetry!,
              ),
            ],
            if (onAdd != null) ...[
              const SizedBox(height: SpacingTokens.sm),
              _StatusButton(
                icon: Icons.edit_note,
                label: addLabel ?? '',
                filled: false,
                accent: accent,
                onTap: onAdd!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A pill action used on the lyrics status view — filled (primary "Try again")
/// or outlined (secondary "Add lyrics").
class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = filled ? colors.onAccent : colors.onSurface;
    return PressScale(
      onTap: onTap,
      pressedScale: 0.94,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.lg, vertical: SpacingTokens.sm + 2),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: RadiusTokens.brPill,
          border: filled ? null : Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              label,
              style: AppTextTheme.body
                  .copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsBody extends ConsumerWidget {
  const _LyricsBody({
    required this.lyrics,
    required this.controller,
    required this.keys,
    required this.fontSize,
    required this.dual,
    required this.directionFor,
  });

  final Lyrics lyrics;
  final ScrollController controller;
  final List<GlobalKey> keys;
  final LyricsFontSize fontSize;
  final bool dual;
  final TextDirection Function(String) directionFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = lyrics.synced ? ref.watch(currentLyricLineProvider) : -1;
    final controllerRef = ref.read(audioControllerProvider);

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.xxl,
        vertical: MediaQuery.sizeOf(context).height * 0.34,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, i) {
        final line = lyrics.lines[i];
        // No active line yet (position before the first timestamp): render the
        // whole column plainly. Otherwise, distance drives size, dim and blur.
        final hasCurrent = current >= 0;
        final distance = hasCurrent ? i - current : 0;
        final lineEnd = i + 1 < lyrics.lines.length
            ? lyrics.lines[i + 1].time
            : line.time + const Duration(seconds: 4);

        return Padding(
          key: keys.length == lyrics.lines.length ? keys[i] : null,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
          child: _LyricRow(
            line: line,
            synced: lyrics.synced && hasCurrent,
            distance: distance,
            fontSize: fontSize,
            dual: dual,
            lineEnd: lineEnd,
            direction: directionFor(line.text),
            onTap: lyrics.synced ? () => controllerRef.seek(line.time) : null,
          ),
        );
      },
    );
  }
}

class _LyricRow extends StatelessWidget {
  const _LyricRow({
    required this.line,
    required this.synced,
    required this.distance,
    required this.fontSize,
    required this.dual,
    required this.lineEnd,
    required this.direction,
    required this.onTap,
  });

  final LyricsLine line;
  final bool synced;

  /// Signed offset from the current line (0 = current, ±1 neighbour, …).
  final int distance;
  final LyricsFontSize fontSize;
  final bool dual;
  final Duration lineEnd;
  final TextDirection direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrent = synced && distance == 0;
    final abs = distance.abs();
    final size = (isCurrent
        ? _LyricMetrics.current
        : _LyricMetrics.secondary)[fontSize]!;

    // Neighbour lines dim with distance and vanish beyond ±2; an unsynced
    // block reads at full primary colour.
    final double opacity = !synced
        ? 1
        : isCurrent
            ? 1
            : abs > 2
                ? 0
                : (0.42 - (abs - 1) * 0.12).clamp(0.0, 1.0);
    final double blur = isCurrent ? 0.0 : (abs > 2 ? 2 : abs) * 0.6;

    final style = AppTextTheme.body.copyWith(
      fontSize: size,
      height: 1.22,
      letterSpacing: -0.3,
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
      color: colors.onSurface,
    );

    final Widget primary;
    if (isCurrent && line.hasWordTimings) {
      // Word-timed: aurora karaoke fill over a dimmed base copy.
      primary = _CurrentKaraoke(
        words: line.words,
        lineEnd: lineEnd,
        style: style,
        base: colors.onSurface.withOpacity(0.3),
        direction: direction,
      );
    } else if (isCurrent) {
      // Plain synced line: aurora-fill the whole line by its time fraction.
      primary = _CurrentLineFill(
        text: line.text,
        lineStart: line.time,
        lineEnd: lineEnd,
        style: style,
        base: colors.onSurface.withOpacity(0.3),
        direction: direction,
      );
    } else {
      primary = Text(
        line.text,
        textDirection: direction,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        primary,
        if (dual && line.translation != null) ...[
          const SizedBox(height: SpacingTokens.xs),
          Text(
            line.translation!,
            textDirection: directionForText(line.translation!),
            textAlign: TextAlign.center,
            style: AppTextTheme.caption.copyWith(
              fontSize: _LyricMetrics.translation[fontSize]!,
              color: colors.onSurfaceFaint,
            ),
          ),
        ],
      ],
    );

    Widget inner = content;
    if (blur > 0) {
      inner = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: inner,
      );
    }
    if (opacity < 1) inner = Opacity(opacity: opacity, child: inner);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(child: inner),
    );
  }

  static TextDirection directionForText(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr;
}

/// A top or bottom gradient fade (bg → transparent) so lines melt at the edges.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.top});
  final bool top;

  @override
  Widget build(BuildContext context) {
    final bg = context.colors.background;
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: top ? 110 : 130,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [bg.withOpacity(0.9), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom mini transport — current-time · thin progress · play/pause.
class _MiniTransport extends ConsumerWidget {
  const _MiniTransport({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final duration = state?.duration ?? Duration.zero;
    final playing = state?.playing ?? false;
    final fraction = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.xxl,
        0,
        SpacingTokens.xxl,
        SpacingTokens.xxl,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              position.clock,
              style: AppTextTheme.caption.copyWith(
                color: colors.onSurfaceFaint,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: ClipRRect(
              borderRadius: RadiusTokens.brPill,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 3,
                // 10% white veil track (DS --state-press) + album-accent fill.
                backgroundColor: colors.onSurface.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.md),
          IconButton(
            tooltip: playing ? l10n.pause : l10n.play,
            onPressed: () => ref.read(audioControllerProvider).togglePlayPause(),
            icon: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: playing ? accent : colors.onSurface,
            ),
            iconSize: 26,
          ),
        ],
      ),
    );
  }
}

/// The active line's word-timed karaoke fill — watches [positionProvider] so
/// only this one line repaints per tick.
class _CurrentKaraoke extends ConsumerWidget {
  const _CurrentKaraoke({
    required this.words,
    required this.lineEnd,
    required this.style,
    required this.base,
    required this.direction,
  });

  final List<LyricWord> words;
  final Duration lineEnd;
  final TextStyle style;
  final Color base;
  final TextDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    return KaraokeLine(
      words: words,
      lineEnd: lineEnd,
      position: position,
      style: style,
      base: base,
      textDirection: direction,
    );
  }
}

/// Aurora fill for a synced line without word timings: the whole line fills
/// left→right by its elapsed fraction (start → next line) over a dimmed base.
class _CurrentLineFill extends ConsumerWidget {
  const _CurrentLineFill({
    required this.text,
    required this.lineStart,
    required this.lineEnd,
    required this.style,
    required this.base,
    required this.direction,
  });

  final String text;
  final Duration lineStart;
  final Duration lineEnd;
  final TextStyle style;
  final Color base;
  final TextDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    // Synthesise a single word spanning the line, so KaraokeLine fills it by
    // time fraction — reusing the established aurora-fill widget.
    return KaraokeLine(
      words: [LyricWord(start: lineStart, text: text)],
      lineEnd: lineEnd,
      position: position,
      style: style,
      base: base,
      textDirection: direction,
    );
  }
}
