import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/radius_tokens.dart';
import '../../../core/constants/spacing_tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/extensions/duration_format.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/audio/waveform.dart';
import '../../providers/playback_providers.dart';

/// A waveform seek control: thin vertical bars (2px wide, 1.5px gap), full
/// opacity in the accent colour behind the playhead and 30% opacity ahead.
/// Tap or drag to seek; a time tooltip floats above the thumb while scrubbing.
///
/// Drop-in replacement for the step-4 slider — same `(duration, accent)` seek
/// contract, plus a [seed] so each track draws its own (deterministic) shape.
/// Watches [positionProvider] in isolation so only the bars repaint as playback
/// advances.
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

  static const double _barWidth = 2;
  static const double _barGap = 1.5;
  static const double _barAreaHeight = 44;
  static const double _tooltipSpace = 26;

  @override
  ConsumerState<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends ConsumerState<WaveformScrubber> {
  double? _dragFraction;
  late WaveformData _waveform = generateWaveform(widget.seed);

  @override
  void didUpdateWidget(WaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _waveform = generateWaveform(widget.seed);
    }
  }

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  void _seekToFraction(double fraction) {
    final ms = (fraction.clamp(0.0, 1.0) * _totalMs).round();
    ref.read(audioControllerProvider).seek(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final hasDuration = _totalMs > 0;

    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final playbackFraction =
        hasDuration ? (position.inMilliseconds / _totalMs).clamp(0.0, 1.0) : 0.0;
    final fraction = _dragFraction ?? playbackFraction;
    final tooltipTime =
        Duration(milliseconds: (fraction * _totalMs).round());

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: WaveformScrubber._barAreaHeight + WaveformScrubber._tooltipSpace,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final period =
                  WaveformScrubber._barWidth + WaveformScrubber._barGap;
              final barCount = ((width + WaveformScrubber._barGap) / period)
                  .floor()
                  .clamp(1, 4000);
              final bars = resampleAmplitudes(_waveform.amplitudes, barCount);

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
                          ? (d) => setState(() =>
                              _dragFraction = (d.localPosition.dx / width)
                                  .clamp(0.0, 1.0))
                          : null,
                      onHorizontalDragUpdate: hasDuration
                          ? (d) => setState(() =>
                              _dragFraction = (d.localPosition.dx / width)
                                  .clamp(0.0, 1.0))
                          : null,
                      onHorizontalDragEnd: hasDuration
                          ? (_) {
                              if (_dragFraction != null) {
                                _seekToFraction(_dragFraction!);
                              }
                              setState(() => _dragFraction = null);
                            }
                          : null,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          bars: bars,
                          progress: fraction,
                          activeColor: widget.accent,
                          inactiveColor: widget.accent.withOpacity(0.30),
                          barWidth: WaveformScrubber._barWidth,
                          gap: WaveformScrubber._barGap,
                        ),
                      ),
                    ),
                  ),
                  if (_dragFraction != null)
                    Positioned(
                      bottom: WaveformScrubber._barAreaHeight + 4,
                      left: (fraction * width - 24).clamp(0.0, width - 48),
                      child: _TimeTooltip(time: tooltipTime),
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
                Duration(milliseconds: (playbackFraction * _totalMs).round())
                    .clock,
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

class _TimeTooltip extends StatelessWidget {
  const _TimeTooltip({required this.time});
  final Duration time;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 48,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: RadiusTokens.brXs,
      ),
      child: Text(
        time.clock,
        style: AppTextTheme.caption.copyWith(color: colors.onSurface),
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
  });

  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final period = barWidth + gap;
    final centerY = size.height / 2;
    final minHeight = barWidth; // never fully collapse a bar
    final radius = Radius.circular(barWidth / 2);
    final playheadX = progress * size.width;

    final active = Paint()..color = activeColor;
    final inactive = Paint()..color = inactiveColor;

    for (var i = 0; i < bars.length; i++) {
      final x = i * period;
      final barHeight = (bars[i] * size.height).clamp(minHeight, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight / 2, barWidth, barHeight),
        radius,
      );
      // A bar is "played" if its centre is left of the playhead.
      final played = (x + barWidth / 2) <= playheadX;
      canvas.drawRRect(rect, played ? active : inactive);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      !identical(old.bars, bars);
}
