import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of favourited artist ids, persisted to SharedPreferences.
///
/// Persistence is best-effort: load/save failures (e.g. no platform channel
/// in widget tests) are swallowed so the in-memory toggle always works.
class ArtistFavoritesNotifier extends StateNotifier<Set<String>> {
  ArtistFavoritesNotifier() : super(const {}) {
    _load();
  }

  static const String _key = 'favorite_artists_v1';

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

  void toggle(String artistId) {
    final next = Set<String>.of(state);
    if (!next.remove(artistId)) next.add(artistId);
    state = next;
    _save();
  }

  /// Returns this notifier's state as JSON for a backup bundle.
  Object? exportData() => state.toList();

  /// Replaces this notifier's state from a backup payload (best-effort).
  void importData(Object? data) {
    if (data is! List) return;
    state = data.whereType<String>().toSet();
    _save();
  }
}

final artistFavoritesProvider =
    StateNotifierProvider<ArtistFavoritesNotifier, Set<String>>(
  (ref) => ArtistFavoritesNotifier(),
);

/// Whether a specific artist is favourited (rebuilds only when *its*
/// membership changes).
final isArtistFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(artistFavoritesProvider).contains(id);
});
