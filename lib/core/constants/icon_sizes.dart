/// Icon-size scale for Aura. Every `Icon(size:)` resolves to one of these so
/// glyph sizing stays as disciplined as spacing and radius. Widgets must never
/// inline a raw numeric icon size.
abstract final class IconSizes {
  const IconSizes._();

  /// 14 — inline badge / chip glyphs.
  static const double xs = 14;

  /// 18 — dense list trailing actions.
  static const double sm = 18;

  /// 20 — standard chip / button leading glyph.
  static const double md = 20;

  /// 24 — default app-bar / control icon.
  static const double lg = 24;

  /// 28 — emphasised transport / nav glyphs.
  static const double xl = 28;

  /// 40 — empty-state / placeholder icons.
  static const double huge = 40;

  /// 48 — large hero placeholder glyphs.
  static const double giant = 48;
}
