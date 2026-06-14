import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/bookmark.dart';

class BookmarksNotifier extends StateNotifier<List<Bookmark>> {
  BookmarksNotifier() : super(const []) {
    _init();
  }

  static const _key = 'aura_bookmarks_v1';

  /// Loads persisted bookmarks. Best-effort: a missing platform channel (widget
  /// tests, first launch) is swallowed so the in-memory list still works.
  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Bookmark.fromJson)
          .toList();
      if (mounted) state = list;
    } catch (_) {/* tests / first launch */}
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    // Prevent duplicate at the same position (within 2 s).
    if (state.any((b) =>
        b.songId == bookmark.songId &&
        (b.positionMs - bookmark.positionMs).abs() < 2000)) {
      return;
    }
    state = [...state, bookmark];
    await _save();
  }

  Future<void> removeBookmark(String songId, int positionMs) async {
    state = state
        .where((b) => !(b.songId == songId && b.positionMs == positionMs))
        .toList();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(state.map((b) => b.toJson()).toList()),
      );
    } catch (_) {/* tests */}
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<Bookmark>>(
  (_) => BookmarksNotifier(),
);

/// All bookmarks for a single song, sorted by position ascending.
final songBookmarksProvider =
    Provider.family<List<Bookmark>, String>((ref, songId) {
  final all = ref.watch(bookmarksProvider);
  return [
    ...all.where((b) => b.songId == songId),
  ]..sort((a, b) => a.positionMs.compareTo(b.positionMs));
});
