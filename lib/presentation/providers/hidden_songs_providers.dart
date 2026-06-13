import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Soft-hidden song ids — tracks the user has removed from view without
/// deleting the files. Persisted to SharedPreferences so the hide sticks across
/// launches; filtered out of `effectiveSongsProvider`, so hidden tracks vanish
/// from every list at once.
///
/// Persistence is best-effort: load/save failures (e.g. no platform channel in
/// widget tests) are swallowed, leaving an in-memory set that still works.
class HiddenSongsNotifier extends StateNotifier<Set<String>> {
  HiddenSongsNotifier() : super(const {}) {
    _load();
  }

  static const String _key = 'hidden_songs_v1';

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

  /// Hides every id in [ids].
  void hideAll(Iterable<String> ids) {
    state = {...state, ...ids};
    _save();
  }

  /// Un-hides every id in [ids].
  void unhideAll(Iterable<String> ids) {
    final next = Set<String>.of(state)..removeAll(ids);
    state = next;
    _save();
  }

  /// Clears the whole hidden list (Settings → "Show all hidden").
  void clear() {
    state = const {};
    _save();
  }
}

final hiddenSongsProvider =
    StateNotifierProvider<HiddenSongsNotifier, Set<String>>(
  (ref) => HiddenSongsNotifier(),
);
