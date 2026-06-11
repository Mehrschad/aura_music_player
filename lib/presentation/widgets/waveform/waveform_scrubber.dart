import 'dart:math' as math;

import 'package:flutter/material.dart';
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

  // Last fraction actually painted — the start point for a smooth tap-seek glide.
  double _lastFraction = 0;

  late final AnimationController _thumbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _thumbScale = CurvedAnimation(
    parent: _thumbController,
    curve: const Cubic(0.34, 1.56, 0.64, 1.0), // spring
  );

  // Drives the soft glide of the fill when the user taps to seek.
  late final AnimationController _seekController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Animation<double>? _seekAnim;

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
  }

  /// Glides the fill from where it is now to the tapped [target], then commits
  /// the seek — so a tap feels like a smooth scrub rather than a hard jump.
  void _animatedSeekTo(double target) {
    final clamped = target.clamp(0.0, 1.0);
    _seekAnim = Tween<double>(begin: _lastFraction, end: clamped).animate(
      CurvedAnimation(parent: _seekController, curve: Curves.easeOutCubic),
    );
    _thumbController.forward();
    _seekController.forward(from: 0);
  }

  @override
  void dispose() {
    _thumbController.dispose();
    _seekController.dispose();
    super.dispose();
  }

  double get _totalMs => widget.duration.inMilliseconds.toDouble();

  void _seekToFraction(double f) {
    final ms = (f.clamp(0.0, 1.0) * _totalMs).round();
    ref.read(audioControllerProvider).seek(Duration(milliseconds: ms));
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
    if (_dragFraction != null) _seekToFraction(_dragFraction!);
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
                          ? (d) => _animatedSeekTo(d.localPosition.dx / w)
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
                            // The "off" rail: a dim neutral groove the neon fills.
                            trackColor: colors.onSurface.withOpacity(0.10),
                            trackH: 5.0 + 3.0 * _thumbScale.value,
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

/// Draws the dark "off" rail and the neon fill with a soft outer glow.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    this.trackH = 4.0,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double trackH;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final playheadX = progress * size.width;
    final r = trackH / 2;

    // ── 1. The full "off" rail — a dim groove across the whole width ───────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - r, size.width, trackH),
        Radius.circular(r),
      ),
      Paint()..color = trackColor,
    );

    if (playheadX <= 0.5) return;

    final fillRect = Rect.fromLTWH(0, centerY - r, playheadX, trackH);
    final fillRRect = RRect.fromRectAndRadius(fillRect, Radius.circular(r));

    // ── 2. Neon halo — a soft blurred glow bleeding out of the filled part ─
    canvas.drawRRect(
      fillRRect,
      Paint()
        ..color = activeColor.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
    );

    // ── 3. Neon core — bright gradient that lights up the rail ─────────────
    canvas.drawRRect(
      fillRRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            activeColor.withOpacity(0.80),
            Color.lerp(activeColor, Colors.white, 0.25)!,
          ],
        ).createShader(fillRect),
    );

    // ── 4. Inner top highlight — a glassy sheen along the neon's top edge ──
    if (playheadX > r * 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r, centerY - r + 0.5, playheadX - r * 2, trackH * 0.34),
          Radius.circular(r),
        ),
        Paint()..color = Colors.white.withOpacity(0.22),
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter o) =>
      o.progress != progress ||
      o.activeColor != activeColor ||
      o.trackColor != trackColor ||
      o.trackH != trackH;
}
