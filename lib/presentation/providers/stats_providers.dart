import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/play_event.dart';
import '../../domain/stats/history_timeline.dart';
import '../../domain/stats/stats_logic.dart';

/// The listening history: an append-only, rotated log of [PlayEvent]s persisted
/// to SharedPreferences. Capped at [_maxEvents] (oldest dropped first).
class PlayHistoryNotifier extends StateNotifier<List<PlayEvent>> {
  PlayHistoryNotifier() : super(const []) {
    _load();
  }

  static const String _key = 'play_history_v1';
  static const int _maxEvents = 100000;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(PlayEvent.fromJson)
          .toList();
      if (mounted) state = list;
    } catch (_) {/* tests / first launch */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {/* tests */}
  }

  /// Appends an event, rotating out the oldest beyond the cap.
  void record(PlayEvent event) {
    final next = [...state, event];
    if (next.length > _maxEvents) {
      next.removeRange(0, next.length - _maxEvents);
    }
    state = next;
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  /// Returns this notifier's state as JSON for a backup bundle.
  Object? exportData() => state.map((e) => e.toJson()).toList();

  /// Replaces this notifier's state from a backup payload (best-effort).
  void importData(Object? data) {
    if (data is! List) return;
    try {
      final list =
          data.cast<Map<String, dynamic>>().map(PlayEvent.fromJson).toList();
      if (list.length > _maxEvents) {
        list.removeRange(0, list.length - _maxEvents);
      }
      state = list;
      _save();
    } catch (_) {/* malformed payload */}
  }
}

final playHistoryProvider =
    StateNotifierProvider<PlayHistoryNotifier, List<PlayEvent>>(
  (ref) => PlayHistoryNotifier(),
);

/// The selected stats window.
final statsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.week);

/// Completed plays within the selected period (the basis for every chart).
final periodPlaysProvider = Provider<List<PlayEvent>>((ref) {
  final history = ref.watch(playHistoryProvider);
  final period = ref.watch(statsPeriodProvider);
  return StatsLogic.inPeriod(history, period, DateTime.now());
});

/// The full play history grouped into day buckets for the timeline page.
final listeningHistoryProvider = Provider<List<HistoryDay>>((ref) {
  final history = ref.watch(playHistoryProvider);
  return HistoryTimeline.groupByDay(history);
});
