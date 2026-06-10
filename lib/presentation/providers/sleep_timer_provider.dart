import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback_providers.dart';

/// Remaining sleep timer duration, or null when the timer is off.
class SleepTimerNotifier extends StateNotifier<Duration?> {
  SleepTimerNotifier(this._ref) : super(null);

  final Ref _ref;
  Timer? _ticker;

  void start(Duration duration) {
    _ticker?.cancel();
    state = duration;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state;
      if (remaining == null || remaining <= Duration.zero) {
        _ref.read(audioControllerProvider).pause();
        _ticker?.cancel();
        _ticker = null;
        state = null;
        return;
      }
      state = remaining - const Duration(seconds: 1);
    });
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    state = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, Duration?>(
  (ref) => SleepTimerNotifier(ref),
);
