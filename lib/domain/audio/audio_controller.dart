import '../models/playback.dart';
import '../models/song.dart';

/// The contract the UI and providers depend on for playback. Two backends
/// implement it (mirroring the library's repository pattern):
///
///   • [FakeAudioController] — a pure-Dart engine that simulates playback with
///     a timer-driven position. Active in development and tests, it lets the
///     mini player, controls, queue advance, shuffle and repeat all be
///     exercised on any platform with no audio hardware or native setup.
///   • [JustAudioController] — the real engine (just_audio +
///     just_audio_background) with gapless queueing and lock-screen /
///     notification controls. Drops in by overriding one provider on device.
abstract interface class AudioController {
  /// Infrequent state: current track, queue, playing flag, shuffle, repeat,
  /// duration. Safe to drive whole-player rebuilds from.
  Stream<PlaybackState> get stateStream;

  /// The latest [PlaybackState] synchronously.
  PlaybackState get state;

  /// High-frequency play position — kept separate from [stateStream] so the
  /// scrubber updates without rebuilding the rest of the player.
  Stream<Duration> get positionStream;

  /// The latest position synchronously.
  Duration get position;

  /// Replaces the queue with [songs] and starts playing at [startIndex].
  Future<void> playQueue(List<Song> songs, {int startIndex = 0});

  Future<void> play();
  Future<void> pause();
  Future<void> togglePlayPause();

  /// Seeks within the current track.
  Future<void> seek(Duration position);

  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToIndex(int index);

  Future<void> setShuffle(bool enabled);
  Future<void> setRepeatMode(RepeatMode mode);

  /// Stops playback and clears the current position (keeps the queue).
  Future<void> stop();

  Future<void> dispose();
}
