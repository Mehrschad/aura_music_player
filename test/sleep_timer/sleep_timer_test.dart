import 'package:aura_music_player/data/audio/fake_audio_controller.dart';
import 'package:aura_music_player/presentation/providers/playback_providers.dart';
import 'package:aura_music_player/presentation/providers/sleep_timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _makeContainer() {
  final container = ProviderContainer(overrides: [
    audioControllerProvider
        .overrideWith((ref) => FakeAudioController(autoTick: false)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SleepTimerNotifier — countdown', () {
    test('starts as off', () {
      final c = _makeContainer();
      expect(c.read(sleepTimerProvider), isA<SleepTimerOff>());
    });

    test('startCountdown puts timer into countdown mode', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).startCountdown(
            const Duration(minutes: 30),
            fadeSecs: 0,
          );
      final mode = c.read(sleepTimerProvider);
      expect(mode, isA<SleepTimerCountdown>());
      expect((mode as SleepTimerCountdown).remaining,
          const Duration(minutes: 30));
    });

    test('cancel returns to off and restores volume', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).startCountdown(
            const Duration(minutes: 5),
          );
      c.read(sleepTimerProvider.notifier).cancel();
      expect(c.read(sleepTimerProvider), isA<SleepTimerOff>());
      // Volume restored to 1.0 after cancel
      expect(c.read(audioControllerProvider).volume, 1.0);
    });

    test('extend adds 5 minutes to countdown', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).startCountdown(
            const Duration(minutes: 10),
            fadeSecs: 0,
          );
      c.read(sleepTimerProvider.notifier).extend();
      final mode = c.read(sleepTimerProvider) as SleepTimerCountdown;
      expect(mode.remaining, const Duration(minutes: 15));
    });

    test('extend does nothing when timer is off', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).extend();
      expect(c.read(sleepTimerProvider), isA<SleepTimerOff>());
    });
  });

  group('SleepTimerNotifier — track-based modes', () {
    test('startEndOfTrack puts timer into end-of-track mode', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).startEndOfTrack();
      expect(c.read(sleepTimerProvider), isA<SleepTimerEndOfTrack>());
    });

    test('startEndOfNTracks sets correct track count', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).startEndOfNTracks(3);
      final mode = c.read(sleepTimerProvider);
      expect(mode, isA<SleepTimerEndOfNTracks>());
      expect((mode as SleepTimerEndOfNTracks).tracksLeft, 3);
    });

    test('cancel clears track-based mode', () {
      final c = _makeContainer();
      c.read(sleepTimerProvider.notifier).startEndOfNTracks(5);
      c.read(sleepTimerProvider.notifier).cancel();
      expect(c.read(sleepTimerProvider), isA<SleepTimerOff>());
    });
  });
}
