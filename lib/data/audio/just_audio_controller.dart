import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../domain/audio/audio_controller.dart';
import '../../domain/models/playback.dart';
import '../../domain/models/song.dart';

/// The real, on-device [AudioController], backed by `just_audio` for decoding
/// and `just_audio_background` for the system media session (notification,
/// lock-screen controls, headset/Bluetooth buttons, audio focus).
///
/// To enable on a device:
///   1. `just_audio` and `just_audio_background` are already uncommented in
///      `pubspec.yaml`.
///   2. Initialise the background session **before** `runApp` in `main.dart`:
///      ```dart
///      await JustAudioBackground.init(
///        androidNotificationChannelId: 'com.aura.audio',
///        androidNotificationChannelName: 'Aura playback',
///        androidNotificationOngoing: true,
///      );
///      ```
///   3. Android: declare the service + permission in `AndroidManifest.xml`
///      (see just_audio_background's README — a `MediaSessionService` entry and
///      `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK`). iOS: enable
///      the *Audio, AirPlay, and Picture in Picture* background mode.
///   4. Point `audioControllerProvider` at this class instead of
///      [FakeAudioController].
///
/// Nothing else in the app changes — the UI depends only on [AudioController].
class JustAudioController implements AudioController {
  JustAudioController() {
    _wireStreams();
  }

  final AudioPlayer _player = AudioPlayer();

  final _stateController = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = PlaybackState.empty;

  List<Song> _queue = const [];
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  Stream<PlaybackState> get stateStream async* {
    yield _state;
    yield* _stateController.stream;
  }

  @override
  PlaybackState get state => _state;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Duration get position => _player.position;

  // ── Stream fan-in ───────────────────────────────────────────────────────

  void _wireStreams() {
    // Recompute the snapshot whenever any contributing stream fires.
    _subs.add(_player.playerStateStream.listen((_) => _recompute()));
    _subs.add(_player.currentIndexStream.listen((_) => _recompute()));
    _subs.add(_player.durationStream.listen((_) => _recompute()));
    _subs.add(_player.shuffleModeEnabledStream.listen((_) => _recompute()));
    _subs.add(_player.loopModeStream.listen((_) => _recompute()));
  }

  void _recompute() {
    final ps = _player.playerState;
    final next = PlaybackState(
      queue: _queue,
      currentIndex: _player.currentIndex,
      playing: ps.playing,
      status: _statusFrom(ps.processingState),
      shuffleEnabled: _player.shuffleModeEnabled,
      repeatMode: _repeatFrom(_player.loopMode),
      duration: _player.duration ?? Duration.zero,
    );
    if (next == _state) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  PlaybackStatus _statusFrom(ProcessingState s) => switch (s) {
        ProcessingState.idle => PlaybackStatus.idle,
        ProcessingState.loading => PlaybackStatus.loading,
        ProcessingState.buffering => PlaybackStatus.loading,
        ProcessingState.ready => PlaybackStatus.ready,
        ProcessingState.completed => PlaybackStatus.completed,
      };

  RepeatMode _repeatFrom(LoopMode m) => switch (m) {
        LoopMode.off => RepeatMode.off,
        LoopMode.all => RepeatMode.all,
        LoopMode.one => RepeatMode.one,
      };

  LoopMode _loopFrom(RepeatMode m) => switch (m) {
        RepeatMode.off => LoopMode.off,
        RepeatMode.all => LoopMode.all,
        RepeatMode.one => LoopMode.one,
      };

  // ── Transport ─────────────────────────────────────────────────────────

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue = List<Song>.of(songs);
    final source = ConcatenatingAudioSource(
      children: [for (final s in _queue) _toSource(s)],
    );
    await _player.setAudioSource(
      source,
      initialIndex: songs.isEmpty ? null : startIndex.clamp(0, songs.length - 1),
      initialPosition: Duration.zero,
    );
    _recompute();
    await _player.play();
  }

  /// Wraps a [Song] as a tagged audio source. The [MediaItem] tag is what
  /// `just_audio_background` surfaces in the notification and on the lock
  /// screen.
  AudioSource _toSource(Song song) {
    return AudioSource.uri(
      Uri.file(song.filePath),
      tag: MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        // artUri is populated once the artwork cache (device path) lands.
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> togglePlayPause() =>
      _player.playing ? _player.pause() : _player.play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToIndex(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> setShuffle(bool enabled) async {
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) =>
      _player.setLoopMode(_loopFrom(mode));

  ConcatenatingAudioSource? get _concatenating =>
      _player.audioSource is ConcatenatingAudioSource
          ? _player.audioSource as ConcatenatingAudioSource
          : null;

  @override
  Future<void> playNext(Song song) async {
    final source = _concatenating;
    if (source == null) {
      await playQueue([song]);
      return;
    }
    final at = (_player.currentIndex ?? -1) + 1;
    _queue = List<Song>.of(_queue)..insert(at, song);
    await source.insert(at, _toSource(song));
    _recompute();
  }

  @override
  Future<void> addToQueue(Song song) async {
    final source = _concatenating;
    if (source == null) {
      await playQueue([song]);
      return;
    }
    _queue = List<Song>.of(_queue)..add(song);
    await source.add(_toSource(song));
    _recompute();
  }

  @override
  Future<void> removeFromQueue(int index) async {
    final source = _concatenating;
    if (source == null || index < 0 || index >= _queue.length) return;
    _queue = List<Song>.of(_queue)..removeAt(index);
    await source.removeAt(index);
    _recompute();
  }

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    final source = _concatenating;
    if (source == null || oldIndex < 0 || oldIndex >= _queue.length) return;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex.clamp(0, _queue.length), item);
    await source.move(oldIndex, newIndex);
    _recompute();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _stateController.close();
  }
}
