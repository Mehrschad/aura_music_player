import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/audio/visual_equalizer_controller.dart';
import '../../domain/audio/equalizer_controller.dart';
import '../../domain/audio/equalizer_presets.dart';
import '../../domain/models/equalizer.dart';
import '../../domain/models/named_eq_preset.dart';

/// The active equalizer backend. Override with `SystemEqualizerController()` on
/// Android once the bridge is wired.
final equalizerControllerProvider = Provider<EqualizerController>((ref) {
  final controller = VisualEqualizerController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Live equalizer settings. Seeded with the controller's current value so the
/// provider is never in [AsyncLoading] — the EQ page always has initial state.
final equalizerSettingsProvider = StreamProvider<EqualizerSettings>((ref) {
  final controller = ref.watch(equalizerControllerProvider);
  return (() async* {
    yield controller.settings;
    yield* controller.settingsStream;
  })();
});

/// Persisted, named custom EQ presets. Best-effort SharedPreferences storage,
/// mirroring SongRatingsNotifier.
class CustomEqPresetsNotifier extends StateNotifier<List<NamedEqPreset>> {
  CustomEqPresetsNotifier() : super(const []) {
    _load();
  }

  static const String _key = 'custom_eq_presets_v1';
  static const int maxPresets = 20;

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(NamedEqPreset.fromJson)
          .toList();
      if (mounted) state = list;
    } catch (_) {/* tests / first launch */}
  }

  /// Saves [preset]; returns false if the cap is reached.
  bool add(NamedEqPreset preset) {
    if (state.length >= maxPresets) return false;
    state = [...state, preset];
    _save();
    return true;
  }

  void rename(String id, String name) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(name: name) else p,
    ];
    _save();
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
    _save();
  }

  /// Returns this notifier's state as JSON for a backup bundle.
  Object? exportData() => state.map((p) => p.toJson()).toList();

  /// Replaces this notifier's state from a backup payload (best-effort).
  void importData(Object? data) {
    if (data is! List) return;
    try {
      state =
          data.cast<Map<String, dynamic>>().map(NamedEqPreset.fromJson).toList();
      _save();
    } catch (_) {/* malformed payload */}
  }

  void _save() {
    SharedPreferences.getInstance().then((p) {
      try {
        p.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
      } catch (_) {/* tests */}
    });
  }
}

final customEqPresetsProvider =
    StateNotifierProvider<CustomEqPresetsNotifier, List<NamedEqPreset>>(
  (ref) => CustomEqPresetsNotifier(),
);

/// The built-in preset matching the current gains, or null ("Custom").
final selectedPresetProvider = Provider<EqPreset?>((ref) {
  final settings = ref.watch(equalizerSettingsProvider).valueOrNull;
  if (settings == null) return EqPreset.flat;
  return matchPreset(settings.gains);
});
