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
    this.level,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassIntensity intensity;
  final EdgeInsetsGeometry padding;

  /// Material role (spec §4.6). When set, the blur sigma comes from the level
  /// scaled by [intensity] (`level.sigmaFor`), instead of the raw intensity
  /// sigma — so an `ultraThin` overlay blurs less than a `regular` nav bar even
  /// at the same global setting. Null preserves the legacy intensity-only blur.
  final GlassLevel? level;

  /// Optional dynamic-colour wash (from the artwork palette) blended over the
  /// neutral glass tint, so a surface can pick up the current track's hue.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (intensity == GlassIntensity.off) {
      final base = colors.surfaceElevated;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tint != null ? Color.alphaBlend(tint!.withOpacity(0.18), base) : base,
          borderRadius: borderRadius,
          border: Border.all(color: colors.divider, width: GlassTokens.borderWidth),
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sigma = level?.sigmaFor(intensity) ?? intensity.sigma;
    // At the deepest setting we layer a touch more white over the base tint so
    // the surface reads as thicker frosted crystal rather than just blurrier.
    var glassTint = intensity.extraTint > 0
        ? Color.alphaBlend(
            Colors.white.withOpacity(intensity.extraTint), colors.glassTint)
        : colors.glassTint;
    // Dynamic-colour wash: pull the surface *softly* toward the artwork hue, so
    // the glass picks up the track's colour the way Liquid Glass tints from the
    // content behind it — present but never enough to drown legibility.
    if (tint != null) {
      glassTint = Color.alphaBlend(tint!.withOpacity(isDark ? 0.11 : 0.10), glassTint);
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            // Tint fill — sizes to the content, exactly as the original surface did.
            decoration: BoxDecoration(color: glassTint),
            child: Stack(
              children: [
                // ── content defines the surface size ──────────────────────────
                Padding(padding: padding, child: child),
                // ── top specular: a crisp bright catch along the upper lip that
                //    fades fast — the signature Liquid-Glass light edge ──────────
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.22 : 0.40),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.30],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── soft diagonal sheen: a gentle light wash from the top-left
                //    with a faint pickup bottom-right — glassy depth, not a fill ─
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.06 : 0.16),
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(isDark ? 0.04 : 0.08),
                          ],
                          stops: const [0.0, 0.32, 0.66, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── luminous lens rim (drawn last so it stays crisp over content)
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
    // Outer luminous rim — bright across the top, nearly gone at the sides, a
    // soft glow along the bottom: light catching the lip of a glass panel.
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(isDark ? 0.58 : 0.85),
        Colors.white.withOpacity(isDark ? 0.05 : 0.10),
        Colors.white.withOpacity(isDark ? 0.14 : 0.22),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = shader,
    );

    // Inner refraction hairline — a faint dark line just inside the lower half
    // of the rim, reading as the lensed *thickness* of the glass (the way the
    // far wall of a water droplet darkens). This is the tell that separates
    // Liquid Glass from a flat frosted panel.
    final inner = RRect.fromRectAndCorners(
      rect.deflate(2.2),
      topLeft: borderRadius.topLeft,
      topRight: borderRadius.topRight,
      bottomLeft: borderRadius.bottomLeft,
      bottomRight: borderRadius.bottomRight,
    );
    final innerShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.black.withOpacity(isDark ? 0.10 : 0.05),
      ],
      stops: const [0.55, 1.0],
    ).createShader(rect);
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = innerShader,
    );
  }

  @override
  bool shouldRepaint(_LiquidRimPainter o) =>
      o.borderRadius != borderRadius || o.isDark != isDark;
}
