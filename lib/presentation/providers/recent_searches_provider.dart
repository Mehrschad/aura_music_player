import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted, capped, de-duplicated list of recent search terms (most-recent
/// first). Best-effort persistence, mirroring SongRatingsNotifier.
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super(const []) {
    _load();
  }

  static const String _key = 'recent_searches_v1';
  static const int _maxEntries = 10;

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).cast<String>();
      if (mounted) state = list;
    } catch (_) {/* tests / first launch */}
  }

  /// Records [term] at the front, de-duplicated (case-insensitive) and capped.
  void record(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final lower = t.toLowerCase();
    final next = [t, ...state.where((e) => e.toLowerCase() != lower)];
    state = next.length > _maxEntries ? next.sublist(0, _maxEntries) : next;
    _save();
  }

  void remove(String term) {
    state = state.where((e) => e != term).toList();
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  void _save() {
    SharedPreferences.getInstance().then((p) {
      try {
        p.setString(_key, jsonEncode(state));
      } catch (_) {/* tests */}
    });
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
  (ref) => RecentSearchesNotifier(),
);
