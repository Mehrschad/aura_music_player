import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/spacing_tokens.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/equalizer.dart';

/// A single vertical EQ band: a track with a draggable thumb mapping the
/// vertical position to a gain in [kEqMinGain, kEqMaxGain], plus a frequency
/// label. Touch or drag anywhere in the column to set the gain.
class BandSlider extends StatelessWidget {
  const BandSlider({
    super.key,
    required this.gain,
    required this.label,
    required this.accent,
    required this.onChanged,
  });

  final double gain;
  final String label;
  final Color accent;
  final ValueChanged<double> onChanged;

  static const double _range = kEqMaxGain - kEqMinGain;

  void _setFromDy(double dy, double height) {
    final fraction = (1 - dy / height).clamp(0.0, 1.0);
    final next = kEqMinGain + fraction * _range;
    // A light tick each time the gain crosses a whole-dB detent — the drag
    // feels notched rather than slippery.
    if (next.round() != gain.round()) HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = ((gain - kEqMinGain) / _range).clamp(0.0, 1.0);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _setFromDy(d.localPosition.dy, h),
                onVerticalDragUpdate: (d) =>
                    _setFromDy(d.localPosition.dy, h),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Track.
                    Container(width: 3, color: colors.divider),
                    // Thumb.
                    Align(
                      alignment: Alignment(0, 1 - 2 * fraction),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: SpacingTokens.xs),
        Text(label,
            style: AppTextTheme.navLabel.copyWith(color: colors.onSurfaceFaint)),
      ],
    );
  }
}
