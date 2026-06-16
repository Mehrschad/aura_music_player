import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/constants/motion_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/seed_color.dart';
import '../../../domain/models/lyrics.dart';
import '../../providers/async_value_x.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_providers.dart';
import '../../widgets/artwork/aura_artwork.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/lyrics_view/karaoke_line.dart';
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
/// than the global type scale, since lyric sizing is user-adjustable.
class _LyricMetrics {
  const _LyricMetrics._();
  static const Map<LyricsFontSize, double> current = {
    LyricsFontSize.small: 18,
    LyricsFontSize.medium: 22,
    LyricsFontSize.large: 28,
  };
  static const Map<LyricsFontSize, double> secondary = {
    LyricsFontSize.small: 14,
    LyricsFontSize.medium: 16,
    LyricsFontSize.large: 19,
  };
  static const Map<LyricsFontSize, double> translation = {
    LyricsFontSize.small: 12,
    LyricsFontSize.medium: 13,
    LyricsFontSize.large: 15,
  };
}

class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  List<GlobalKey> _keys = const [];
  int _keyCount = -1;

  // Slow drift for ambient orbs (24s loop)
  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  // Fast pulse for the frosted-glass light shimmer (~2.4s loop, ≈25 BPM)
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbient();
  }

  // Hold the ambient loops still under reduce-motion; run them otherwise.
  void _syncAmbient() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    for (final c in [_ambientCtrl, _pulseCtrl]) {
      if (reduce) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ambientCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureKeys(int count) {
    if (_keyCount == count) return;
    _keyCount = count;
    _keys = List.generate(count, (_) => GlobalKey());
  }

  bool _didInitialJump = false;

  void _scrollTo(int index, {bool instant = false}) {
    if (index < 0 || index >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.40, // current line sits ~40% from the top
        // Longer, gentler glide than a screen transition so lines drift
        // smoothly into focus rather than snapping.
        duration:
            instant ? Duration.zero : const Duration(milliseconds: 720),
        curve: Curves.easeInOutCubic,
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
    final accent = SeedPalette.accent(song?.artworkSeed ?? 'lyrics');

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
          // Blurred album-art background + dark overlay.
          if (song != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: AuraArtwork(
                    seed: song.artworkSeed,
                    size: MediaQuery.sizeOf(context).width,
                    hasArtwork: song.hasArtwork,
                  ),
                ),
              ),
            ),
          Positioned.fill(child: ColoredBox(color: colors.background.withOpacity(0.48))),
          // Ambient orbs — slow drift layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientCtrl,
              builder: (_, __) => CustomPaint(
                painter: _LyricsAmbientPainter(
                  t: _ambientCtrl.value,
                  accent: accent,
                ),
              ),
            ),
          ),
          // Frosted-glass light from below — pulses softly with rhythm
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final pulse =
                    0.5 + 0.5 * math.sin(_pulseCtrl.value * 2 * math.pi);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        // Bottom: warm glow that breathes
                        accent.withOpacity(0.055 + 0.028 * pulse),
                        accent.withOpacity(0.022 + 0.010 * pulse),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.38, 0.70],
                    ),
                  ),
                );
              },
            ),
          ),
          // Top edge: very faint white shimmer (frosted ceiling reflection)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: l10n.lyrics,
                  hasTranslations:
                      lyricsAsync.valueOrNull?.hasTranslations ?? false,
                  dual: dual,
                  fontSize: fontSize,
                  onToggleDual: () => ref
                      .read(dualLanguageProvider.notifier)
                      .update((v) => !v),
                  onCycleFontSize: () => ref
                      .read(lyricsFontSizeProvider.notifier)
                      .update(_nextFontSize),
                  onOpenSync: () => openSyncEditor(context),
                ),
                Expanded(
                  child: AsyncStateView<Lyrics?>(
                    value: lyricsAsync.like,
                    isEmpty: (l) => l == null || l.isEmpty,
                    emptyMessage: l10n.lyricsNone,
                    emptyIcon: Icons.lyrics_outlined,
                    data: (lyrics) => _LyricsBody(
                      lyrics: lyrics!,
                      controller: _scrollController,
                      keys: () {
                        _ensureKeys(lyrics.lines.length);
                        return _keys;
                      }(),
                      fontSize: fontSize,
                      dual: dual,
                      accent: accent,
                      directionFor: _directionFor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

LyricsFontSize _nextFontSize(LyricsFontSize s) => switch (s) {
      LyricsFontSize.small => LyricsFontSize.medium,
      LyricsFontSize.medium => LyricsFontSize.large,
      LyricsFontSize.large => LyricsFontSize.small,
    };

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.hasTranslations,
    required this.dual,
    required this.fontSize,
    required this.onToggleDual,
    required this.onCycleFontSize,
    required this.onOpenSync,
  });

  final String title;
  final bool hasTranslations;
  final bool dual;
  final LyricsFontSize fontSize;
  final VoidCallback onToggleDual;
  final VoidCallback onCycleFontSize;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    // Stack ensures the title is absolutely centered regardless of how many
    // action buttons are on each side.
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextTheme.caption.copyWith(
              color: colors.onSurfaceMuted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
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
            if (hasTranslations)
              IconButton(
                tooltip: dual ? l10n.lyricsDual : l10n.lyricsSingle,
                onPressed: onToggleDual,
                icon: Icon(Icons.translate,
                    color: dual ? colors.onSurface : colors.onSurfaceFaint),
              ),
            IconButton(
              tooltip: l10n.lyricsFontSize,
              onPressed: onCycleFontSize,
              icon: Icon(Icons.format_size, color: colors.onSurfaceMuted),
            ),
            IconButton(
              tooltip: l10n.syncTitle,
              onPressed: onOpenSync,
              icon: Icon(Icons.edit_note, color: colors.onSurfaceMuted),
            ),
          ],
        ),
      ],
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
    required this.accent,
    required this.directionFor,
  });

  final Lyrics lyrics;
  final ScrollController controller;
  final List<GlobalKey> keys;
  final LyricsFontSize fontSize;
  final bool dual;
  final Color accent;
  final TextDirection Function(String) directionFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = lyrics.synced ? ref.watch(currentLyricLineProvider) : -1;
    final controllerRef = ref.read(audioControllerProvider);

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.xl,
        vertical: MediaQuery.sizeOf(context).height * 0.32,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, i) {
        final line = lyrics.lines[i];
        final relation = !lyrics.synced
            ? _Relation.neutral
            : i == current
                ? _Relation.current
                : i < current
                    ? _Relation.past
                    : _Relation.future;
        final lineEnd = i + 1 < lyrics.lines.length
            ? lyrics.lines[i + 1].time
            : line.time + const Duration(seconds: 4);

        return Padding(
          key: keys.length == lyrics.lines.length ? keys[i] : null,
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: _LyricRow(
            line: line,
            relation: relation,
            fontSize: fontSize,
            dual: dual,
            accent: accent,
            lineEnd: lineEnd,
            direction: directionFor(line.text),
            onTap: lyrics.synced ? () => controllerRef.seek(line.time) : null,
          ),
        );
      },
    );
  }
}

