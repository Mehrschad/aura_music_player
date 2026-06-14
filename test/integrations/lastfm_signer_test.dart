import 'package:aura_music_player/domain/integrations/lastfm_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LastFmSigner', () {
    test('produces a 32-char lowercase hex string', () {
      final sig = LastFmSigner.sign({
        'method': 'auth.getToken',
        'api_key': 'b25b959554ed76058ac220b7b2e0a026',
      }, 'test_secret');
      expect(sig.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(sig), isTrue);
    });

    test('sign is deterministic', () {
      final params = <String, String>{
        'method': 'track.scrobble',
        'api_key': 'key123',
        'artist': 'Artist',
        'track': 'Song',
      };
      final sig1 = LastFmSigner.sign(params, 'secret');
      final sig2 = LastFmSigner.sign(params, 'secret');
      expect(sig1, sig2);
    });

    test('different params produce different signatures', () {
      final sig1 = LastFmSigner.sign({'a': '1'}, 'secret');
      final sig2 = LastFmSigner.sign({'a': '2'}, 'secret');
      expect(sig1, isNot(sig2));
    });

    test('known MD5 — empty input → d41d8cd98f00b204e9800998ecf8427e', () {
      // md5('') is the canonical empty-string digest.
      expect(LastFmSigner.sign({}, ''), 'd41d8cd98f00b204e9800998ecf8427e');
    });

    test('known MD5 — "abc" → 900150983cd24fb0d6963f7d28e17f72', () {
      // Verified against RFC 1321 test vector.
      expect(LastFmSigner.sign({}, 'abc'), '900150983cd24fb0d6963f7d28e17f72');
    });
  });
}
