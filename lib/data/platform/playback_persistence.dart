import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/playback.dart';

/// A lightweight snapshot of the last playback session — just enough to restore
/// the queue, the current track, the position, and the shuffle/repeat modes on
/// the next cold start. Songs are stored by id and re-resolved against the
/// freshly-scanned library on restore.
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.songIds,
    required this.index,
    required this.positionMs,
    required this.shuffle,
    required this.repeat,
  });

  final List<String> songIds;
  final int index;
  final int positionMs;
  final bool shuffle;
  final RepeatMode repeat;

  Map<String, dynamic> toJson() => {
        'ids': songIds,
        'index': index,
        'posMs': positionMs,
        'shuffle': shuffle,
        'repeat': repeat.name,
      };

  static PlaybackSnapshot? fromJson(Map<String, dynamic> j) {
    final ids = (j['ids'] as List?)?.cast<String>();
    if (ids == null || ids.isEmpty) return null;
    return PlaybackSnapshot(
      songIds: ids,
      index: (j['index'] as num?)?.toInt() ?? 0,
      positionMs: (j['posMs'] as num?)?.toInt() ?? 0,
      shuffle: j['shuffle'] as bool? ?? false,
      repeat: RepeatMode.values.firstWhere(
        (r) => r.name == j['repeat'],
        orElse: () => RepeatMode.off,
      ),
    );
  }
}

/// Persists the last playback session to [SharedPreferences] so the player can
/// pick up where it left off after the app is fully closed and relaunched.
class PlaybackPersistence {
  PlaybackPersistence(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'last_playback_v1';

  Future<void> save(PlaybackSnapshot snapshot) async {
    try {
      await _prefs.setString(_key, jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('[Aura] playback snapshot save failed: $e');
    }
  }

  Future<void> clear() => _prefs.remove(_key);

  PlaybackSnapshot? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PlaybackSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
