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
    required this.onAccent,
    required this.divider,
    required this.glassTint,
    required this.glassBorder,
    required this.scrim,
    required this.danger,
    required this.favorite,
    required this.positive,
    required this.warning,
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

  /// Text / icon colour rendered on an [accent]-filled surface.
  final Color onAccent;

  final Color divider;

  /// Fill colour layered behind a [BackdropFilter] on glass surfaces.
  final Color glassTint;

  /// The 8–12% white inner-highlight border on glass surfaces.
  final Color glassBorder;

  /// Dark overlay used behind blurred album art (lyrics / now-playing).
  final Color scrim;

  /// Semantic colour for destructive actions (delete, clear, remove). The only
  /// place a "red" lives — widgets never reach for `Colors.red*`.
  final Color danger;

  /// The heart — the one warm accent in the product. Liked songs, favourite
  /// artists, and the like-button ripple all use this, never [danger].
  final Color favorite;

  /// Positive / success semantic colour (e.g. scrobble confirmed, rating saved).
  final Color positive;

  /// Warning / caution semantic colour (e.g. slow network, partial match).
  final Color warning;

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
    onAccent: Color(0xFF0A0A0C),
    divider: Color(0xFF1C1C1F),
    glassTint: Color(0x22FFFFFF), // ~13% white for richer glass
    glassBorder: Color(0x2AFFFFFF), // ~16% white inner highlight
    scrim: Color(0xB3000000), // 70% black
    danger: Color(0xFFFF6B6B), // soft coral red, legible on black
    favorite: Color(0xFFE66A6A), // the heart — the one warm accent
    positive: Color(0xFF82D1A9),
    warning: Color(0xFFD1B782),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF141416),
    surfaceElevated: Color(0xFF1E1E22),
    onSurface: Color(0xFFF5F5F7),
    onSurfaceMuted: Color(0xFF9A9AA0),
    onSurfaceFaint: Color(0xFF6A6A70),
    accent: Color(0xFFE6E6EA),
    onAccent: Color(0xFF0A0A0C),
    divider: Color(0xFF222226),
    glassTint: Color(0x22FFFFFF),
    glassBorder: Color(0x2AFFFFFF),
    scrim: Color(0xB3000000),
    danger: Color(0xFFFF6B6B),
    favorite: Color(0xFFE66A6A),
    positive: Color(0xFF82D1A9),
    warning: Color(0xFFD1B782),
  );

  // Reworked airy paper-white system: page steps DOWN from white cards, glass
  // uses a white frost tint with a hairline dark border, text is a true
  // near-black ladder for AA+ contrast.
  static const AppColors light = AppColors(
    background: Color(0xFFF4F4F7), // soft paper, never pure white
    surface: Color(0xFFFFFFFF), // cards / rows sit above the page
    surfaceElevated: Color(0xFFFFFFFF),
    onSurface: Color(0xFF15151A),
    onSurfaceMuted: Color(0xFF5A5A66),
    onSurfaceFaint: Color(0xFF9494A0),
    accent: Color(0xFF16161B),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFE7E7ED), // visible hairline
    glassTint: Color(0x9EFFFFFF), // 62% white frost
    glassBorder: Color(0x1414141C), // dark hairline, shows on white
    scrim: Color(0x73FFFFFF), // 45% white over blurred art
    danger: Color(0xFFD93A3A), // deeper red for contrast on white
    favorite: Color(0xFFE0466A), // deeper rose for contrast on white
    positive: Color(0xFF1F9A6B), // re-tuned darker/richer for light ground
    warning: Color(0xFFB5772A), // re-tuned darker/richer for light ground
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
    Color? onAccent,
    Color? divider,
    Color? glassTint,
    Color? glassBorder,
    Color? scrim,
    Color? danger,
    Color? favorite,
    Color? positive,
    Color? warning,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      divider: divider ?? this.divider,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      scrim: scrim ?? this.scrim,
      danger: danger ?? this.danger,
      favorite: favorite ?? this.favorite,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
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
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.onSurface`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
