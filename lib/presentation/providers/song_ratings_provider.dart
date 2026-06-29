import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User star ratings (1–5) keyed by song id, persisted to SharedPreferences.
/// Merged onto the scanned [Song]s by `effectiveSongsProvider`, mirroring the
/// tag-overrides pattern.
class SongRatingsNotifier extends StateNotifier<Map<String, int>> {
  SongRatingsNotifier() : super(const {}) {
    _load();
  }

  static const String _key = 'song_ratings_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final map = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
      if (mounted) state = map;
    } catch (_) {/* tests / first launch */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state));
    } catch (_) {/* tests */}
  }

  int? ratingOf(String songId) => state[songId];

  /// Sets [songId] to [rating] (1–5); a null or 0 rating clears it.
  void setRating(String songId, int? rating) {
    if (rating == null || rating <= 0) {
      if (!state.containsKey(songId)) return;
      state = Map<String, int>.of(state)..remove(songId);
    } else {
      state = {...state, songId: rating.clamp(1, 5)};
    }
    _save();
  }

  /// Applies one rating to many songs (bulk action).
  void setAll(Iterable<String> songIds, int rating) {
    final r = rating.clamp(1, 5);
    state = {...state, for (final id in songIds) id: r};
    _save();
  }

  /// Returns this notifier's state as JSON for a backup bundle.
  Object? exportData() => Map<String, int>.of(state);

  /// Replaces this notifier's state from a backup payload (best-effort).
  void importData(Object? data) {
    if (data is! Map) return;
    final next = <String, int>{};
    data.forEach((k, v) {
      if (k is String && v is int) next[k] = v.clamp(1, 5);
    });
    state = next;
    _save();
  }
}

final songRatingsProvider =
    StateNotifierProvider<SongRatingsNotifier, Map<String, int>>(
  (ref) => SongRatingsNotifier(),
);

/// A single song's rating (rebuilds only when *its* rating changes).
final songRatingProvider = Provider.family<int?, String>((ref, songId) {
  return ref.watch(songRatingsProvider)[songId];
});
