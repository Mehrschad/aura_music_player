import 'package:aura_music_player/domain/audio/waveform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateWaveform', () {
    test('is deterministic for a given seed', () {
      final a = generateWaveform('album-1').amplitudes;
      final b = generateWaveform('album-1').amplitudes;
      expect(a, b);
    });

    test('different seeds produce different shapes', () {
      final a = generateWaveform('album-1').amplitudes;
      final b = generateWaveform('album-2').amplitudes;
      expect(a, isNot(b));
    });

    test('all amplitudes are within [0.06, 1.0] at the requested resolution',
        () {
      final amps = generateWaveform('x', resolution: 64).amplitudes;
      expect(amps.length, 64);
      for (final v in amps) {
        expect(v, inInclusiveRange(0.06, 1.0));
      }
    });
  });

  group('resampleAmplitudes', () {
    test('returns exactly the requested bucket count', () {
      final src = List<double>.generate(240, (i) => i / 240);
      expect(resampleAmplitudes(src, 80).length, 80);
      expect(resampleAmplitudes(src, 300).length, 300);
    });

    test('identity when count matches and empty when count is zero', () {
      final src = [0.1, 0.2, 0.3];
      expect(resampleAmplitudes(src, 3), src);
      expect(resampleAmplitudes(src, 0), isEmpty);
      expect(resampleAmplitudes(const [], 10), isEmpty);
    });

    test('downsampling averages buckets', () {
      final src = [0.0, 1.0, 0.0, 1.0];
      final out = resampleAmplitudes(src, 2);
      // Each output bucket spans two inputs averaging to 0.5.
      expect(out, [0.5, 0.5]);
    });
  });
}
