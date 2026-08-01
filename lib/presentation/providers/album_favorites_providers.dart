import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of favourited album ids, persisted to SharedPreferences.
///
/// Persistence is best-effort: load/save failures (e.g. no platform channel in
/// widget tests) are swallowed so the in-memory toggle always works. Mirrors
/// [ArtistFavoritesNotifier].
class AlbumFavoritesNotifier extends StateNotifier<Set<String>> {
  AlbumFavoritesNotifier() : super(const {}) {
    _load();
  }

  static const String _key = 'favorite_albums_v1';

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

  void toggle(String albumId) {
    final next = Set<String>.of(state);
    if (!next.remove(albumId)) next.add(albumId);
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

final albumFavoritesProvider =
    StateNotifierProvider<AlbumFavoritesNotifier, Set<String>>(
  (ref) => AlbumFavoritesNotifier(),
);

/// Whether a specific album is favourited (rebuilds only when *its* membership
/// changes).
final isAlbumFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(albumFavoritesProvider).contains(id);
});

/// When true, the Albums list is filtered to favourited albums only. Session
/// scoped — a filter shouldn't outlive the app the way the favourites do.
final albumsFavoritesOnlyProvider = StateProvider<bool>((ref) => false);
