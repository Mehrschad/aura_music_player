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
import '../../../domain/audio/waveform.dart';
import '../../providers/playback_providers.dart';

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

  static const double _barWidth = 2.5;
  static const double _barGap = 1.8;
  static const double _barAreaHeight = 48;
  static const double _tooltipSpace = 28;

  @override
  ConsumerState<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends ConsumerState<WaveformScrubber>
    with SingleTickerProviderStateMixin {
  double? _dragFraction;
  late WaveformData _waveform = generateWaveform(widget.seed);

  // Separate controller just for the thumb spring animation
  late final AnimationController _thumbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _thumbScale = CurvedAnimation(
    parent: _thumbController,
    curve: const Cubic(0.34, 1.56, 0.64, 1.0),
  );

  // Ticker for continuous bar animation
  Ticker? _ticker;
  double _animTime = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (_isPlaying) {
      setState(() => _animTime += 1 / 60);
    }
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
  void didUpdateWidget(WaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _waveform = generateWaveform(widget.seed);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  void _seekToFraction(double fraction) {
    final ms = (fraction.clamp(0.0, 1.0) * _totalMs).round();
    ref.read(audioControllerProvider).seek(Duration(milliseconds: ms));
  }

  void _onDragStart(double localX, double width) {
    setState(() => _dragFraction = (localX / width).clamp(0.0, 1.0));
    _thumbController.forward();
  }

  void _onDragUpdate(double localX, double width) {
    setState(() => _dragFraction = (localX / width).clamp(0.0, 1.0));
  }

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

    final playbackState = ref.watch(playbackStateProvider);
    final playing = playbackState.valueOrNull?.playing ?? false;
    _syncPlaying(playing);

    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final playbackFraction =
        hasDuration ? (position.inMilliseconds / _totalMs).clamp(0.0, 1.0) : 0.0;
    final fraction = _dragFraction ?? playbackFraction;
    final tooltipTime = Duration(milliseconds: (fraction * _totalMs).round());

    return Semantics(
      container: true,
      slider: true,
      label: l10n.a11ySeekBar,
      value: '${(fraction * 100).round()}%',
      increasedValue: hasDuration
          ? '${((fraction + 0.05).clamp(0.0, 1.0) * 100).round()}%'
          : null,
      decreasedValue: hasDuration
          ? '${((fraction - 0.05).clamp(0.0, 1.0) * 100).round()}%'
          : null,
      onIncrease: hasDuration ? () => _seekToFraction(fraction + 0.05) : null,
      onDecrease: hasDuration ? () => _seekToFraction(fraction - 0.05) : null,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: WaveformScrubber._barAreaHeight + WaveformScrubber._tooltipSpace,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final period = WaveformScrubber._barWidth + WaveformScrubber._barGap;
                final barCount = ((width + WaveformScrubber._barGap) / period)
                    .floor()
                    .clamp(1, 4000);
                final bars = resampleAmplitudes(_waveform.amplitudes, barCount);
                final thumbX = fraction * width;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: WaveformScrubber._barAreaHeight,
                      child: GestureDetector(
                        key: const Key('waveform_gesture'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: hasDuration
                            ? (d) => _seekToFraction(d.localPosition.dx / width)
                            : null,
                        onHorizontalDragStart: hasDuration
                            ? (d) => _onDragStart(d.localPosition.dx, width)
                            : null,
                        onHorizontalDragUpdate: hasDuration
                            ? (d) => _onDragUpdate(d.localPosition.dx, width)
                            : null,
                        onHorizontalDragEnd: hasDuration ? (_) => _onDragEnd() : null,
                        child: AnimatedBuilder(
                          animation: _thumbScale,
                          builder: (_, __) => CustomPaint(
                            painter: _WaveformPainter(
                              bars: bars,
                              progress: fraction,
                              activeColor: widget.accent,
                              inactiveColor: widget.accent.withOpacity(0.28),
                              barWidth: WaveformScrubber._barWidth,
                              gap: WaveformScrubber._barGap,
                              thumbScale: _thumbScale.value,
                              thumbX: thumbX,
                              animTime: _animTime,
                              isPlaying: playing,
                              totalWidth: width,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Animated thumb circle
                    AnimatedBuilder(
                      animation: _thumbScale,
                      builder: (_, __) {
                        final baseRadius = 5.0;
                        final maxRadius = 9.0;
                        final radius =
                            baseRadius + (maxRadius - baseRadius) * _thumbScale.value;
                        final thumbTop =
                            (WaveformScrubber._barAreaHeight / 2) - radius;

                        return Positioned(
                          bottom: thumbTop,
                          left: (thumbX - radius).clamp(0.0, math.max(0, width - radius * 2)),
                          child: Container(
                            width: radius * 2,
                            height: radius * 2,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                              boxShadow: _thumbScale.value > 0.01
                                  ? [
                                      BoxShadow(
                                        color: widget.accent
                                            .withOpacity(0.45 * _thumbScale.value),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_dragFraction != null)
                      Positioned(
                        bottom: WaveformScrubber._barAreaHeight + 4,
                        left: (thumbX - 26).clamp(0.0, math.max(0, width - 52)),
                        child: _TimeTooltip(time: tooltipTime, accent: widget.accent),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Duration(
                          milliseconds:
                              (playbackFraction * _totalMs).round())
                      .clock,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurfaceFaint),
                ),
                Text(
                  widget.duration.clock,
                  style: AppTextTheme.caption
                      .copyWith(color: colors.onSurfaceFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTooltip extends StatelessWidget {
  const _TimeTooltip({required this.time, required this.accent});
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
        color: accent.withOpacity(0.15),
        borderRadius: RadiusTokens.brSm,
        border: Border.all(color: accent.withOpacity(0.35), width: 1),
      ),
      child: Text(
        time.clock,
        style: AppTextTheme.caption.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.barWidth,
    required this.gap,
    required this.thumbScale,
    required this.thumbX,
    required this.animTime,
    required this.isPlaying,
    required this.totalWidth,
  });

  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double barWidth;
  final double gap;
  final double thumbScale;
  final double thumbX;
  final double animTime;
  final bool isPlaying;
  final double totalWidth;

  static const double _squeezeRadius = 44.0;
  static const double _waveFreq = 1.6; // Hz
  static const double _waveAmp = 0.26; // fraction of bar height

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final period = barWidth + gap;
    final centerY = size.height / 2;
    final minHeight = barWidth;
    final radius = Radius.circular(barWidth / 2);
    final playheadX = progress * size.width;

    final active = Paint()..color = activeColor;
    final inactive = Paint()..color = inactiveColor;

    for (var i = 0; i < bars.length; i++) {
      final x = i * period;
      final barCenterX = x + barWidth / 2;

      // Traveling sine wave when playing
      double wave = 1.0;
      if (isPlaying && totalWidth > 0) {
        final phase = (x / totalWidth) * 4 * math.pi -
            animTime * 2 * math.pi * _waveFreq;
        wave = 1.0 + _waveAmp * math.sin(phase);
      }

      // Squeeze near thumb when dragging
      final dist = (barCenterX - thumbX).abs();
      final squeeze = thumbScale > 0
          ? 1.0 - thumbScale * 0.42 * math.max(0, 1 - dist / _squeezeRadius)
          : 1.0;

      final rawHeight = (bars[i] * size.height).clamp(minHeight, size.height);
      final barHeight = (rawHeight * wave * squeeze).clamp(minHeight, size.height);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight / 2, barWidth, barHeight),
        radius,
      );
      final played = barCenterX <= playheadX;
      canvas.drawRRect(rect, played ? active : inactive);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.animTime != animTime ||
      old.isPlaying != isPlaying ||
      old.thumbScale != thumbScale ||
      old.thumbX != thumbX ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      !identical(old.bars, bars);
}
