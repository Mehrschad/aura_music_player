import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of favourited song ids, persisted to SharedPreferences so a "like"
/// survives leaving and reopening the app.
///
/// Persistence is best-effort: load/save failures (e.g. no platform channel in
/// widget tests) are swallowed so the in-memory toggle always works. Mirrors
/// the [ArtistFavoritesNotifier] / [SongRatingsNotifier] pattern.
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super(const {}) {
    _load();
  }

  static const String _key = 'favorite_songs_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_key);
      if (ids != null && mounted) state = ids.toSet();
    } catch (_) {/* tests / first launch */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.toList());
    } catch (_) {/* tests */}
  }

  bool contains(String songId) => state.contains(songId);

  void toggle(String songId) {
    final next = Set<String>.of(state);
    if (!next.remove(songId)) next.add(songId);
    state = next;
    _save();
  }

  /// Marks every id in [songIds] as favourite (bulk select action).
  void addAll(Iterable<String> songIds) {
    state = {...state, ...songIds};
    _save();
  }

  /// Un-favourites every id in [songIds] (bulk select action).
  void removeAll(Iterable<String> songIds) {
    state = Set<String>.of(state)..removeAll(songIds);
    _save();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier(),
);

/// Whether a specific song is favourited (rebuilds only when *its* membership
/// changes).
final isFavoriteProvider = Provider.family<bool, String>((ref, songId) {
  return ref.watch(favoritesProvider).contains(songId);
});
