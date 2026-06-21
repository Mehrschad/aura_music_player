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

/// Progress scrubber. The clean progress rail is *always* visible (playing or
/// paused) so the position is never lost. While playing, a faint translucent
/// "subdermal" wave ripples just beneath the surface of the rail; when paused
/// it settles back to a still, clean line.
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

  // Drives the slow horizontal travel of the subdermal wave while playing.
  late final AnimationController _waveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  // 0 = still line (paused), 1 = rippling wave (playing).
  late final AnimationController _waveAmpCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
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
    _syncWave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(WaveformScrubber old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) _syncWave();
  }

  void _syncWave() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.isPlaying && !reduceMotion) {
      if (!_waveCtrl.isAnimating) _waveCtrl.repeat();
      _waveAmpCtrl.animateTo(1.0, curve: Curves.easeOut);
    } else {
      _waveCtrl.stop();
      if (reduceMotion) {
        _waveAmpCtrl.value = widget.isPlaying ? 1.0 : 0.0;
      } else {
        _waveAmpCtrl.animateTo(0.0, curve: Curves.easeIn);
      }
    }
  }

  @override
  void dispose() {
    _thumbController.dispose();
    _seekController.dispose();
    _waveCtrl.dispose();
    _waveAmpCtrl.dispose();
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
                  // ── track gesture area ─────────────────────────────────
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
                        animation: Listenable.merge(
                            [_thumbScale, _waveAmpCtrl, _waveCtrl]),
                        builder: (_, __) {
                          return CustomPaint(
                            size: Size(w, 44),
                            painter: _TrackPainter(
                              progress: fraction,
                              activeColor: widget.accent,
                              trackColor: colors.onSurface.withOpacity(0.10),
                              trackH: 4.0 + 2.0 * _thumbScale.value,
                              waveAmp: _waveAmpCtrl.value,
                              wavePhase: _waveCtrl.value,
                              bookmarkFractions: widget.bookmarkFractions,
                              abA: widget.abPointA,
                              abB: widget.abPointB,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── playhead dot (always visible) ──────────────────────
                  AnimatedBuilder(
                    animation: _thumbScale,
                    builder: (_, __) {
                      const baseR = 5.0;
                      const dragR = 9.0;
                      final r = baseR + (dragR - baseR) * _thumbScale.value;
                      const trackY = 22.0;
                      return Positioned(
                        bottom: trackY - r,
                        left: (thumbX - r).clamp(0.0, math.max(0, w - r * 2)),
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

// ── Track painter ────────────────────────────────────────────────────────────

/// Clean progress rail (always visible) plus a faint translucent "subdermal"
/// sine wave that ripples beneath the surface while playing ([waveAmp] → 1) and
/// flattens to nothing when paused ([waveAmp] → 0).
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.waveAmp,
    required this.wavePhase,
    this.trackH = 4.0,
    this.bookmarkFractions = const [],
    this.abA,
    this.abB,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double waveAmp;
  final double wavePhase;
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

    // Subdermal wave — a thin, translucent sine just under the rail surface.
    if (waveAmp > 0.01) {
      final amp = 2.6 * waveAmp;
      const periods = 13.0;
      const twoPi = 2 * math.pi;

      Path build(double from, double to) {
        final p = Path();
        var first = true;
        for (double x = from; x <= to; x += 2) {
          final phase = (x / size.width) * periods * twoPi - wavePhase * twoPi;
          final y = centerY + math.sin(phase) * amp;
          if (first) {
            p.moveTo(x, y);
            first = false;
          } else {
            p.lineTo(x, y);
          }
        }
        return p;
      }

      // Unplayed side — barely-there.
      canvas.drawPath(
        build(playheadX, size.width),
        Paint()
          ..color = activeColor.withOpacity(0.06 * waveAmp)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
      // Played side — a touch more present, still subdermal.
      if (playheadX > 1) {
        canvas.drawPath(
          build(0, playheadX),
          Paint()
            ..color = activeColor.withOpacity(0.16 * waveAmp)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );
      }
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
      o.waveAmp != waveAmp ||
      o.wavePhase != wavePhase ||
      o.trackH != trackH ||
      o.bookmarkFractions != bookmarkFractions ||
      o.abA != abA ||
      o.abB != abB;
}
