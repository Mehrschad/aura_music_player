import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/aurora_colors.dart';
import '../../../core/utils/seed_color.dart';
import '../../providers/cover_palette_provider.dart';
import '../../providers/playback_providers.dart';

/// The app-wide immersive backdrop.
///
/// A deep base with three large, soft, slowly-drifting colour blobs — a living
/// "mesh gradient" in the spirit of Apple Music / iOS 26 immersive mode. The
/// blobs pull their hue from the **currently playing track's cover palette**;
/// with nothing playing they fall back to the Aura aurora ribbon so the app is
/// never a flat black field.
///
/// Crucially this also makes every [GlassSurface] finally read as real frosted
/// glass: the nav bar, mini player and sheets now blur a colourful gradient
/// instead of uniform black, so the Liquid-Glass treatment becomes visible.
///
/// Rendered once at the app root (behind the whole [Navigator]); all scaffolds
/// are transparent so it shows through on every screen.
class AuraAmbientBackground extends ConsumerStatefulWidget {
  const AuraAmbientBackground({super.key});

  @override
  ConsumerState<AuraAmbientBackground> createState() =>
      _AuraAmbientBackgroundState();
}

class _AuraAmbientBackgroundState extends ConsumerState<AuraAmbientBackground>
    with TickerProviderStateMixin {
  // Slow continuous drift of the blob centres.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  // Short cross-fade whenever the track (and therefore the palette) changes.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );

  _BlobColors? _from;
  _BlobColors? _to;

  @override
  void dispose() {
    _drift.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _retarget(_BlobColors next, {required bool animate}) {
    if (_to == next) return;
    _from = _to == null ? next : _resolvedNow();
    _to = next;
    if (animate) {
      _fade.forward(from: 0);
    } else {
      _fade.value = 1;
    }
  }

  _BlobColors _resolvedNow() {
    final from = _from ?? _to!;
    final to = _to!;
    return _BlobColors.lerp(from, to, _fade.value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Current track → cover palette (accent + wash). Null when nothing plays.
    final song = ref.watch(currentSongProvider);
    final palette = song == null
        ? null
        : ref
            .watch(coverPaletteProvider((
              seed: song.artworkSeed,
              hasArtwork: song.hasArtwork,
              artworkId: int.tryParse(song.id),
            )))
            .valueOrNull;

    final target = _BlobColors.resolve(
      palette: palette,
      seed: song?.artworkSeed,
      isDark: isDark,
    );
    _retarget(target, animate: !reduceMotion);

    if (reduceMotion && _drift.isAnimating) _drift.stop();
    if (!reduceMotion && !_drift.isAnimating) _drift.repeat();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _fade]),
        builder: (context, _) {
          final colors = _resolvedNow();
          return CustomPaint(
            painter: _AmbientPainter(
              t: reduceMotion ? 0.18 : _drift.value,
              colors: colors,
              isDark: isDark,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

/// The three blob colours + the base behind them.
@immutable
class _BlobColors {
  const _BlobColors(this.base, this.a, this.b, this.c, this.opacity);

  final Color base;
  final Color a;
  final Color b;
  final Color c;

  /// Master opacity for the blobs (dark grounds carry them stronger).
  final double opacity;

  static _BlobColors resolve({
    required CoverPalette? palette,
    required String? seed,
    required bool isDark,
  }) {
    if (isDark) {
      const deep = Color(0xFF06070C);
      if (palette != null) {
        return _BlobColors(
          deep,
          palette.accent,
          palette.wash,
          Color.lerp(palette.accent, AuroraColors.c3, 0.45)!,
          0.34,
        );
      }
      if (seed != null) {
        return _BlobColors(
          deep,
          SeedPalette.accent(seed),
          SeedPalette.wash(seed),
          AuroraColors.c1,
          0.30,
        );
      }
      // Nothing playing — the Aura aurora ribbon, alive on deep black.
      return const _BlobColors(
        deep,
        AuroraColors.c2,
        AuroraColors.c3,
        AuroraColors.c1,
        0.30,
      );
    }

    // Light: airy paper base with faint pastel blooms.
    const paper = Color(0xFFF1F1F6);
    if (palette != null) {
      return _BlobColors(
        paper,
        palette.accent,
        palette.wash,
        Color.lerp(palette.accent, AuroraColors.c2, 0.4)!,
        0.14,
      );
    }
    return const _BlobColors(
      paper,
      AuroraColors.c2,
      AuroraColors.c4,
      AuroraColors.c1,
      0.12,
    );
  }

  static _BlobColors lerp(_BlobColors x, _BlobColors y, double t) {
    return _BlobColors(
      Color.lerp(x.base, y.base, t)!,
      Color.lerp(x.a, y.a, t)!,
      Color.lerp(x.b, y.b, t)!,
      Color.lerp(x.c, y.c, t)!,
      lerpDouble(x.opacity, y.opacity, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _BlobColors &&
      other.base == base &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(base, a, b, c, opacity);
}

/// Paints the deep base, three drifting radial blobs, and an edge vignette.
class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.t,
    required this.colors,
    required this.isDark,
  });

  /// Drift phase 0..1.
  final double t;
  final _BlobColors colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Base fill — always the full screen.
    canvas.drawRect(rect, Paint()..color = colors.base);

    final tau = 2 * math.pi;
    final r = math.max(w, h);

    // ── Ambient floor: colour lives only in the bottom 55% (spec §2.4) ──────
    // Blobs drift in the lower portion of the screen. A dstIn gradient mask
    // fades them out above the 55%-from-bottom threshold so the top of the
    // screen stays dark/clean and glass surfaces only pick up colour at the
    // bottom — matching the LinearGradient(bottomCenter→topCenter, stops
    // [0.0, 0.22, 0.55]) from the design spec.
    canvas.saveLayer(rect, Paint());

    // Blob A — bottom-left, drifts gently.
    _blob(
      canvas,
      center: Offset(
        w * (0.22 + 0.10 * math.sin(t * tau)),
        h * (0.68 + 0.08 * math.cos(t * tau)),
      ),
      radius: r * 0.80,
      color: colors.a.withOpacity(colors.opacity),
    );
    // Blob B — bottom-right.
    _blob(
      canvas,
      center: Offset(
        w * (0.82 + 0.08 * math.cos(t * tau * 0.8 + 1.3)),
        h * (0.72 + 0.10 * math.sin(t * tau * 0.8 + 1.3)),
      ),
      radius: r * 0.72,
      color: colors.b.withOpacity(colors.opacity * 0.92),
    );
    // Blob C — bottom-center anchor, largest bloom.
    _blob(
      canvas,
      center: Offset(
        w * (0.50 + 0.12 * math.sin(t * tau * 1.2 + 2.6)),
        h * (0.94 + 0.04 * math.cos(t * tau * 1.2 + 2.6)),
      ),
      radius: r * 0.92,
      color: colors.c.withOpacity(colors.opacity * 0.78),
    );

    // Vertical gradient mask: transparent above 40% from top, fades in by 55%.
    // dstIn keeps the layer pixels only where this gradient is opaque.
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0.40, 0.55],
        ).createShader(rect),
    );

    canvas.restore();

    // Edge vignette for depth (dark grounds only).
    if (isDark) {
      final vignette = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.28),
          ],
          stops: const [0.62, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, vignette);
    }
  }

  void _blob(Canvas canvas,
      {required Offset center, required double radius, required Color color}) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AmbientPainter o) =>
      o.t != t || o.colors != colors || o.isDark != isDark;
}
