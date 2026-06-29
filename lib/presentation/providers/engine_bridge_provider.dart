import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/audio/crossfade_logic.dart';
import '../../domain/audio/replay_gain_logic.dart';
import '../../domain/models/app_settings.dart';
import 'playback_providers.dart';
import 'settings_providers.dart';

/// Persists the last-used playback speed across sessions.
class SpeedMemoryNotifier extends StateNotifier<double> {
  SpeedMemoryNotifier() : super(1.0) {
    _load();
  }

  static const _key = 'speed_memory_value';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getDouble(_key) ?? 1.0;
    } catch (_) {}
  }

  /// Saves [speed] to state and persists it.
  void save(double speed) {
    state = speed;
    SharedPreferences.getInstance().then((p) {
      try {
        p.setDouble(_key, speed);
      } catch (_) {}
    });
  }
}

final speedMemoryNotifier = StateNotifierProvider<SpeedMemoryNotifier, double>(
  (ref) => SpeedMemoryNotifier(),
);

/// Watches settings and wires them to the audio engine as a side-effect provider.
final engineBridgeProvider = Provider<void>((ref) {
  final ctrl = ref.watch(audioControllerProvider);
  final settings = ref.watch(settingsProvider);

  // Apply skip-silence and pitch from settings.
  try {
    ctrl.setSkipSilence(settings.skipSilence);
  } catch (_) {}
  try {
    ctrl.setPitch(settings.pitchSemitones);
  } catch (_) {}

  // Apply ReplayGain volume adjustment when a song is loaded.
  final song = ref.watch(currentSongProvider);
  if (song != null && settings.replayGain != ReplayGainMode.off) {
    try {
      final gain = ReplayGainLogic.gainFor(song, settings.replayGain);
      ctrl.setVolume(gain.clamp(0.0, 1.0));
    } catch (_) {}
  }

  // Apply crossfade fade-out when approaching end of track.
  if (settings.crossfadeSeconds > 0) {
    ref.listen(positionProvider, (_, next) {
      try {
        final pos = next.valueOrNull;
        if (pos == null) return;
        final dur = ctrl.state.duration;
        if (CrossfadeLogic.inFadeOut(pos, dur, settings.crossfadeSeconds)) {
          final remaining = dur - pos;
          final gain =
              CrossfadeLogic.fadeOutGain(remaining, settings.crossfadeSeconds);
          ctrl.setVolume(gain);
        }
      } catch (_) {}
    });
  }

  // Persist speed when speed-memory setting is enabled.
  if (settings.speedMemory) {
    ref.listen(speedProvider, (_, next) {
      try {
        final sp = next.valueOrNull;
        if (sp != null) ref.read(speedMemoryNotifier.notifier).save(sp);
      } catch (_) {}
    });
  }
});
