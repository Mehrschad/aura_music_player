import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/visual_equalizer_controller.dart';
import '../../domain/audio/equalizer_controller.dart';
import '../../domain/audio/equalizer_presets.dart';
import '../../domain/models/equalizer.dart';

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

/// The three user preset slots (null = empty). Session-scoped; persists to
/// shared preferences on device.
final userEqPresetsProvider =
    StateProvider<List<List<double>?>>((ref) => [null, null, null]);

/// The built-in preset matching the current gains, or null ("Custom").
final selectedPresetProvider = Provider<EqPreset?>((ref) {
  final settings = ref.watch(equalizerSettingsProvider).valueOrNull;
  if (settings == null) return EqPreset.flat;
  return matchPreset(settings.gains);
});
