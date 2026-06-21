import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/playback_providers.dart';

/// Progress scrubber that shows animated EQ bars while playing and collapses
/// to a clean thin track when paused. Transitions between modes smoothly.
///
/// [onLongPress] fires with the tapped duration — host uses this to cycle
/// A-B repeat points. [bookmarkFractions] draw tick marks on the track.
/// [abPointA] / [abPointB] are 0-1 fractions that highlight the loop region.
class WaveformScrubber extends ConsumerStatefulWidget {
  const WaveformScrubber({
    super.key,
    required this.duration,
    required this.accent,
    required this.seed,
    required this.isPlaying,
    this.onLongPress,
    this.bookmarkFractions = const [],
    this.abPointA,
    this.abPointB,
  });

  final Duration duration;
  final Color accent;
  final String seed;
  final bool isPlaying;
  final void Function(Duration position)? onLongPress;
  final List<double> bookmarkFractions;
  final double? abPointA;
  final double? abPointB;

  @override
  ConsumerState<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends ConsumerState<WaveformScrubber>
    with TickerProviderStateMixin {
  double? _dragFraction;
  double _lastFraction = 0;

  late final AnimationController _thumbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _thumbScale = CurvedAnimation(
    parent: _thumbController,
    curve: const Cubic(0.34, 1.56, 0.64, 1.0),
  );

  late final AnimationController _seekController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Animation<double>? _seekAnim;

  // Drives the EQ bar animation while playing.
  late final AnimationController _barCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  // 0 = line mode (paused), 1 = bar mode (playing).
  late final AnimationController _modeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.isPlaying ? 1.0 : 0.0,
  );

  @override
  void initState() {
    super.initState();
    _seekController.addListener(() {
      final a = _seekAnim;
      if (a != null) setState(() => _dragFraction = a.value);
    });
    _seekController.addStatusListener((s) {
      if (s == AnimationStatus.completed && _seekAnim != null) {
        _seekToFraction(_seekAnim!.value);
        setState(() => _dragFraction = null);
        _thumbController.reverse();
      }
    });
    _syncBars();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBars();
  }

