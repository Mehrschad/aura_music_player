import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

/// Draws the frequency-response curve behind the band sliders: a smooth bezier
/// line through the 10 band gains, a gradient area fill beneath it, a centre
/// 0 dB divider line, and a small dot at each band point.
class EqCurvePainter extends CustomPainter {
  EqCurvePainter({
    required this.gains,
    required this.accent,
    required this.baseline,
  });

  final List<double> gains;
  final Color accent;
  final Color baseline;

  // Horizontal inset so end dots aren't clipped at the edges.
  static const double _pad = 8;

  double _yFor(double gain, double height) {
    final fraction = (gain - kEqMinGain) / (kEqMaxGain - kEqMinGain);
    return height * (1 - fraction);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (gains.isEmpty) return;
    final n = gains.length;

    // Centre 0 dB divider line.
    final mid = _yFor(0, size.height);
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    // Band points across the width (matching the DS x()/y() mapping).
    final inner = size.width - _pad * 2;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(_pad + (i / (n - 1)) * inner, _yFor(gains[i], size.height)),
    ];

    // Smooth bezier line through the points (Catmull-style control offsets).
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < n; i++) {
      final p0 = pts[i - 1];
      final p1 = pts[i];
      final dx = (p1.dx - p0.dx) * 0.4;
      path.cubicTo(p0.dx + dx, p0.dy, p1.dx - dx, p1.dy, p1.dx, p1.dy);
    }

    // Gradient area fill beneath the curve (accent ~0.34 → transparent).
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [accent.withOpacity(0.34), accent.withOpacity(0.0)],
        ),
    );

    // Curve line.
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot at each band point.
    final dot = Paint()..color = accent;
    for (final p in pts) {
      canvas.drawCircle(p, 3, dot);
    }
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
