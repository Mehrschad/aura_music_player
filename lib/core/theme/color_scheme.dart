import 'package:flutter/material.dart';

/// Aura's colour palette.
///
/// Widgets read colours from the [AppColors] extension on the active
/// [ThemeData] (see `app_theme.dart`) — never from raw hex. This class only
/// holds the canonical variants and the seed used to build Material's
/// [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceFaint,
    required this.accent,
    required this.divider,
    required this.glassTint,
    required this.glassBorder,
    required this.scrim,
  });

  /// True page background. AMOLED = pure black, dark = near-black, light = white.
  final Color background;

  /// Resting card / row surface.
  final Color surface;

  /// Raised surface (e.g. selected, hovered, or stacked above [surface]).
  final Color surfaceElevated;

  /// Primary text — the song-title hero tier.
  final Color onSurface;

  /// Secondary text — artist · album metadata (400 weight).
  final Color onSurfaceMuted;

  /// Tertiary text — timestamps, captions, disabled (300 weight).
  final Color onSurfaceFaint;

  /// Default accent before dynamic album-art colour takes over.
  final Color accent;

  final Color divider;

  /// Fill colour layered behind a [BackdropFilter] on glass surfaces.
  final Color glassTint;

  /// The 8–12% white inner-highlight border on glass surfaces.
  final Color glassBorder;

  /// Dark overlay used behind blurred album art (lyrics / now-playing).
  final Color scrim;

  // ── Canonical variants ─────────────────────────────────────────────────

  static const Color _seed = Color(0xFF8E8E93);

  /// Seed for the underlying Material [ColorScheme].
  static const Color seed = _seed;

  static const AppColors amoled = AppColors(
    background: Color(0xFF000000),
    surface: Color(0xFF0C0C0E),
    surfaceElevated: Color(0xFF161618),
    onSurface: Color(0xFFF5F5F7),
    onSurfaceMuted: Color(0xFF9A9AA0),
    onSurfaceFaint: Color(0xFF6A6A70),
    accent: Color(0xFFE6E6EA),
    divider: Color(0xFF1C1C1F),
    glassTint: Color(0x22FFFFFF), // ~13% white for richer glass
    glassBorder: Color(0x2AFFFFFF), // ~16% white inner highlight
    scrim: Color(0xB3000000), // 70% black
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF141416),
    surfaceElevated: Color(0xFF1E1E22),
    onSurface: Color(0xFFF5F5F7),
    onSurfaceMuted: Color(0xFF9A9AA0),
    onSurfaceFaint: Color(0xFF6A6A70),
    accent: Color(0xFFE6E6EA),
    divider: Color(0xFF222226),
    glassTint: Color(0x22FFFFFF),
    glassBorder: Color(0x2AFFFFFF),
    scrim: Color(0xB3000000),
  );

  static const AppColors light = AppColors(
    background: Color(0xFFFBFBFD),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F1F4),
    onSurface: Color(0xFF111114),
    onSurfaceMuted: Color(0xFF5A5A60),
    onSurfaceFaint: Color(0xFF8A8A90),
    accent: Color(0xFF1C1C1E),
    divider: Color(0xFFE6E6EA),
    glassTint: Color(0x14000000), // ~8% black tint on light glass
    glassBorder: Color(0x14FFFFFF),
    scrim: Color(0x66FFFFFF),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? onSurfaceFaint,
    Color? accent,
    Color? divider,
    Color? glassTint,
    Color? glassBorder,
    Color? scrim,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      onSurfaceFaint: Color.lerp(onSurfaceFaint, other.onSurfaceFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.onSurface`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
