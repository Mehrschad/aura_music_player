import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/playback.dart';
import 'playback_providers.dart';

// ── Sleep timer mode (sealed) ────────────────────────────────────────────────

sealed class SleepTimerMode {
  const SleepTimerMode();
  bool get isOff => this is SleepTimerOff;
  bool get isActive => !isOff;
}

/// Timer is off.
class SleepTimerOff extends SleepTimerMode {
  const SleepTimerOff();
}

/// Duration-based countdown. Volume fades during the last [fadeSecs] seconds.
class SleepTimerCountdown extends SleepTimerMode {
  const SleepTimerCountdown({required this.remaining, this.fadeSecs = 10});
  final Duration remaining;
  final int fadeSecs;
}

/// Stops after the current track finishes naturally.
class SleepTimerEndOfTrack extends SleepTimerMode {
  const SleepTimerEndOfTrack();
}

/// Stops after [tracksLeft] more track completions.
class SleepTimerEndOfNTracks extends SleepTimerMode {
  const SleepTimerEndOfNTracks({required this.tracksLeft});
  final int tracksLeft;
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class SleepTimerNotifier extends StateNotifier<SleepTimerMode> {
  SleepTimerNotifier(this._ref) : super(const SleepTimerOff()) {
    _stateSub =
        _ref.read(audioControllerProvider).stateStream.listen(_onPlaybackState);
  }

  final Ref _ref;
  Timer? _ticker;
  int? _lastTrackIndex;
  late final StreamSubscription<PlaybackState> _stateSub;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Starts a countdown timer. Volume fades during the last [fadeSecs] seconds.
  void startCountdown(Duration duration, {int fadeSecs = 10}) {
    _cancelTicker();
    state = SleepTimerCountdown(remaining: duration, fadeSecs: fadeSecs);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Stops playback when the current track ends.
  void startEndOfTrack() {
    _cancelTicker();
    _lastTrackIndex = _ref.read(audioControllerProvider).state.currentIndex;
    state = const SleepTimerEndOfTrack();
  }

  /// Stops playback after [n] more track completions.
  void startEndOfNTracks(int n) {
    _cancelTicker();
    _lastTrackIndex = _ref.read(audioControllerProvider).state.currentIndex;
    state = SleepTimerEndOfNTracks(tracksLeft: n);
  }

  /// Adds 5 minutes to an active countdown (e.g. from the chip quick-action).
  void extend() {
    final s = state;
    if (s is SleepTimerCountdown) {
      state = SleepTimerCountdown(
        remaining: s.remaining + const Duration(minutes: 5),
        fadeSecs: s.fadeSecs,
      );
    }
  }

  void cancel() {
    _cancelTicker();
    state = const SleepTimerOff();
    _ref.read(audioControllerProvider).setVolume(1.0);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _tick() {
    final s = state;
    if (s is! SleepTimerCountdown) return;

    final remaining = s.remaining - const Duration(seconds: 1);
    if (remaining <= Duration.zero) {
      _doStop();
      return;
    }

    state = SleepTimerCountdown(remaining: remaining, fadeSecs: s.fadeSecs);

    // Smooth linear fade during the last fadeSecs seconds.
    final secs = remaining.inSeconds;
    if (s.fadeSecs > 0 && secs <= s.fadeSecs) {
      final vol = (secs / s.fadeSecs).clamp(0.0, 1.0);
      _ref.read(audioControllerProvider).setVolume(vol);
    }
  }

  void _onPlaybackState(PlaybackState ps) {
    final idx = ps.currentIndex;
    if (idx == null || idx == _lastTrackIndex) return;
    _lastTrackIndex = idx;

    switch (state) {
      case SleepTimerEndOfTrack():
        _doStop();
      case SleepTimerEndOfNTracks(:final tracksLeft):
        final remaining = tracksLeft - 1;
        if (remaining <= 0) {
          _doStop();
        } else {
          state = SleepTimerEndOfNTracks(tracksLeft: remaining);
        }
      default:
        break;
    }
  }

  void _doStop() {
    _cancelTicker();
    state = const SleepTimerOff();
    final ctrl = _ref.read(audioControllerProvider);
    ctrl.pause();
    ctrl.setVolume(1.0);
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _cancelTicker();
    _stateSub.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerMode>(
  (ref) => SleepTimerNotifier(ref),
);
