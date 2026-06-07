import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/audio/equalizer_presets.dart';
import '../../../domain/models/equalizer.dart';

/// Tween over a list of band gains, lerped element-wise, so the response curve
/// eases smoothly when a preset is applied (per the spec's `TweenAnimationBuilder`).
class GainsTween extends Tween<List<double>> {
  GainsTween({List<double>? begin, required List<double> end})
      : super(begin: begin, end: end);

  @override
  List<double> lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    final n = b.length;
    return [
      for (var i = 0; i < n; i++)
        (i < a.length ? a[i] : b[i]) + (b[i] - (i < a.length ? a[i] : b[i])) * t,
    ];
  }
}

/// Draws the frequency-response curve: a smooth line through the band gains
/// with a soft gradient fill beneath it and a faint 0 dB baseline.
class EqCurvePainter extends CustomPainter {
  EqCurvePainter({
    required this.gains,
    required this.accent,
    required this.baseline,
  });

  final List<double> gains;
  final Color accent;
  final Color baseline;

  static const int _samples = 72;

  double _yFor(double gain, double height) {
    final fraction = (gain - kEqMinGain) / (kEqMaxGain - kEqMinGain);
    return height * (1 - fraction);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 0 dB baseline.
    final mid = _yFor(0, size.height);
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final path = Path();
    for (var i = 0; i < _samples; i++) {
      final t = i / (_samples - 1);
      final x = t * size.width;
      final y = _yFor(eqGainAt(gains, t), size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill beneath the curve.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [accent.withOpacity(0.30), accent.withOpacity(0.0)],
        ),
    );

    // Curve line.
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(EqCurvePainter old) =>
      old.accent != accent ||
      old.baseline != baseline ||
      !_eq(old.gains, gains);

  bool _eq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
