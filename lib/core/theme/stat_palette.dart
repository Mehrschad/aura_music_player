import 'dart:ui';

/// A small vivid palette for the "wrapped"-style listening stats — the brand
/// teal plus complementary hues, tuned to read on the near-black AMOLED
/// surface. The set is CVD-separated (validated worst-adjacent ΔE ≈ 35) so the
/// colour coding stays legible for colour-blind users; used both for the home
/// "Your Week" card and the full statistics page so the two feel like one story.
abstract final class StatHues {
  static const Color teal = Color(0xFF5FC6BC); // brand
  static const Color violet = Color(0xFF9F8CF0);
  static const Color amber = Color(0xFFF2B84B);
  static const Color coral = Color(0xFFF2775B);
  static const Color blue = Color(0xFF5AA6F0);

  /// Fixed categorical order — assign by slot, never cycle past the end.
  static const List<Color> series = [teal, violet, amber, coral, blue];
}
