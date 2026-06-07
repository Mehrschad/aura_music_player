import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/fake_audio_controller.dart';
import '../../domain/audio/audio_controller.dart';
import '../../domain/models/playback.dart';
import '../../domain/models/song.dart';

/// The active playback engine.
///
/// [FakeAudioController] for now — fully functional with no native setup. On a
/// real device, override this (here or in `main.dart`'s `ProviderScope`) with
/// `JustAudioController()` after the one-time background-session setup; nothing
/// downstream changes.
final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = FakeAudioController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// The infrequent player snapshot (track, queue, playing, shuffle, repeat).
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final controller = ref.watch(audioControllerProvider);
  // Seed with the synchronous current value so the first frame isn't "loading".
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
