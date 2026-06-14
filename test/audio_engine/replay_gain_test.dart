import 'package:aura_music_player/domain/audio/replay_gain_logic.dart';
import 'package:aura_music_player/domain/models/app_settings.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

// Builds a minimal Song with optional ReplayGain tags.
Song _song({double? trackGain, double? albumGain}) => Song(
      id: 's',
      title: 't',
      artist: 'a',
      album: 'al',
      albumId: 'al',
      artistId: 'ar',
      duration: const Duration(minutes: 3),
      filePath: '/f.mp3',
      dateAdded: DateTime(2024),
      trackGain: trackGain,
      albumGain: albumGain,
    );

void main() {
  group('ReplayGainLogic', () {
    test('off mode returns 1.0 (no adjustment)', () {
      expect(
        ReplayGainLogic.gainFor(_song(trackGain: -6), ReplayGainMode.off),
        closeTo(1.0, 0.001),
      );
    });

    test('track mode uses trackGain', () {
      // -6 dB → ~0.501
      final gain =
          ReplayGainLogic.gainFor(_song(trackGain: -6.0), ReplayGainMode.track);
      expect(gain, closeTo(0.501, 0.01));
    });

    test('album mode falls back to trackGain when albumGain is null', () {
      final gain =
          ReplayGainLogic.gainFor(_song(trackGain: -3.0), ReplayGainMode.album);
      expect(gain, closeTo(0.708, 0.01));
    });

    test('album mode prefers albumGain', () {
      final gain = ReplayGainLogic.gainFor(
          _song(trackGain: -6.0, albumGain: -3.0), ReplayGainMode.album);
      expect(gain, closeTo(0.708, 0.01));
    });

    test('fallback when no gain tags', () {
      // fallback is -6 dB → ~0.501
      final gain =
          ReplayGainLogic.gainFor(_song(), ReplayGainMode.track);
      expect(gain, closeTo(0.501, 0.01));
    });

    test('clamps extreme gains', () {
      // +100 dB clamped to +6 dB
      final gain = ReplayGainLogic.gainFor(
          _song(trackGain: 100.0), ReplayGainMode.track);
      expect(gain, closeTo(ReplayGainLogic.dbToLinear(6.0), 0.001));
    });

    test('dbToLinear and linearToDb are inverse', () {
      const db = -3.0;
      expect(
        ReplayGainLogic.linearToDb(ReplayGainLogic.dbToLinear(db)),
        closeTo(db, 0.001),
      );
    });
  });
}
