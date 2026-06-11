import 'dart:async';
import 'dart:math' show log;

import 'package:audio_service/audio_service.dart' as bg;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';

import '../../domain/audio/audio_controller.dart';
import '../../domain/audio/equalizer_controller.dart';
import '../../domain/audio/equalizer_presets.dart' show eqGainAt;
import '../../domain/models/equalizer.dart';
import '../../domain/models/playback.dart';
import '../../domain/models/song.dart';

/// The real, on-device [AudioController], backed by `just_audio` for decoding
/// and `audio_service` for the system media session (notification, lock-screen
/// controls, headset/Bluetooth buttons, audio focus).
///
/// Extends [bg.BaseAudioHandler] so the background service can invoke play/pause/
/// seek from the notification and lock-screen controls. The same instance is also
/// exposed via [AudioController] for UI-layer consumption.
///
/// Audio quality pipeline (Android):
/// - [AndroidEqualizer]: 10-band parametric EQ via Android AudioEffect.
///   Device bands are mapped from our fixed 10-band spec using log-frequency
///   interpolation, so any 5- or 10-band hardware EQ receives accurate gains.
/// - [AndroidLoudnessEnhancer]: boosts perceived loudness by the amount set
///   via the bass-boost control (0–1000 mB → 0–3 dB target gain). This
///   compensates for the Fletcher-Munson loudness curves at low volumes
///   without amplifying peaks.
class JustAudioController extends bg.BaseAudioHandler implements AudioController {
  JustAudioController({EqualizerController? eqController}) {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_androidEq, _loudnessEnhancer],
      ),
    );
    _wireStreams();
    if (eqController != null) _wireEqualizer(eqController);
  }

  // ── Audio effects (Android) ──────────────────────────────────────────────

  final AndroidEqualizer _androidEq = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  AndroidEqualizerParameters? _eqParams;

  // ── Player ───────────────────────────────────────────────────────────────

  late final AudioPlayer _player;

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
    _broadcastServiceState(ps);
  }

  /// Pushes the current state to [audio_service] so the notification and
  /// lock-screen controls stay in sync. Called every time [_recompute] fires.
  void _broadcastServiceState(PlayerState ps) {
    final playing = ps.playing;
    final processing = _processingStateMap[ps.processingState] ??
        bg.AudioProcessingState.idle;

    // Set media item FIRST so the notification always has a title.
    // Use actual decoded duration when available — more accurate than metadata.
    final song = _state.currentSong;
    if (song != null) {
      mediaItem.add(_toMediaItem(song, playerDuration: _player.duration));
    }

    playbackState.add(bg.PlaybackState(
      controls: [
        bg.MediaControl.skipToPrevious,
        playing ? bg.MediaControl.pause : bg.MediaControl.play,
        bg.MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      // Full set of actions so lock screen, AVRCP, and Android Auto all get
      // prev/next/seek/seekForward/seekBackward controls.
      systemActions: const {
        bg.MediaAction.seek,
        bg.MediaAction.seekForward,
        bg.MediaAction.seekBackward,
        bg.MediaAction.skipToNext,
        bg.MediaAction.skipToPrevious,
      },
      processingState: processing,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
      // Wall-clock timestamp so the OS interpolates the seek-bar position in
      // real time without needing a constant stream of position updates.
      updateTime: DateTime.now(),
      shuffleMode: _player.shuffleModeEnabled
          ? bg.AudioServiceShuffleMode.all
          : bg.AudioServiceShuffleMode.none,
      repeatMode: _bgRepeatFrom(_player.loopMode),
    ));
  }

  // ── MediaItem factory ─────────────────────────────────────────────────────

  /// Builds a [bg.MediaItem] for [song], including album artwork URI so the
  /// system notification, lock screen, and Android Auto can all show cover art.
  ///
  /// [artUri] points to MediaStore's pre-extracted album thumbnail
  /// (`content://media/external/audio/albumart/<albumId>`). The system loads
  /// it asynchronously; if no art exists it simply falls back to the app icon.
  bg.MediaItem _toMediaItem(Song song, {Duration? playerDuration}) =>
      bg.MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: playerDuration ?? song.duration,
        artUri: song.hasArtwork
            ? Uri.parse(
                'content://media/external/audio/albumart/${song.albumId}')
            : null,
      );

  bg.AudioServiceRepeatMode _bgRepeatFrom(LoopMode m) => switch (m) {
        LoopMode.off => bg.AudioServiceRepeatMode.none,
        LoopMode.all => bg.AudioServiceRepeatMode.all,
        LoopMode.one => bg.AudioServiceRepeatMode.one,
      };

  static const _processingStateMap = {
    ProcessingState.idle: bg.AudioProcessingState.idle,
    ProcessingState.loading: bg.AudioProcessingState.loading,
    ProcessingState.buffering: bg.AudioProcessingState.buffering,
    ProcessingState.ready: bg.AudioProcessingState.ready,
    ProcessingState.completed: bg.AudioProcessingState.completed,
  };

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

  /// Keeps [BaseAudioHandler.queue] in sync with [_queue] so Android Auto,
  /// WearOS, and lock-screen queue views always reflect the current list.
  void _syncBgQueue() {
    queue.add([for (final s in _queue) _toMediaItem(s)]);
  }

  // ── Equalizer wiring ─────────────────────────────────────────────────────

  /// Subscribes to [eqController] and bridges every [EqualizerSettings] change
  /// to the Android [AndroidEqualizer] and [AndroidLoudnessEnhancer] effects
  /// that live in the [AudioPipeline]. Also re-applies settings each time a
  /// new track reaches [ProcessingState.ready] so a fresh audio session always
  /// gets the correct EQ state.
  void _wireEqualizer(EqualizerController eqController) {
    _subs.add(eqController.settingsStream
        .listen((s) => _applyEqualizerSettings(s)));
    // Re-apply on each new track (new audio session may reset the effect).
    _subs.add(_player.processingStateStream
        .where((s) => s == ProcessingState.ready)
        .listen((_) {
      _eqParams = null; // force re-fetch for the new session
      _applyEqualizerSettings(eqController.settings);
    }));
    // Apply current settings immediately (may be a no-op if idle).
    _applyEqualizerSettings(eqController.settings);
  }

  /// Applies [settings] to the hardware Android EQ and loudness enhancer.
  ///
  /// Device bands are mapped via log-frequency interpolation: given a device
  /// band centred at F Hz, we compute its normalised position on our 10-band
  /// log scale (32 Hz … 16 kHz) and call [eqGainAt] to interpolate the gain.
  /// This works correctly for both 5-band and 10-band hardware EQs.
  Future<void> _applyEqualizerSettings(EqualizerSettings settings) async {
    try {
      await _androidEq.setEnabled(settings.enabled);

      final boostActive = settings.enabled && settings.bassBoost > 0;
      await _loudnessEnhancer.setEnabled(boostActive);

      if (!settings.enabled) return;

      // Map our gains to the device's bands.
      _eqParams ??= await _androidEq.parameters;
      final params = _eqParams!;
      for (final band in params.bands) {
        final t = _freqToNormalized(band.centerFrequency);
        final gainDb = eqGainAt(settings.gains, t)
            .clamp(params.minDecibels, params.maxDecibels);
        await band.setGain(gainDb);
      }

      // LoudnessEnhancer: map 0–1000 mB bass-boost to 0–3 dB perceptual gain.
      if (boostActive) {
        await _loudnessEnhancer
            .setTargetGain(settings.bassBoost / 1000.0 * 3.0);
      }
    } catch (e) {
      // EQ may not be available on emulators or early in startup; safe to skip.
      debugPrint('[Aura] EQ apply skipped: $e');
    }
  }

  /// Maps a frequency (Hz) to normalised position [0, 1] across our 10
  /// log-spaced EQ bands (32 Hz … 16 kHz). Our bands are spaced uniformly on a
  /// log scale so the normalised position maps directly to the band index used
  /// by [eqGainAt].
  double _freqToNormalized(double freqHz) {
    const minFreq = 32.0;
    const maxFreq = 16000.0;
    if (freqHz <= minFreq) return 0.0;
    if (freqHz >= maxFreq) return 1.0;
    return log(freqHz / minFreq) / log(maxFreq / minFreq);
  }

  // ── Transport (AudioController interface) ────────────────────────────────

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue = List<Song>.of(songs);
    _syncBgQueue();

    // Set the media item eagerly so the OS notification can appear immediately
    // when the foreground service starts — before any stream events fire.
    final startIdx = songs.isEmpty ? null : startIndex.clamp(0, songs.length - 1);
    if (startIdx != null) {
      mediaItem.add(_toMediaItem(_queue[startIdx]));
    }

    final source = ConcatenatingAudioSource(
      children: [for (final s in _queue) _toSource(s)],
    );
    await _player.setAudioSource(
      source,
      initialIndex: startIdx,
      initialPosition: Duration.zero,
    );
    _recompute();
    await _player.play();
  }

  /// Wraps a [Song] as a [just_audio] source, tagging it with its [bg.MediaItem]
  /// so audio_service can surface metadata immediately on source transitions.
  ///
  /// ExoPlayer derives the codec from the file's magic bytes, so all formats
  /// natively supported by ExoPlayer — MP3, AAC/M4A, FLAC, WAV/PCM, OGG
  /// Vorbis, Opus, ALAC (M4A container), AIFF — play without extra hints.
  AudioSource _toSource(Song song) => AudioSource.uri(
        Uri.file(song.filePath),
        tag: _toMediaItem(song),
      );

  // ── BaseAudioHandler overrides (called by notification / lock-screen) ────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  /// Seek +10 s (called when the lock screen / notification "fast-forward"
  /// button is pressed — [begin]=true on press, false on release).
  @override
  Future<void> seekForward(bool begin) async {
    if (!begin) return;
    final dur = _player.duration;
    if (dur == null) return;
    final target = _player.position + const Duration(seconds: 10);
    await _player.seek(target > dur ? dur : target);
  }

  /// Seek −10 s (called when the lock screen / notification "rewind" button
  /// is pressed — [begin]=true on press, false on release).
  @override
  Future<void> seekBackward(bool begin) async {
    if (!begin) return;
    final target = _player.position - const Duration(seconds: 10);
    await _player.seek(target.isNegative ? Duration.zero : target);
  }

  /// Skip to a specific item in the queue (used by Android Auto, WearOS,
  /// and some lock-screen implementations).
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> stop() async {
    // Broadcast idle state first so the notification is dismissed cleanly
    // before the player stops emitting stream events.
    playbackState.add(bg.PlaybackState(
      processingState: bg.AudioProcessingState.idle,
      playing: false,
    ));
    await _player.stop();
  }

  /// Called when the user swipes the app from the Recents screen.
  /// We do NOT stop playback here — [stopWithTask="false"] in the manifest
  /// keeps the foreground service running; the user dismisses the
  /// notification to stop playback.
  @override
  Future<void> onTaskRemoved() async {}

  // ── AudioController extras ───────────────────────────────────────────────

  @override
  Future<void> togglePlayPause() =>
      _player.playing ? _player.pause() : _player.play();

  @override
  Future<void> skipToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Stream<double> get speedStream => _player.speedStream;

  @override
  double get speed => _player.speed;

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setShuffle(bool enabled) async {
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
  }

  /// Called by the media notification's repeat button (audio_service API).
  @override
  Future<void> setRepeatMode(bg.AudioServiceRepeatMode repeatMode) =>
      _player.setLoopMode(_loopFromService(repeatMode));

  /// Called by the in-app UI (AudioController API).
  @override
  Future<void> setRepeat(RepeatMode mode) => _player.setLoopMode(_loopFrom(mode));

  LoopMode _loopFromService(bg.AudioServiceRepeatMode m) => switch (m) {
        bg.AudioServiceRepeatMode.none => LoopMode.off,
        bg.AudioServiceRepeatMode.all => LoopMode.all,
        bg.AudioServiceRepeatMode.one => LoopMode.one,
        _ => LoopMode.off,
      };

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
    _syncBgQueue();
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
    _syncBgQueue();
    await source.add(_toSource(song));
    _recompute();
  }

  @override
  Future<void> removeFromQueue(int index) async {
    final source = _concatenating;
    if (source == null || index < 0 || index >= _queue.length) return;
    _queue = List<Song>.of(_queue)..removeAt(index);
    _syncBgQueue();
    await source.removeAt(index);
    _recompute();
  }

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    final source = _concatenating;
    if (source == null || oldIndex < 0 || oldIndex >= _queue.length) return;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex.clamp(0, _queue.length), item);
    _syncBgQueue();
    await source.move(oldIndex, newIndex);
    _recompute();
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _stateController.close();
  }
}
