import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny mutable set-of-ids notifier (session-scoped, mirroring the existing
/// favourites store) used for the discovery preferences below.
class IdSetNotifier extends StateNotifier<Set<String>> {
  IdSetNotifier() : super(const {});

  void add(String id) => state = {...state, id};
  void remove(String id) => state = Set<String>.of(state)..remove(id);
  bool contains(String id) => state.contains(id);
}

/// Whether the home's discovery rails (For You, Your Week, shelves…) are
/// collapsed so the Songs/Albums/Artists/Genres browser sits right under the
/// header. Persisted to SharedPreferences so the choice sticks across restarts;
/// best-effort, matching the app's other persisted stores.
class DiscoveryCollapsedNotifier extends StateNotifier<bool> {
  DiscoveryCollapsedNotifier() : super(false) {
    _load();
  }

  static const String _key = 'discovery_collapsed_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_key);
      if (v != null && mounted) state = v;
    } catch (_) {/* tests / first launch */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, state);
    } catch (_) {/* tests */}
  }

  void toggle() {
    state = !state;
    _save();
  }
}

final discoveryCollapsedProvider =
    StateNotifierProvider<DiscoveryCollapsedNotifier, bool>(
  (ref) => DiscoveryCollapsedNotifier(),
);

/// Smart-collection ids the user has dismissed from the home ("Hide"). Filtered
/// out of [smartCollectionsProvider]. Session-scoped.
final hiddenCollectionsProvider =
    StateNotifierProvider<IdSetNotifier, Set<String>>(
  (ref) => IdSetNotifier(),
);

/// Smart-collection ids the user has pinned to the top of the home. They float
/// into a dedicated "Pinned" rail and are removed from the regular For You rail
/// so they aren't shown twice. Session-scoped.
final pinnedCollectionsProvider =
    StateNotifierProvider<IdSetNotifier, Set<String>>(
  (ref) => IdSetNotifier(),
);

/// Song ids the user marked "Not interested". These are excluded from
/// recommendations and feed a negative signal into the taste profile (their
/// artists are down-weighted), so the engine learns from the rejection.
final notInterestedProvider =
    StateNotifierProvider<IdSetNotifier, Set<String>>(
  (ref) => IdSetNotifier(),
);

