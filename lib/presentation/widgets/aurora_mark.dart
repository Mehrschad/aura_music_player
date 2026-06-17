import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/aurora_colors.dart';

/// The Aura brand mark — 4 concentric aurora-gradient rings radiating
/// from a single point of sound. Used in the library header.
class AuraMark extends StatelessWidget {
  const AuraMark({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        shaderCallback: (bounds) => AuroraColors.gradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: CustomPaint(
          size: Size(size, size),
          painter: _MarkPainter(),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * (3 / 32);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), r * (4 / 32), fill);
    // Concentric rings at decreasing opacity (opacity ≙ alpha in ShaderMask srcIn)
    for (final (factor, opacity) in [
      (11 / 32, 0.92),
      (19 / 32, 0.55),
      (27 / 32, 0.24),
    ]) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * factor,
        ring..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter _) => false;
}
