import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/just_audio_controller.dart';
import '../../domain/audio/audio_controller.dart';
import '../../domain/models/playback.dart';
import '../../domain/models/song.dart';

/// The active playback engine.
///
/// In production this provider is overridden in [main] with the
/// [AudioService]-backed [JustAudioController] so the background service and
/// lock-screen notification stay in sync with UI state. In tests it is
/// overridden with [FakeAudioController] for deterministic simulation.
final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = JustAudioController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// The infrequent player snapshot (track, queue, playing, shuffle, repeat).
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final controller = ref.watch(audioControllerProvider);
  return controller.stateStream;
});

/// The high-frequency play position, on its own stream so the scrubber updates
/// without rebuilding the rest of the player.
final positionProvider = StreamProvider<Duration>((ref) {
  final controller = ref.watch(audioControllerProvider);
  return controller.positionStream;
});

/// The current track, or null. Convenience for widgets that only need the song.
final currentSongProvider = Provider<Song?>((ref) {
  return ref.watch(playbackStateProvider).maybeWhen(
        data: (s) => s.currentSong,
        orElse: () => null,
      );
});

/// Whether a track is loaded (drives mini-player visibility and scroll insets).
final hasMediaProvider = Provider<bool>((ref) {
  return ref.watch(currentSongProvider) != null;
});

/// Current playback speed (1.0 = normal). Kept separate from [playbackStateProvider]
/// so only the speed indicator rebuilds on rate change.
final speedProvider = StreamProvider<double>((ref) {
  return ref.watch(audioControllerProvider).speedStream;
});

/// Output volume (0.0 – 1.0). Driven by [SleepTimerNotifier] during fade-out;
/// also writable by any other UI element that needs to adjust volume.
final volumeProvider = StreamProvider<double>((ref) {
  return ref.watch(audioControllerProvider).volumeStream;
});

/// Current pitch in semitones. 0.0 = original pitch.
final pitchProvider = StreamProvider<double>((ref) {
  return ref.watch(audioControllerProvider).pitchStream;
});

/// Whether skip-silence is active on the engine.
final skipSilenceStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioControllerProvider).skipSilenceStream;
});
