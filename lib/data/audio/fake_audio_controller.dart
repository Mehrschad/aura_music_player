import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/audio/audio_controller.dart';
import '../../domain/models/playback.dart';
import '../../domain/models/song.dart';

/// A pure-Dart [AudioController] that simulates playback.
///
/// It advances a position counter on a periodic timer while playing, honours
/// shuffle and all three repeat modes, and advances the queue on track
/// completion exactly as a real engine would — so the full player UI is live
/// and controllable with no audio backend.
///
/// Tests construct it with `autoTick: false` and drive time explicitly via
/// [advance], keeping them deterministic and free of real timers.
class FakeAudioController implements AudioController {
  FakeAudioController({bool autoTick = true}) : _autoTick = autoTick;

  final bool _autoTick;

  static const Duration _tick = Duration(milliseconds: 200);

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _speedController = StreamController<double>.broadcast();

  PlaybackState _state = PlaybackState.empty;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  Timer? _timer;

  /// Shuffle order: indices into [_state.queue]. When shuffle is off this is
  /// the identity order. The "play order" the next/prev buttons traverse.
  List<int> _order = const [];

  @override
  Stream<PlaybackState> get stateStream async* {
    // Yield the current synchronous state immediately so StreamProviders that
    // subscribe after playQueue/pause has already been called don't start in
    // the loading state.
    yield _state;
    yield* _stateController.stream;
  }

  @override
  PlaybackState get state => _state;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Duration get position => _position;

