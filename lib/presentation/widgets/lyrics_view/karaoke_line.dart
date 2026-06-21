import 'package:flutter/material.dart';

import '../../../core/constants/aurora_colors.dart';
import '../../../domain/models/lyrics.dart';

/// Renders a word-timed lyric line with a left-to-right karaoke fill: the line
/// is drawn dimmed in [base] colour, and an aurora-gradient copy is clipped to
/// the portion sung so far, computed from the word timings and the current
/// [position].
///
/// Fill is by character proportion across the words (completed words plus the
/// time-interpolated fraction of the word currently being sung), which tracks
/// the singing closely without needing per-glyph measurement. RTL lines fill
/// from the right.
class KaraokeLine extends StatelessWidget {
  const KaraokeLine({
    super.key,
    required this.words,
    required this.lineEnd,
    required this.position,
    required this.style,
    required this.base,
    required this.textDirection,
  });

  final List<LyricWord> words;

  /// End time of the line (start of the next line, or a sensible cap), used to
  /// size the final word's duration.
  final Duration lineEnd;
  final Duration position;
  final TextStyle style;

  /// Dimmed colour for the not-yet-sung base copy of the text.
  final Color base;
  final TextDirection textDirection;

  String get _text => words.map((w) => w.text).join();

  double _fillFraction() {
    if (words.isEmpty) return 0;
    if (position < words.first.start) return 0;
    final total = _text.length;
    if (total == 0) return 0;

    var filledChars = 0.0;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final end = i + 1 < words.length ? words[i + 1].start : lineEnd;
      if (position >= end) {
        filledChars += w.text.length;
      } else if (position >= w.start) {
        final span = (end - w.start).inMilliseconds;
        final progress =
            span <= 0 ? 1.0 : (position - w.start).inMilliseconds / span;
        filledChars += w.text.length * progress.clamp(0.0, 1.0);
        break;
      } else {
        break;
      }
    }
    return (filledChars / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _fillFraction();
    final text = _text;
    return Stack(
      children: [
        // Dimmed base copy of the full line.
        Text(text,
            textAlign: TextAlign.center,
            textDirection: textDirection,
            style: style.copyWith(color: base)),
        // Aurora-gradient copy, clipped to the sung fraction (left→right; RTL
        // fills from the right). srcIn paints the gradient through the glyphs.
        ClipRect(
          clipper: _FractionClipper(fraction, textDirection),
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AuroraColors.gradient.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(text,
                textAlign: TextAlign.center,
                textDirection: textDirection,
                style: style.copyWith(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction, this.direction);

  final double fraction;
  final TextDirection direction;

  @override
  Rect getClip(Size size) {
    final w = size.width * fraction;
    if (direction == TextDirection.rtl) {
      return Rect.fromLTWH(size.width - w, 0, w, size.height);
    }
    return Rect.fromLTWH(0, 0, w, size.height);
  }

  @override
  bool shouldReclip(_FractionClipper old) =>
      old.fraction != fraction || old.direction != direction;
}
