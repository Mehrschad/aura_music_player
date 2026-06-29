import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/color_scheme.dart';

/// A row of five tappable stars. Tapping star _n_ sets the rating to _n_; tapping
/// the current rating again clears it (passes 0). Read-only when [onRate] is null.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.onRate,
    this.size = 22,
    this.color,
  });

  /// Current rating, 0–5 (0 / null-equivalent shown as all-empty).
  final int rating;
  final ValueChanged<int>? onRate;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = color ?? colors.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: onRate != null,
            label: '$i',
            selected: i <= rating,
            child: GestureDetector(
              onTap: onRate == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      // Tapping the current top star clears the rating.
                      onRate!(i == rating ? 0 : i);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= rating ? active : colors.onSurfaceFaint,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
