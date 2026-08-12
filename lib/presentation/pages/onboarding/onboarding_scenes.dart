import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/aurora_colors.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';

/// Every onboarding slide shows the feature working rather than an icon
/// standing in for it: the lyric slide really fills a line word by word, the
/// colour slide really pulls its accent off the artwork behind the glass.
///
/// All scenes share one looping [progress] animation and one box size, and all
/// of them hold a meaningful still frame under reduce-motion — the pose that
/// best explains the feature, not a blank.
const double kSceneWidth = 230;
const double kSceneHeight = 150;

/// A still, representative moment for each scene when motion is off.
const double _kStillFrame = 0.42;

double _frame(Animation<double> progress, bool reduceMotion) =>
    reduceMotion ? _kStillFrame : progress.value;

/// ── 1. Your library, playing from your own device ──────────────────────────
///
/// The brand mark with rings pushing outward: sound leaving a point. Nothing
/// arrives from a network — it radiates from the centre you already own.
class AuraPulseScene extends StatelessWidget {
  const AuraPulseScene({
    super.key,
    required this.progress,
    required this.reduceMotion,
  });

  final Animation<double> progress;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kSceneWidth,
      height: kSceneHeight,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => CustomPaint(
          painter: _PulsePainter(_frame(progress, reduceMotion)),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t);
  final double t;

  /// The aurora ribbon at a given opacity.
  ///
  /// Baked into the shader's own stops rather than set on `Paint.color`: once
  /// a paint carries a shader its colour is ignored, so fading the rings any
  /// other way would need a saveLayer per ring.
  static Shader _ribbon(Rect bounds, double opacity) => LinearGradient(
        begin: AuroraColors.gradient.begin,
        end: AuroraColors.gradient.end,
        stops: AuroraColors.gradient.stops,
        colors: [
          for (final c in AuroraColors.gradient.colors) c.withOpacity(opacity),
        ],
      ).createShader(bounds);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxR = size.height / 2;
    final bounds = Rect.fromCircle(center: centre, radius: maxR);

