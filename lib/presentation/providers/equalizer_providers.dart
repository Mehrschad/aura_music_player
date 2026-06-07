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

/// Live equalizer settings.
final equalizerSettingsProvider = StreamProvider<EqualizerSettings>((ref) {
  return ref.watch(equalizerControllerProvider).settingsStream;
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