  // ── Transport ─────────────────────────────────────────────────────────

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    final queue = List<Song>.of(songs);
    final index = queue.isEmpty ? null : startIndex.clamp(0, queue.length - 1);
    _rebuildOrder(queue.length);
    _setPosition(Duration.zero);
    _emit(_state.copyWithVia(
      queue: queue,
      setIndex: true,
      currentIndex: index,
      playing: queue.isNotEmpty,
      status: queue.isEmpty ? PlaybackStatus.idle : PlaybackStatus.ready,
      duration: index == null ? Duration.zero : queue[index].duration,
    ));
    _syncTimer();
  }

  @override
  Future<void> play() async {
    if (!_state.hasMedia) return;
    _emit(_state.copyWithVia(playing: true, status: PlaybackStatus.ready));
    _syncTimer();
  }

  @override
  Future<void> pause() async {
    _emit(_state.copyWithVia(playing: false));
    _syncTimer();
  }

  @override
  Future<void> togglePlayPause() =>
      _state.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > _state.duration ? _state.duration : position);
    _setPosition(clamped);
  }

  @override
  Future<void> skipToNext() async => _advanceTrack(forward: true, user: true);

  @override
  Future<void> skipToPrevious() async {
    // Match the familiar behaviour: if we're more than 3s in, restart the
    // current track; otherwise step to the previous one.
    if (_position > const Duration(seconds: 3)) {
      _setPosition(Duration.zero);
      return;
    }
    _advanceTrack(forward: false, user: true);
  }

  @override
  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    _setPosition(Duration.zero);
    _emit(_state.copyWithVia(
      setIndex: true,
      currentIndex: index,
      status: PlaybackStatus.ready,
      duration: _state.queue[index].duration,
    ));
    _syncTimer();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _emit(_state.copyWithVia(shuffleEnabled: enabled));
    _rebuildOrder(_state.queue.length);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _emit(_state.copyWithVia(repeatMode: mode));
  }

  @override
  Stream<double> get speedStream async* {
    yield _speed;
    yield* _speedController.stream;
  }

  @override
  double get speed => _speed;

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    if (!_speedController.isClosed) _speedController.add(_speed);
  }
  @override
  Future<void> playNext(Song song) async {
    final current = _state.currentIndex;
    final insertAt = current == null ? 0 : current + 1;
    final queue = List<Song>.of(_state.queue)..insert(insertAt, song);
    _emit(_state.copyWithVia(
      queue: queue,
      setIndex: true,
      currentIndex: current ?? 0,
      duration: _state.hasMedia ? _state.duration : song.duration,
    ));
    _rebuildOrder(queue.length);
  }

  @override
  Future<void> addToQueue(Song song) async {
    final queue = List<Song>.of(_state.queue)..add(song);
    final wasEmpty = _state.currentIndex == null;
    _emit(_state.copyWithVia(
      queue: queue,
      setIndex: wasEmpty,
      currentIndex: wasEmpty ? 0 : _state.currentIndex,
      duration: wasEmpty ? song.duration : _state.duration,
    ));
    _rebuildOrder(queue.length);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    final current = _state.currentIndex;
    if (index < 0 || index >= _state.queue.length) return;
    final queue = List<Song>.of(_state.queue)..removeAt(index);

    if (queue.isEmpty) {
      _setPosition(Duration.zero);
      _emit(_state.copyWithVia(
        queue: queue,
        setIndex: true,
        currentIndex: null,
        playing: false,
        status: PlaybackStatus.idle,
        duration: Duration.zero,
      ));
      _order = const [];
      _syncTimer();
      return;
    }

    int newCurrent;
    Duration? newDuration;
    if (current == null) {
      newCurrent = 0;
    } else if (index < current) {
      newCurrent = current - 1;
    } else if (index > current) {
      newCurrent = current;
    } else {
      // Removed the current track: the next one slides into its place.
      newCurrent = index.clamp(0, queue.length - 1);
      newDuration = queue[newCurrent].duration;
      _setPosition(Duration.zero);
    }

    _emit(_state.copyWithVia(
      queue: queue,
      setIndex: true,
      currentIndex: newCurrent,
      duration: newDuration ?? _state.duration,
    ));
    _rebuildOrder(queue.length);
  }

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _state.queue.length) return;
    final currentSong = _state.currentSong;
    final queue = List<Song>.of(_state.queue);
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex.clamp(0, queue.length), item);

    final newCurrent =
        currentSong == null ? _state.currentIndex : queue.indexOf(currentSong);
    _emit(_state.copyWithVia(
      queue: queue,
      setIndex: true,
      currentIndex: newCurrent,
    ));
    _rebuildOrder(queue.length);
  }

  @override
  Future<void> stop() async {
    _setPosition(Duration.zero);
    _emit(_state.copyWithVia(playing: false, status: PlaybackStatus.idle));
    _syncTimer();
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _stateController.close();
    await _positionController.close();
    await _speedController.close();
  }

  // ── Simulation ────────────────────────────────────────────────────────

  /// Advances simulated time by [delta]. Called by the internal timer; exposed
  /// for deterministic tests (use with `autoTick: false`).
  @visibleForTesting
  void advance(Duration delta) {
    if (!_state.playing || !_state.hasMedia) return;
    final next = _position + delta;
    if (next >= _state.duration) {
      _onTrackComplete();
    } else {
      _setPosition(next);
    }
  }

  void _onTrackComplete() {
    if (_state.repeatMode == RepeatMode.one) {
      _setPosition(Duration.zero);
      return;
    }
    _advanceTrack(forward: true, user: false);
  }

  /// Moves to the next/previous track in the current play [_order]. When a user
  /// explicitly skips we always move; on natural completion at the end of the
  /// queue with repeat off, we stop.
  void _advanceTrack({required bool forward, required bool user}) {
    final current = _state.currentIndex;
    if (current == null || _order.isEmpty) return;

    final pos = _order.indexOf(current);
    if (pos == -1) return;

    var nextPos = forward ? pos + 1 : pos - 1;

    if (nextPos >= _order.length) {
      if (_state.repeatMode == RepeatMode.all) {
        nextPos = 0;
      } else {
        // End of queue, no repeat: stop on the last track.
        _setPosition(_state.duration);
        _emit(_state.copyWithVia(
            playing: false, status: PlaybackStatus.completed));
        _syncTimer();
        return;
      }
    } else if (nextPos < 0) {
      nextPos = _state.repeatMode == RepeatMode.all ? _order.length - 1 : 0;
    }

    final nextIndex = _order[nextPos];
    _setPosition(Duration.zero);
    _emit(_state.copyWithVia(
      setIndex: true,
      currentIndex: nextIndex,
      status: PlaybackStatus.ready,
      duration: _state.queue[nextIndex].duration,
      // A natural advance keeps playing; a user skip preserves play/pause.
      playing: user ? _state.playing : true,
    ));
    _syncTimer();
  }

  void _rebuildOrder(int length) {
    final base = List<int>.generate(length, (i) => i);
    if (_state.shuffleEnabled && length > 1) {
      base.shuffle();
      // Keep the current track at the front of the shuffled order so "next"
      // explores the rest rather than possibly replaying it immediately.
      final current = _state.currentIndex;
      if (current != null) {
        base
          ..remove(current)
          ..insert(0, current);
      }
    }
    _order = base;
  }

  void _setPosition(Duration p) {
    _position = p;
    if (!_positionController.isClosed) _positionController.add(p);
  }

  void _emit(PlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  void _syncTimer() {
    final shouldRun = _autoTick && _state.playing && _state.hasMedia;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(_tick, (_) => advance(_tick));
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }
}

/// Local copy helper for [PlaybackState] that supports clearing
/// [PlaybackState.currentIndex] to null (a plain copyWith can't express
/// "set to null"). [setIndex] opts in to changing the index.
extension on PlaybackState {
  PlaybackState copyWithVia({
    List<Song>? queue,
    bool setIndex = false,
    int? currentIndex,
    bool? playing,
    PlaybackStatus? status,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    Duration? duration,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      currentIndex: setIndex ? currentIndex : this.currentIndex,
      playing: playing ?? this.playing,
      status: status ?? this.status,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      duration: duration ?? this.duration,
    );
  }
}