    // Three rings, evenly out of phase, each fading as it expands.
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final r = maxR * (0.22 + phase * 0.78);
      final fade = (1 - phase).clamp(0.0, 1.0);
      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..shader = _ribbon(bounds, fade * 0.8),
      );
    }

    // The source: a small solid disc that breathes with the pulse.
    final beat = 1 + 0.12 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(
      centre,
      6.5 * beat,
      Paint()..shader = _ribbon(bounds, 1.0),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// ── 2. Liquid Glass, coloured by the cover ─────────────────────────────────
///
/// A cover cycles behind a frosted panel. The panel really blurs what is
/// behind it, and the accent dot really tracks the cover's colour — which is
/// the whole claim: one calm accent, pulled from each album.
class DynamicColourScene extends StatelessWidget {
  const DynamicColourScene({
    super.key,
    required this.progress,
    required this.reduceMotion,
  });

  final Animation<double> progress;
  final bool reduceMotion;

  /// Stand-in covers, one per aurora anchor, so the accent visibly changes.
  static const _covers = <(Color, Color)>[
    (AuroraColors.c1, AuroraColors.c2),
    (AuroraColors.c3, AuroraColors.c4),
    (AuroraColors.c2, AuroraColors.c3),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: kSceneWidth,
      height: kSceneHeight,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = _frame(progress, reduceMotion);
          // Cross-fade between covers so the accent glides rather than jumps.
          final scaled = t * _covers.length;
          final index = scaled.floor() % _covers.length;
          final next = (index + 1) % _covers.length;
          final k = Curves.easeInOut.transform(
              (scaled - scaled.floor()).clamp(0.0, 1.0));
          final top = Color.lerp(_covers[index].$1, _covers[next].$1, k)!;
          final bottom = Color.lerp(_covers[index].$2, _covers[next].$2, k)!;
          final accent = Color.lerp(top, bottom, 0.5)!;

          return Stack(
            alignment: Alignment.center,
            children: [
              // The artwork.
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [top, bottom],
                  ),
                ),
              ),
              // The glass sitting over it.
              Positioned(
                bottom: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 172,
                      height: 54,
                      padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.md),
                      decoration: BoxDecoration(
                        color: colors.background.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          // The one accent, taken from the cover behind.
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: accent.withOpacity(0.6),
                                    blurRadius: 10),
                              ],
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Bar(width: 78, color: colors.onSurface),
                                const SizedBox(height: 6),
                                _Bar(width: 48, color: accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A stand-in for a line of text — the scene is about colour and blur, so real
/// words would only compete for attention.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 5,
        decoration: BoxDecoration(
          color: color.withOpacity(0.75),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

/// ── 3. Lyrics that keep time ───────────────────────────────────────────────
///
/// The middle line fills left to right as the "song" plays, then the stack
/// steps on. This is the real karaoke treatment from the lyrics view, at a
/// smaller size.
class SyncedLyricsScene extends StatelessWidget {
  const SyncedLyricsScene({
    super.key,
    required this.progress,
    required this.reduceMotion,
  });

  final Animation<double> progress;
  final bool reduceMotion;

  static const _lines = [
    'we chase the fading sky',
    'hold on till morning',
    'aurora skyline',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: kSceneWidth,
      height: kSceneHeight,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = _frame(progress, reduceMotion);
          final scaled = t * _lines.length;
          final active = scaled.floor() % _lines.length;
          final fill = (scaled - scaled.floor()).clamp(0.0, 1.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _lines.length; i++) ...[
                if (i > 0) const SizedBox(height: SpacingTokens.md),
                _LyricLine(
                  text: _lines[i],
                  // Only the active line is lit; the others sit back, exactly
                  // as they do on the lyrics screen.
                  fill: i == active ? fill : (i < active ? 1.0 : 0.0),
                  current: i == active,
                  base: colors.onSurfaceFaint,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  const _LyricLine({
    required this.text,
    required this.fill,
    required this.current,
    required this.base,
  });

  final String text;
  final double fill;
  final bool current;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final style = AppTextTheme.body.copyWith(
      fontSize: current ? 17 : 14,
      height: 1.2,
      fontWeight: current ? FontWeight.w600 : FontWeight.w500,
    );

    final dim = Text(text,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: style.copyWith(color: base.withOpacity(current ? 0.45 : 0.30)));

    if (fill <= 0) return dim;

    // The lit copy is clipped to the played fraction and painted with the
    // aurora ribbon, so the sweep reads as the song moving through the line.
    final lit = ShaderMask(
      shaderCallback: (b) => AuroraColors.gradient.createShader(b),
      blendMode: BlendMode.srcIn,
      child: Text(text,
          textAlign: TextAlign.center, maxLines: 1, style: style),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        dim,
        ClipRect(
          clipper: _FractionClipper(fill),
          child: lit,
        ),
      ],
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_FractionClipper old) => old.fraction != fraction;
}

/// ── 4. Sound you can shape ─────────────────────────────────────────────────
///
/// Ten EQ bands settle into a curve while a waveform runs beneath them: the
/// two controls the player gives you over how a track actually sounds.
class EqualiserScene extends StatelessWidget {
  const EqualiserScene({
    super.key,
    required this.progress,
    required this.reduceMotion,
  });

  final Animation<double> progress;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: kSceneWidth,
      height: kSceneHeight,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => CustomPaint(
          painter: _EqualiserPainter(
            _frame(progress, reduceMotion),
            track: colors.onSurfaceFaint.withOpacity(0.28),
          ),
        ),
      ),
    );
  }
}

class _EqualiserPainter extends CustomPainter {
  _EqualiserPainter(this.t, {required this.track});
  final double t;
  final Color track;

  static const _bands = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = AuroraColors.gradient.createShader(Offset.zero & size);
    final slot = size.width / _bands;
    final barW = slot * 0.34;
    final top = size.height * 0.10;
    final bottom = size.height * 0.66;
    final span = bottom - top;

    for (var i = 0; i < _bands; i++) {
      final cx = slot * (i + 0.5);
      // A smile curve that breathes: low and high bands lifted, mids relaxed,
      // which is what a listener actually dials in.
      final shape = 0.35 + 0.45 * math.pow(math.cos((i / (_bands - 1) - 0.5) * math.pi), 2).toDouble();
      final wobble = 0.12 * math.sin(t * 2 * math.pi + i * 0.7);
      final level = (shape + wobble).clamp(0.12, 1.0);

      // Track.
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, top, barW, span),
        const Radius.circular(6),
      );
      canvas.drawRRect(trackRect, Paint()..color = track);

      // Filled portion, rising from the baseline.
      final h = span * level;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, bottom - h, barW, h),
          const Radius.circular(6),
        ),
        Paint()..shader = shader,
      );
    }

    // Waveform beneath: the scrubbable shape of the track.
    final baseY = size.height * 0.86;
    final path = Path()..moveTo(0, baseY);
    for (var x = 0.0; x <= size.width; x += 2) {
      final u = x / size.width;
      final env = math.sin(u * math.pi); // fades in and out at the edges
      final y = baseY -
          env *
              10 *
              math.sin(u * 18 + t * 2 * math.pi) *
              math.cos(u * 5 - t * math.pi);
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_EqualiserPainter old) => old.t != t;
}

/// ── Backdrop ───────────────────────────────────────────────────────────────
///
/// The aurora wash behind everything.
///
/// It is painted, not transformed. The previous version rotated a
/// screen-sized rectangle scaled 1.4x, but a tall rectangle needs far more
/// than that to keep covering as it turns — on a 360x800 phone it stopped
/// covering after 15 degrees, and the sweep runs to 90, so most of the screen
/// fell through to the black Scaffold and the intro went dark. A painter that
/// fills its own canvas cannot uncover.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({
    super.key,
    required this.progress,
    required this.reduceMotion,
  });

  final Animation<double> progress;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _BackdropPainter(
          reduceMotion ? 0.0 : progress.value,
          sink: context.colors.background,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t, {required this.sink});
  final double t;
  final Color sink;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Drift the gradient's axis instead of spinning the geometry.
    final angle = t * 2 * math.pi;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
          colors: const [
            AuroraColors.c1,
            AuroraColors.c2,
            AuroraColors.c3,
            AuroraColors.c4,
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(rect),
    );

    // Sink the edges into the page so the wash reads as a glow behind the
    // content rather than a painted sheet.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 1.15,
          colors: [sink.withOpacity(0.10), sink],
          stops: const [0.28, 0.92],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t || old.sink != sink;
}
