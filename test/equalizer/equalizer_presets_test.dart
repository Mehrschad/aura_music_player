import 'package:aura_music_player/domain/audio/equalizer_presets.dart';
import 'package:aura_music_player/domain/models/equalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('presets', () {
    test('every preset has one gain per band, within range', () {
      for (final p in EqPreset.values) {
        final g = presetGains(p);
        expect(g.length, kEqBands.length);
        for (final v in g) {
          expect(v, inInclusiveRange(kEqMinGain, kEqMaxGain));
        }
      }
    });

    test('flat is all zero', () {
      expect(presetGains(EqPreset.flat).every((g) => g == 0), isTrue);
    });

    test('matchPreset round-trips and returns null for custom', () {
      expect(matchPreset(presetGains(EqPreset.rock)), EqPreset.rock);
      final custom = List<double>.filled(kEqBands.length, 0)..[0] = 7;
      expect(matchPreset(custom), isNull);
    });
  });

  test('clampGain respects the range', () {
    expect(clampGain(99), kEqMaxGain);
    expect(clampGain(-99), kEqMinGain);
    expect(clampGain(3), 3);
  });

  group('eqGainAt', () {
    final gains = [0.0, 10.0, -10.0]; // 3 points
    test('hits the endpoints', () {
      expect(eqGainAt(gains, 0), 0);
      expect(eqGainAt(gains, 1), -10);
    });
    test('interpolates linearly between points', () {
      expect(eqGainAt(gains, 0.25), closeTo(5, 0.001)); // halfway 0->10
      expect(eqGainAt(gains, 0.5), closeTo(10, 0.001)); // the middle band
    });
  });
}