  @override
  void didUpdateWidget(WaveformScrubber old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) _syncBars();
  }

  void _syncBars() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.isPlaying && !reduceMotion) {
      if (!_barCtrl.isAnimating) _barCtrl.repeat();
      _modeCtrl.animateTo(1.0, curve: Curves.easeOut);
    } else {
      _barCtrl.stop();
      if (reduceMotion) {
        _modeCtrl.value = widget.isPlaying ? 1.0 : 0.0;
      } else {
        _modeCtrl.animateTo(0.0, curve: Curves.easeIn);
      }
    }
  }

  @override
  void dispose() {
    _thumbController.dispose();
    _seekController.dispose();
    _barCtrl.dispose();
    _modeCtrl.dispose();
    super.dispose();
  }

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  void _seekToFraction(double f) {
    final ms = (f.clamp(0.0, 1.0) * _totalMs).round();
    ref.read(audioControllerProvider).seek(Duration(milliseconds: ms));
  }

  void _animatedSeekTo(double target) {
    final clamped = target.clamp(0.0, 1.0);
    _seekAnim = Tween<double>(begin: _lastFraction, end: clamped).animate(
      CurvedAnimation(parent: _seekController, curve: Curves.easeOutCubic),
    );
    _thumbController.forward();
    _seekController.forward(from: 0);
  }

  void _onDragStart(double x, double w) {
    _seekController.stop();
    _seekAnim = null;
    setState(() => _dragFraction = (x / w).clamp(0.0, 1.0));
    _thumbController.forward();
  }

  void _onDragUpdate(double x, double w) =>
      setState(() => _dragFraction = (x / w).clamp(0.0, 1.0));

  void _onDragEnd() {
    if (_dragFraction != null) {
      HapticFeedback.selectionClick();
      _seekToFraction(_dragFraction!);
    }
    _thumbController.reverse();
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final hasDuration = _totalMs > 0;

    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final playFrac =
        hasDuration ? (position.inMilliseconds / _totalMs).clamp(0.0, 1.0) : 0.0;
    final fraction = _dragFraction ?? playFrac;
    _lastFraction = fraction;
    final tooltipTime = Duration(milliseconds: (fraction * _totalMs).round());

    final pct = (fraction * 100).round();
    final incPct = ((fraction + 0.05).clamp(0.0, 1.0) * 100).round();
    final decPct = ((fraction - 0.05).clamp(0.0, 1.0) * 100).round();

    return Semantics(
      container: true,
      slider: true,
      label: l10n.a11ySeekBar,
      value: '$pct%',
      increasedValue: '$incPct%',
      decreasedValue: '$decPct%',
      onIncrease: hasDuration ? () => _seekToFraction(fraction + 0.05) : null,
      onDecrease: hasDuration ? () => _seekToFraction(fraction - 0.05) : null,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              final thumbX = fraction * w;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── track / bar gesture area ───────────────────────────
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: GestureDetector(
                      key: const Key('scrubber_gesture'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: hasDuration
                          ? (d) => _animatedSeekTo(d.localPosition.dx / w)
                          : null,
                      onLongPressStart: widget.onLongPress != null && hasDuration
                          ? (d) {
                              _seekController.stop();
                              _seekAnim = null;
                              _thumbController.reverse();
                              final f = (d.localPosition.dx / w).clamp(0.0, 1.0);
                              widget.onLongPress!(
                                Duration(
                                    milliseconds: (f * _totalMs).round()),
                              );
                            }
                          : null,
                      onHorizontalDragStart: hasDuration
                          ? (d) => _onDragStart(d.localPosition.dx, w)
                          : null,
                      onHorizontalDragUpdate: hasDuration
                          ? (d) => _onDragUpdate(d.localPosition.dx, w)
                          : null,
                      onHorizontalDragEnd:
                          hasDuration ? (_) => _onDragEnd() : null,
                      child: AnimatedBuilder(
                        animation:
                            Listenable.merge([_thumbScale, _modeCtrl, _barCtrl]),
                        builder: (_, __) {
                          final mode = _modeCtrl.value;
                          return Stack(
                            children: [
                              // Line mode layer (fades out when playing)
                              if (mode < 0.999)
                                Opacity(
                                  opacity: (1.0 - mode).clamp(0.0, 1.0),
                                  child: CustomPaint(
                                    size: Size(w, 44),
                                    painter: _TrackPainter(
                                      progress: fraction,
                                      activeColor: widget.accent,
                                      trackColor:
                                          colors.onSurface.withOpacity(0.10),
                                      trackH: 4.0 + 2.0 * _thumbScale.value,
                                      bookmarkFractions: widget.bookmarkFractions,
                                      abA: widget.abPointA,
                                      abB: widget.abPointB,
                                    ),
                                  ),
                                ),
                              // Bar mode layer (fades in when playing)
                              if (mode > 0.001)
                                Opacity(
                                  opacity: mode.clamp(0.0, 1.0),
                                  child: CustomPaint(
                                    size: Size(w, 44),
                                    painter: _BarPainter(
                                      progress: fraction,
                                      t: _barCtrl.value,
                                      activeColor: widget.accent,
                                      abA: widget.abPointA,
                                      abB: widget.abPointB,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // ── playhead dot (line mode only) ──────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_thumbScale, _modeCtrl]),
                    builder: (_, __) {
                      final mode = _modeCtrl.value;
                      if (mode > 0.85) return const SizedBox.shrink();
                      final opacity = (1.0 - mode / 0.85).clamp(0.0, 1.0);
                      final baseR = 5.0;
                      final dragR = 9.0;
                      final r = baseR + (dragR - baseR) * _thumbScale.value;
                      const trackY = 22.0;
                      return Positioned(
                        bottom: trackY - r,
                        left: (thumbX - r).clamp(0.0, math.max(0, w - r * 2)),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: r * 2,
                            height: r * 2,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accent.withOpacity(0.38),
                                  blurRadius: 7 + 4 * _thumbScale.value,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ── tooltip ────────────────────────────────────────────
                  if (_dragFraction != null)
                    Positioned(
                      bottom: 44 + 4,
                      left: (thumbX - 26).clamp(0.0, math.max(0, w - 52)),
                      child: _Tooltip(time: tooltipTime, accent: widget.accent),
                    ),
                ],
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Duration(milliseconds: (playFrac * _totalMs).round()).clock,
                  style:
                      AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
                ),
                Text(
                  widget.duration.clock,
                  style:
                      AppTextTheme.caption.copyWith(color: colors.onSurfaceFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tooltip ──────────────────────────────────────────────────────────────────

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.time, required this.accent});
  final Duration time;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: RadiusTokens.brSm,
        border: Border.all(color: accent.withOpacity(0.35), width: 1),
      ),
      child: Text(
        time.clock,
        style: AppTextTheme.caption
            .copyWith(color: colors.onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Line mode painter (paused) ───────────────────────────────────────────────

/// Clean progress line — no neon, just a soft filled rail and optional A-B pins.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    this.trackH = 4.0,
    this.bookmarkFractions = const [],
    this.abA,
    this.abB,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double trackH;
  final List<double> bookmarkFractions;
  final double? abA;
  final double? abB;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final playheadX = progress * size.width;
    final r = trackH / 2;

    // Dim rail
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - r, size.width, trackH),
        Radius.circular(r),
      ),
      Paint()..color = trackColor,
    );

    // Active fill
    if (playheadX > 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - r, playheadX, trackH),
          Radius.circular(r),
        ),
        Paint()..color = activeColor.withOpacity(0.82),
      );
    }

    // A-B loop region
    final a = abA;
    final b = abB;
    if (a != null) {
      final ax = a * size.width;
      final bx = (b ?? progress) * size.width;
      if (bx > ax) {
        canvas.drawRect(
          Rect.fromLTWH(ax, centerY - 5, bx - ax, 10),
          Paint()..color = activeColor.withOpacity(0.18),
        );
      }
      _drawPin(canvas, ax, centerY, activeColor);
      if (b != null) _drawPin(canvas, b * size.width, centerY, activeColor);
    }

    // Bookmark ticks
    final tickPaint = Paint()
      ..color = activeColor.withOpacity(0.65)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final f in bookmarkFractions) {
      final x = f.clamp(0.0, 1.0) * size.width;
      canvas.drawLine(Offset(x, centerY - 5), Offset(x, centerY + 5), tickPaint);
    }
  }

  void _drawPin(Canvas canvas, double x, double cy, Color color) {
    canvas.drawLine(
      Offset(x, cy - 8),
      Offset(x, cy + 8),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter o) =>
      o.progress != progress ||
      o.activeColor != activeColor ||
      o.trackColor != trackColor ||
      o.trackH != trackH ||
      o.bookmarkFractions != bookmarkFractions ||
      o.abA != abA ||
      o.abB != abB;
}

// ── Bar mode painter (playing) ───────────────────────────────────────────────

/// Animated EQ visualizer bars. Bars to the left of the playhead are bright;
/// bars to the right are dim. Each bar oscillates at a unique phase and speed.
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.progress,
    required this.t,
    required this.activeColor,
    this.abA,
    this.abB,
  });

  final double progress;
  final double t;
  final Color activeColor;
  final double? abA;
  final double? abB;

  static const double _barW = 3.5;
  static const double _gap = 2.5;
  static const double _step = _barW + _gap;
  static const double _maxH = 36.0;
  static const double _minH = 3.0;

  // Spectrum envelope: peaks in the upper-mids, simulates typical music energy.
  static const List<double> _env = [
    0.18, 0.32, 0.52, 0.70, 0.84, 0.92, 0.98, 1.00, 0.96, 0.90,
    0.88, 0.92, 0.96, 0.88, 0.78, 0.68, 0.62, 0.70, 0.58, 0.46,
    0.40, 0.42, 0.36, 0.28, 0.24, 0.20, 0.16, 0.20, 0.24, 0.18,
    0.14, 0.12,
  ];

  double _barH(int i) {
    final base = _env[i % _env.length];
    final phase = i * 0.51;
    final freq = 0.65 + (i % 7) * 0.10;
    final anim = 0.35 + 0.65 * ((1.0 + math.sin(t * 2 * math.pi * freq + phase)) / 2);
    return _minH + (_maxH - _minH) * base * anim;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = (size.width / _step).floor();
    if (n < 2) return;
    final totalW = n * _step - _gap;
    final startX = (size.width - totalW) / 2;
    final centerY = size.height / 2;
    final playheadX = progress * size.width;

    // A-B tint behind bars
    final a = abA;
    final b = abB;
    if (a != null && b != null) {
      canvas.drawRect(
        Rect.fromLTWH(a * size.width, 0, (b - a) * size.width, size.height),
        Paint()..color = activeColor.withOpacity(0.09),
      );
    }

    for (int i = 0; i < n; i++) {
      final x = startX + i * _step;
      final h = _barH(i);
      final played = (x + _barW / 2) <= playheadX;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - h / 2, _barW, h),
          const Radius.circular(1.5),
        ),
        Paint()..color = activeColor.withOpacity(played ? 0.80 : 0.26),
      );
    }

    // Thin playhead line in bar mode
    if (playheadX > 0 && playheadX < size.width) {
      canvas.drawLine(
        Offset(playheadX, 2),
        Offset(playheadX, size.height - 2),
        Paint()
          ..color = activeColor.withOpacity(0.72)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) =>
      o.progress != progress ||
      o.t != t ||
      o.activeColor != activeColor ||
      o.abA != abA ||
      o.abB != abB;
}
