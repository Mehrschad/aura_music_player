import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The set of favourited song ids.
///
/// Session-scoped for now via a plain [StateNotifier]; build step 6 (playlists)
/// persists this to Isar and exposes a "Favorites" auto-playlist. The UI only
/// ever calls [FavoritesNotifier.toggle] / reads membership, so swapping the
/// backing store is invisible to it.
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super(const {});

  bool contains(String songId) => state.contains(songId);

  void toggle(String songId) {
    final next = Set<String>.of(state);
    if (!next.remove(songId)) next.add(songId);
    state = next;
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
