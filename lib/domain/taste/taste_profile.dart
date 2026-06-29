/// An inferred snapshot of the user's current music taste.
///
/// Built by [TasteEngine] from the listening history (plays *and* skips), the
/// favourites, and the star ratings — all weighted by an exponential time decay
/// so the profile tracks what the user is into *now*, not their lifetime
/// average. Every facet is normalised to roughly [-1, 1]: positive = liked,
/// negative = actively avoided (e.g. repeatedly skipped).
///
/// Pure data — no Flutter, no IO — so it's trivially testable and cacheable.
class TasteProfile {
  const TasteProfile({
    required this.artistAffinity,
    required this.genreAffinity,
    required this.decadeAffinity,
    required this.hourAffinity,
    required this.playCount,
  });

  /// Artist **name** → affinity in [-1, 1].
  final Map<String, double> artistAffinity;

  /// Genre → affinity in [-1, 1].
  final Map<String, double> genreAffinity;

  /// Decade (e.g. 1990) → affinity in [-1, 1].
  final Map<int, double> decadeAffinity;

  /// Listening intensity by hour-of-day (length 24, normalised 0..1) — the
  /// context signal behind time-aware recommendations.
  final List<double> hourAffinity;

  /// Number of completed plays that fed the profile.
  final int playCount;

  bool get isEmpty => playCount == 0 && artistAffinity.isEmpty;

  /// Top [n] artists by affinity (positive only), highest first.
  List<MapEntry<String, double>> topArtists([int n = 5]) =>
      _top(artistAffinity, n);

  /// Top [n] genres by affinity (positive only), highest first.
  List<MapEntry<String, double>> topGenres([int n = 5]) =>
      _top(genreAffinity, n);

  static List<MapEntry<String, double>> _top(Map<String, double> m, int n) {
    final entries = m.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).toList();
  }

  static final TasteProfile empty = TasteProfile(
    artistAffinity: const {},
    genreAffinity: const {},
    decadeAffinity: const {},
    hourAffinity: List<double>.filled(24, 0),
    playCount: 0,
  );
}
