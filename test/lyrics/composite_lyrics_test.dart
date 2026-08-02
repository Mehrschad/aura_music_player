import 'package:aura_music_player/data/repositories/composite_lyrics_repository.dart';
import 'package:aura_music_player/domain/models/lyrics.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/repositories/lyrics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song() => Song(
      id: 's1',
      title: 'Aurora Skyline',
      artist: 'Marlowe',
      album: 'Northern Glass',
      albumId: 'a1',
      artistId: 'ar1',
      duration: const Duration(seconds: 252),
      // No sidecar: the path has no .lrc/.txt neighbour on disk.
      filePath: '/nonexistent/aura-test/s1.flac',
      dateAdded: DateTime(2024),
    );

Lyrics _lyrics({
  required bool synced,
  required double confidence,
  String text = 'a line',
}) =>
    Lyrics(
      lines: [
        LyricsLine(time: Duration.zero, text: text),
        LyricsLine(time: const Duration(seconds: 5), text: '$text 2'),
      ],
      synced: synced,
      confidence: confidence,
    );

/// A source that answers after [delay] with [result].
class _FakeSource implements LyricsRepository {
  _FakeSource(this.result, {this.delay = Duration.zero});

  final Lyrics? result;
  final Duration delay;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

class _FailingSource implements LyricsRepository {
  int calls = 0;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    calls++;
    throw StateError('network down');
  }
}

void main() {
  group('CompositeLyricsRepository result selection', () {
    test('a confident plain result beats a poorly matched synced one',
        () async {
      final repo = CompositeLyricsRepository(
        network: [
          _FakeSource(_lyrics(synced: true, confidence: 0.56, text: 'wrong')),
          _FakeSource(_lyrics(synced: false, confidence: 1.0, text: 'right')),
        ],
      );

      final result = await repo.lyricsFor(_song());

      expect(result, isNotNull);
      expect(result!.lines.first.text, 'right',
          reason: 'showing the wrong song synced is worse than the right song '
              'plain');
    });

    test('a confident synced result still wins over a confident plain one',
        () async {
      final repo = CompositeLyricsRepository(
        network: [
          _FakeSource(_lyrics(synced: false, confidence: 1.0, text: 'plain')),
          _FakeSource(_lyrics(synced: true, confidence: 1.0, text: 'synced')),
        ],
      );

      final result = await repo.lyricsFor(_song());

      expect(result!.lines.first.text, 'synced');
      expect(result.synced, isTrue);
    });

    test('a high-confidence synced hit short-circuits the slow racers',
        () async {
      final repo = CompositeLyricsRepository(
        network: [
          _FakeSource(_lyrics(synced: true, confidence: 1.0, text: 'fast')),
          _FakeSource(
            _lyrics(synced: true, confidence: 1.0, text: 'slow'),
            delay: const Duration(seconds: 30),
          ),
        ],
        timeout: const Duration(seconds: 60),
      );

      final result = await repo
          .lyricsFor(_song())
          .timeout(const Duration(seconds: 5));

      expect(result!.lines.first.text, 'fast');
    });

    test('the fallback tier rescues a track the primary misses', () async {
      final repo = CompositeLyricsRepository(
        network: [_FakeSource(null)],
        fallback: [_FakeSource(_lyrics(synced: false, confidence: 0.62))],
      );

      expect(await repo.lyricsFor(_song()), isNotNull);
    });

    test('a transient failure is retried and reported, not cached as a miss',
        () async {
      final failing = _FailingSource();
      final repo = CompositeLyricsRepository(
        network: [failing],
        maxAttempts: 3,
      );

      final lookup = await repo.lookupWithStatus(_song());

      expect(lookup.lyrics, isNull);
      expect(lookup.hadErrors, isTrue,
          reason: 'an errored lookup must not be recorded as "no lyrics exist"');
      expect(failing.calls, 3);
    });

    test('a clean miss is not retried', () async {
      var calls = 0;
      final counting = _CountingSource(() => calls++);
      final repo = CompositeLyricsRepository(
        network: [counting],
        maxAttempts: 3,
      );

      final lookup = await repo.lookupWithStatus(_song());

      expect(lookup.lyrics, isNull);
      expect(lookup.hadErrors, isFalse);
      expect(calls, 1, reason: 'repeating a confirmed miss just costs latency');
    });
  });
}

class _CountingSource implements LyricsRepository {
  _CountingSource(this.onCall);
  final void Function() onCall;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    onCall();
    return null;
  }
}
