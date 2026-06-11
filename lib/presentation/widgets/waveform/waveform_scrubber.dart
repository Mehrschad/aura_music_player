import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../providers/playback_providers.dart';

/// Samsung Music / Material You-style progress scrubber.
///
/// A thin rounded track (4 dp) with a glowing circle dot at the playhead.
/// When playing, very soft sine-wave ripples travel behind the dot in the
/// unplayed portion — barely perceptible, never distracting (≤ 8% amplitude).
/// When scrubbing, the dot inflates with a spring and a time tooltip appears.
class WaveformScrubber extends ConsumerStatefulWidget {
  const WaveformScrubber({
    super.key,
    required this.duration,
    required this.accent,
    required this.seed,
  });

  final Duration duration;
  final Color accent;
  final String seed;

  @override
  ConsumerState<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends ConsumerState<WaveformScrubber>
    with TickerProviderStateMixin {
  double? _dragFraction;

  late final AnimationController _thumbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _thumbScale = CurvedAnimation(
    parent: _thumbController,
    curve: const Cubic(0.34, 1.56, 0.64, 1.0), // spring
  );

  Ticker? _ticker;
  double _animTime = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration _) {
    if (_isPlaying) setState(() => _animTime += 1 / 60);
  }

  void _syncPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    if (playing) {
      if (!(_ticker?.isTicking ?? false)) _ticker?.start();
    } else {
      _ticker?.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  void _seekToFraction(double f) {
    final ms = (f.clamp(0.0, 1.0) * _totalMs).round();
    ref.read(audioControllerProvider).seek(Duration(milliseconds: ms));
  }

  void _onDragStart(double x, double w) {
    setState(() => _dragFraction = (x / w).clamp(0.0, 1.0));
    _thumbController.forward();
  }

  void _onDragUpdate(double x, double w) =>
      setState(() => _dragFraction = (x / w).clamp(0.0, 1.0));

  void _onDragEnd() {
    if (_dragFraction != null) _seekToFraction(_dragFraction!);
    _thumbController.reverse();
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final hasDuration = _totalMs > 0;

    final playing = ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;
    _syncPlaying(playing);

    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final playFrac =
        hasDuration ? (position.inMilliseconds / _totalMs).clamp(0.0, 1.0) : 0.0;
    final fraction = _dragFraction ?? playFrac;
    final tooltipTime = Duration(milliseconds: (fraction * _totalMs).round());

    return Semantics(
      container: true,
      slider: true,
      label: l10n.a11ySeekBar,
      value: '${(fraction * 100).round()}%',
      onIncrease: hasDuration ? () => _seekToFraction(fraction + 0.05) : null,
      onDecrease: hasDuration ? () => _seekToFraction(fraction - 0.05) : null,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56, // track area + tooltip clearance
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              final thumbX = fraction * w;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── track ──────────────────────────────────────────────
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: GestureDetector(
                      key: const Key('scrubber_gesture'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: hasDuration
                          ? (d) => _seekToFraction(d.localPosition.dx / w)
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
                        animation: _thumbScale,
                        builder: (_, __) => CustomPaint(
                          painter: _TrackPainter(
                            progress: fraction,
                            activeColor: widget.accent,
                            trackColor: widget.accent.withOpacity(0.22),
                            animTime: _animTime,
                            isPlaying: playing,
                            totalWidth: w,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── glowing dot ────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _thumbScale,
                    builder: (_, __) {
                      final baseR = 5.0;
                      final dragR = 9.0;
                      final r = baseR + (dragR - baseR) * _thumbScale.value;
                      const trackY = 22.0; // center of 44px gesture area
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
                                color: widget.accent.withOpacity(0.45),
                                blurRadius: 8 + 4 * _thumbScale.value,
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

/// Draws the thin rounded track + very-soft ripple waves in the unplayed region.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.animTime,
    required this.isPlaying,
    required this.totalWidth,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double animTime;
  final bool isPlaying;
  final double totalWidth;

  static const double _trackH = 4.0;
  static const double _waveAmp = 0.06; // 6% of trackH — barely perceptible
  static const double _waveFreq = 0.9; // Hz
  static const int _segments = 160; // smoothness of the wave

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final playheadX = progress * size.width;
    final r = _trackH / 2;

    // ── played portion: solid flat pill ──────────────────────────────────
    if (playheadX > r) {
      final paint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - r, playheadX, _trackH),
          Radius.circular(r),
        ),
        paint,
      );
    }

    // ── unplayed portion: flat track + soft sine ripple on top ────────────
    if (playheadX < size.width - r) {
      final basePaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              playheadX, centerY - r, size.width - playheadX, _trackH),
          Radius.circular(r),
        ),
        basePaint,
      );

      // Very soft ripple overlay — visible only when playing.
      if (isPlaying && totalWidth > 0) {
        final wavePaint = Paint()
          ..color = activeColor.withOpacity(0.30)
          ..style = PaintingStyle.fill;

        final segW = (size.width - playheadX) / _segments;
        final path = Path();
        final halfAmp = _trackH * _waveAmp;

        for (var i = 0; i <= _segments; i++) {
          final x = playheadX + i * segW;
          final relX = (x - playheadX) / size.width;
          final phase =
              relX * 4 * math.pi - animTime * 2 * math.pi * _waveFreq;
          final y = centerY + math.sin(phase) * halfAmp;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        // Close at the bottom of the track.
        path.lineTo(size.width, centerY + r);
        path.lineTo(playheadX, centerY + r);
        path.close();
        canvas.clipRect(
          Rect.fromLTWH(playheadX, centerY - r, size.width - playheadX, _trackH),
        );
        canvas.drawPath(path, wavePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter o) =>
      o.progress != progress ||
      o.animTime != animTime ||
      o.isPlaying != isPlaying ||
      o.activeColor != activeColor ||
      o.trackColor != trackColor;
}
