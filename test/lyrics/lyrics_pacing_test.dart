import 'package:aura_music_player/domain/lyrics/lyrics_pacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimatedLineIndex', () {
    const total = Duration(minutes: 3); // 180s

    test('returns -1 when there is nothing to pace', () {
      expect(estimatedLineIndex(0, Duration.zero, total), -1);
      expect(estimatedLineIndex(10, Duration.zero, Duration.zero), -1);
    });

    test('a single line is always the focused one', () {
      expect(estimatedLineIndex(1, const Duration(seconds: 90), total), 0);
    });

    test('holds the first line through the lead-in', () {
      expect(estimatedLineIndex(20, Duration.zero, total), 0);
      // 6% of 180s = 10.8s — still the first line just before it.
      expect(estimatedLineIndex(20, const Duration(seconds: 10), total), 0);
    });

    test('holds the last line through the tail-out', () {
      final last = estimatedLineIndex(20, total, total);
      expect(last, 19);
      expect(estimatedLineIndex(20, const Duration(seconds: 175), total), 19);
    });

    test('walks forward monotonically across the track', () {
      var previous = -1;
      for (var s = 0; s <= 180; s += 5) {
        final i = estimatedLineIndex(20, Duration(seconds: s), total);
        expect(i, greaterThanOrEqualTo(previous));
        previous = i;
      }
      expect(previous, 19);
    });

    test('lands mid-sheet at the halfway point', () {
      // Halfway through the track is halfway through the lyric window.
      expect(estimatedLineIndex(21, const Duration(seconds: 90), total), 10);
    });
  });

  group('estimatedLineStart', () {
    const total = Duration(minutes: 3);

    test('round-trips back to the same line', () {
      for (final index in [0, 5, 13, 19]) {
        final at = estimatedLineStart(index, 20, total);
        expect(estimatedLineIndex(20, at, total), index);
      }
    });

    test('degenerate inputs seek to the start', () {
      expect(estimatedLineStart(0, 1, total), Duration.zero);
      expect(estimatedLineStart(3, 10, Duration.zero), Duration.zero);
    });

    test('stays inside the track', () {
      final last = estimatedLineStart(19, 20, total);
      expect(last, lessThan(total));
      expect(last, greaterThan(Duration.zero));
    });
  });
}
