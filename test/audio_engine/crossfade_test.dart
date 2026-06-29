import 'package:aura_music_player/domain/audio/crossfade_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrossfadeLogic', () {
    test('inFadeOut false when crossfadeSeconds is 0', () {
      expect(
        CrossfadeLogic.inFadeOut(
            const Duration(seconds: 58), const Duration(minutes: 1), 0),
        isFalse,
      );
    });

    test('inFadeOut false when outside window', () {
      expect(
        CrossfadeLogic.inFadeOut(
            const Duration(seconds: 50), const Duration(minutes: 1), 5),
        isFalse,
      );
    });

    test('inFadeOut true inside window', () {
      expect(
        CrossfadeLogic.inFadeOut(
            const Duration(seconds: 57), const Duration(minutes: 1), 5),
        isTrue,
      );
    });

    test('fadeOutGain is 1.0 at start of window', () {
      expect(
        CrossfadeLogic.fadeOutGain(const Duration(seconds: 5), 5),
        closeTo(1.0, 0.01),
      );
    });

    test('fadeOutGain is 0.5 at midpoint', () {
      expect(
        CrossfadeLogic.fadeOutGain(const Duration(milliseconds: 2500), 5),
        closeTo(0.5, 0.01),
      );
    });

    test('fadeOutGain is 0.0 at end', () {
      expect(
        CrossfadeLogic.fadeOutGain(Duration.zero, 5),
        closeTo(0.0, 0.01),
      );
    });
  });
}
