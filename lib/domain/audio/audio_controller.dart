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
///     audio_service) with gapless queueing and lock-screen /
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

  /// Loads [songs] at [startIndex] and [position] **without auto-playing** —
  /// used on cold start to restore the last session, paused and ready to
  /// resume from exactly where the user left off.
  Future<void> restoreQueue(
    List<Song> songs, {
    int startIndex = 0,
    Duration position = Duration.zero,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> togglePlayPause();

  /// Seeks within the current track.
  Future<void> seek(Duration position);

  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToIndex(int index);

  /// Queue mutations.
  Future<void> playNext(Song song);
  Future<void> addToQueue(Song song);
  Future<void> removeFromQueue(int index);
  Future<void> moveInQueue(int oldIndex, int newIndex);

  Future<void> setShuffle(bool enabled);
  Future<void> setRepeat(RepeatMode mode);

  /// Playback rate. 1.0 = normal speed. Exposed as a stream so the UI
  /// can react without a full provider rebuild.
  Stream<double> get speedStream;
  double get speed;
  Future<void> setSpeed(double speed);

  /// Stops playback and clears the current position (keeps the queue).
  Future<void> stop();

  /// Output volume in [0.0, 1.0]. Separate from the system media volume.
  Stream<double> get volumeStream;
  double get volume;
  Future<void> setVolume(double volume);

  // Pitch shift in semitones. 0.0 = original pitch. Range: -12 to +12.
  Stream<double> get pitchStream;
  double get pitch;
  Future<void> setPitch(double semitones);

  // Automatically skip silent sections.
  Stream<bool> get skipSilenceStream;
  bool get skipSilence;
  Future<void> setSkipSilence(bool enabled);

  Future<void> dispose();
}