enum _Relation { current, past, future, neutral }

class _LyricRow extends StatelessWidget {
  const _LyricRow({
    required this.line,
    required this.relation,
    required this.fontSize,
    required this.dual,
    required this.accent,
    required this.lineEnd,
    required this.direction,
    required this.onTap,
  });

  final LyricsLine line;
  final _Relation relation;
  final LyricsFontSize fontSize;
  final bool dual;
  final Color accent;
  final Duration lineEnd;
  final TextDirection direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrent = relation == _Relation.current;
    final size = (isCurrent
        ? _LyricMetrics.current
        : _LyricMetrics.secondary)[fontSize]!;

    final color = switch (relation) {
      _Relation.current => accent,
      _Relation.past => colors.onSurfaceFaint,
      _Relation.future => colors.onSurfaceMuted,
      _Relation.neutral => colors.onSurface,
    };

    final style = AppTextTheme.body.copyWith(
      fontSize: size,
      height: 1.3,
      fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
      color: color,
    );

    final Widget primary;
    if (isCurrent && line.hasWordTimings) {
      primary = _CurrentKaraoke(
        words: line.words,
        lineEnd: lineEnd,
        style: style,
        accent: accent,
        base: colors.onSurfaceFaint,
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
          const SizedBox(height: 2),
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

    // Wrap the active line in a subtle glass capsule.
    final Widget inner = isCurrent
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.20), width: 1),
            ),
            child: content,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: content,
          );

    return GestureDetector(
      onTap: onTap,
      child: Center(child: inner),
    );
  }

  static TextDirection directionForText(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr;
}

// ── Ambient frosted-glass gradient that breathes behind the lyrics ───────────

class _LyricsAmbientPainter extends CustomPainter {
  _LyricsAmbientPainter({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Top orb — shifts slowly left/right
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.35 + 0.30 * _n(math.sin(t * 2 * math.pi * 0.25))),
        size.height * 0.18,
      ),
      size.width * 0.55,
      accent.withOpacity(0.055),
    );
    // Bottom orb — counter-phase drift
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.55 + 0.28 * _n(math.cos(t * 2 * math.pi * 0.20 + 1.8))),
        size.height * 0.80,
      ),
      size.width * 0.48,
      accent.withOpacity(0.045),
    );
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ).createShader(Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2,
        )),
    );
  }

  double _n(double x) => (x + 1.0) / 2.0;

  @override
  bool shouldRepaint(_LyricsAmbientPainter o) => o.t != t || o.accent != accent;
}

/// The active line's karaoke fill — watches [positionProvider] so only this one
/// line repaints per tick.
class _CurrentKaraoke extends ConsumerWidget {
  const _CurrentKaraoke({
    required this.words,
    required this.lineEnd,
    required this.style,
    required this.accent,
    required this.base,
    required this.direction,
  });

  final List<LyricWord> words;
  final Duration lineEnd;
  final TextStyle style;
  final Color accent;
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
      accent: accent,
      base: base,
      textDirection: direction,
    );
  }
}
