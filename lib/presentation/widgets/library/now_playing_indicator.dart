import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three slim bars that dance softly — the universal "this row is playing"
/// cue. When [animating] is false (paused) the bars freeze at a resting
/// height; respects the reduce-motion accessibility setting.
class NowPlayingIndicator extends StatefulWidget {
  const NowPlayingIndicator({
    super.key,
    required this.color,
    this.animating = true,
    this.size = 16,
  });

  final Color color;
  final bool animating;
  final double size;

  @override
  State<NowPlayingIndicator> createState() => _NowPlayingIndicatorState();
}

class _NowPlayingIndicatorState extends State<NowPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NowPlayingIndicator old) {
    super.didUpdateWidget(old);
    if (old.animating != widget.animating) _sync();
  }

  void _sync() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.animating && !reduce) {
      _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _BarsPainter(
            t: _ctrl.value,
            color: widget.color,
            resting: !widget.animating,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.t, required this.color, required this.resting});

  final double t;
  final Color color;
  final bool resting;

  // Per-bar phase offsets and speeds so the dance never looks mechanical.
  static const _phases = [0.0, 2.1, 4.2];
  static const _speeds = [1.0, 1.35, 0.8];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.18;

    const n = 3;
    final gap = size.width / n;
    for (var i = 0; i < n; i++) {
      final x = gap * (i + 0.5);
      final wave = resting
          ? 0.35
          : 0.30 +
              0.55 *
                  (0.5 +
                      0.5 *
                          math.sin(
                              2 * math.pi * (_speeds[i] * t) + _phases[i]));
      final h = size.height * wave.clamp(0.15, 1.0);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) =>
      o.t != t || o.color != color || o.resting != resting;
}
