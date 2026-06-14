import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/named_queue.dart';
import '../../domain/models/playback.dart';

/// Persisted registry of named queues (Musicolet-style multi-queue).
///
/// CRUD is pure list manipulation over [state]; persistence is best-effort and
/// degrades gracefully when there is no platform channel (widget tests). A hard
/// cap of [maxQueues] is enforced — create/duplicate no-op past it.
class QueueRegistry extends StateNotifier<List<NamedQueue>> {
  QueueRegistry() : super(const []) {
    _load();
  }

  static const int maxQueues = 20;
  static const String _key = 'named_queues_v1';
  int _seq = 0;

  bool get isFull => state.length >= maxQueues;

  String _newId() => 'q_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(NamedQueue.fromJson)
          .toList();
      if (mounted) state = list;
    } catch (_) {/* tests / first launch */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(state.map((q) => q.toJson()).toList()));
    } catch (_) {/* tests */}
  }

  NamedQueue? byId(String id) {
    for (final q in state) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// Creates a queue from [songIds]. Returns null (and does nothing) at the cap.
  NamedQueue? create(
    String name,
    List<String> songIds, {
    int colorIndex = 0,
    QueueKind kind = QueueKind.normal,
    int currentIndex = 0,
    bool shuffle = false,
    RepeatMode repeatMode = RepeatMode.off,
    int positionMs = 0,
  }) {
    if (isFull) return null;
    final q = NamedQueue(
      id: _newId(),
      name: name.trim().isEmpty ? 'Queue' : name.trim(),
      songIds: List<String>.of(songIds),
      colorIndex: colorIndex,
      kind: kind,
      currentIndex: currentIndex,
      shuffle: shuffle,
      repeatMode: repeatMode,
      positionMs: positionMs,
      lastTouched: DateTime.now(),
    );
    state = [q, ...state];
    _save();
    return q;
  }

  void rename(String id, String name) =>
      _mutate(id, (q) => q.copyWith(name: name.trim()));

  void recolor(String id, int colorIndex) =>
      _mutate(id, (q) => q.copyWith(colorIndex: colorIndex));

  void setKind(String id, QueueKind kind) =>
      _mutate(id, (q) => q.copyWith(kind: kind));

  void delete(String id) {
    state = state.where((q) => q.id != id).toList();
    _save();
  }

  /// Duplicates [id] (new id, "… copy"). No-op at the cap or if [id] is unknown.
  NamedQueue? duplicate(String id) {
    if (isFull) return null;
    final src = byId(id);
    if (src == null) return null;
    final copy = NamedQueue(
      id: _newId(),
      name: '${src.name} copy',
      songIds: List<String>.of(src.songIds),
      currentIndex: src.currentIndex,
      shuffle: src.shuffle,
      repeatMode: src.repeatMode,
      positionMs: src.positionMs,
      colorIndex: src.colorIndex,
      kind: src.kind,
      lastTouched: DateTime.now(),
    );
    final i = state.indexWhere((q) => q.id == id);
    final next = List<NamedQueue>.of(state)..insert(i + 1, copy);
    state = next;
    _save();
    return copy;
  }

  /// Reorders the queues themselves (drawer drag-to-reorder).
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    final next = List<NamedQueue>.of(state);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), item);
    state = next;
    _save();
  }

  /// Reorders songs within a queue.
  void reorderSongs(String id, int oldIndex, int newIndex) {
    _mutate(id, (q) {
      if (oldIndex < 0 || oldIndex >= q.songIds.length) return q;
      final songs = List<String>.of(q.songIds);
      final item = songs.removeAt(oldIndex);
      songs.insert(newIndex.clamp(0, songs.length), item);
      return q.copyWith(songIds: songs);
    });
  }

  /// Writes the live playback cursor back into queue [id] — so switching away
  /// and back resumes exactly where it left off.
  void updateSnapshot(
    String id, {
    int? currentIndex,
    int? positionMs,
    bool? shuffle,
    RepeatMode? repeatMode,
  }) {
    _mutate(
      id,
      (q) => q.copyWith(
        currentIndex: currentIndex,
        positionMs: positionMs,
        shuffle: shuffle,
        repeatMode: repeatMode,
      ),
    );
  }

  /// Bumps play count + last-touched when a queue is made live.
  void markPlayed(String id) => _mutate(
        id,
        (q) => q.copyWith(
          playCount: q.playCount + 1,
          lastTouched: DateTime.now(),
        ),
      );

  void _mutate(String id, NamedQueue Function(NamedQueue) f) {
    var changed = false;
    final next = <NamedQueue>[];
    for (final q in state) {
      if (q.id == id) {
        next.add(f(q));
        changed = true;
      } else {
        next.add(q);
      }
    }
    if (!changed) return;
    state = next;
    _save();
  }
}

final queueRegistryProvider =
    StateNotifierProvider<QueueRegistry, List<NamedQueue>>(
  (ref) => QueueRegistry(),
);

/// The id of the queue currently driving the audio engine, or null.
final activeQueueIdProvider = StateProvider<String?>((ref) => null);
