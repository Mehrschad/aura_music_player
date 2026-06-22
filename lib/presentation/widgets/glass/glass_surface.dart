import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/glass_theme.dart';

/// A Liquid-Glass surface (iOS 26 style).
///
/// Applied with surgical precision — only the nav bar, mini player, Now Playing
/// overlay, modal sheets, and the queue panel should use this. Beyond a plain
/// frosted blur it layers the optical cues that read as real glass:
///   1. a [BackdropFilter] blur (sigma from [intensity]),
///   2. a faint tint fill ([AppColors.glassTint]),
///   3. a diagonal **specular sheen** (a soft light wash from the top-left),
///   4. a **luminous rim** — a gradient hairline that is bright along the top
///      edge and fades to a soft glow at the bottom, the way light catches the
///      lip of a glass panel.
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sigma = intensity.sigma;
    // At the deepest setting we layer a touch more white over the base tint so
    // the surface reads as thicker frosted crystal rather than just blurrier.
    final tint = intensity.extraTint > 0
        ? Color.alphaBlend(
            Colors.white.withOpacity(intensity.extraTint), colors.glassTint)
        : colors.glassTint;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          // Tint fill — sizes to the content, exactly as the original surface did.
          decoration: BoxDecoration(color: tint),
          child: Stack(
            children: [
              // ── content defines the surface size ──────────────────────────
              Padding(padding: padding, child: child),
              // ── specular sheen: a soft light wash from the top-left with a
              //    faint pickup bottom-right — glassy, not a flat fill ─────────
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(isDark ? 0.14 : 0.30),
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(isDark ? 0.05 : 0.10),
                        ],
                        stops: const [0.0, 0.34, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // ── luminous rim (drawn last so it stays crisp over content) ────
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidRimPainter(
                      borderRadius: borderRadius,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Strokes the surface outline with a top-lit gradient so the edge reads as a
/// catching lip of glass — bright across the top, nearly gone at the sides, and
/// a soft glow along the bottom. The signature optical tell of Liquid Glass.
class _LiquidRimPainter extends CustomPainter {
  const _LiquidRimPainter({required this.borderRadius, required this.isDark});

  final BorderRadius borderRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Inset by half the stroke width so the rim sits fully inside the clip.
    final rrect = RRect.fromRectAndCorners(
      rect.deflate(0.7),
      topLeft: borderRadius.topLeft,
      topRight: borderRadius.topRight,
      bottomLeft: borderRadius.bottomLeft,
      bottomRight: borderRadius.bottomRight,
    );
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(isDark ? 0.55 : 0.85),
        Colors.white.withOpacity(isDark ? 0.06 : 0.10),
        Colors.white.withOpacity(isDark ? 0.12 : 0.22),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_LiquidRimPainter o) =>
      o.borderRadius != borderRadius || o.isDark != isDark;
}
