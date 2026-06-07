import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';

/// A frosted Liquid Glass surface.
///
/// Applied with surgical precision — only the nav bar, mini player, Now Playing
/// overlay, modal sheets, and the queue panel should use this. It composes:
///   1. a [BackdropFilter] blur (sigma from [intensity]),
///   2. a faint tint fill ([AppColors.glassTint]),
///   3. a 1px inner-highlight border ([AppColors.glassBorder]).
///
/// When [intensity] is [GlassIntensity.off] the blur is skipped entirely and
/// the surface falls back to an opaque elevated surface — this is what the
/// "Liquid Glass intensity: Off" setting and `MediaQuery.disableAnimations`
/// accessibility paths render.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.intensity = GlassTokens.defaultIntensity,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassIntensity intensity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (intensity == GlassIntensity.off) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: borderRadius,
          border: Border.all(color: colors.divider, width: GlassTokens.borderWidth),
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    final sigma = intensity.sigma;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: borderRadius,
            border: Border.all(
              color: colors.glassBorder,
              width: GlassTokens.borderWidth,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
