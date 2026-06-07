import 'package:aura_music_player/domain/lyrics/lrc_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLrc', () {
    test('parses timed lines, sorted, ignoring metadata', () {
      const lrc = '''
[ar:Someone]
[ti:A Song]
[00:05.00]second
[00:01.50]first
''';
      final lyrics = parseLrc(lrc);
      expect(lyrics.synced, isTrue);
      expect(lyrics.lines.map((l) => l.text), ['first', 'second']);
      expect(lyrics.lines.first.time, const Duration(seconds: 1, milliseconds: 500));
    });

    test('centiseconds vs milliseconds fractions', () {
      expect(parseLrc('[00:01.50]x').lines.first.time,
          const Duration(milliseconds: 1500));
      expect(parseLrc('[00:01.500]x').lines.first.time,
          const Duration(milliseconds: 1500));
    });

    test('applies the offset tag to all times', () {
      const lrc = '[offset:+500]\n[00:02.00]line';
      expect(parseLrc(lrc).lines.first.time,
          const Duration(milliseconds: 2500));
      expect(parseLrc(lrc).offset, const Duration(milliseconds: 500));
    });

    test('negative offset never produces a negative time', () {
      const lrc = '[offset:-5000]\n[00:02.00]line';
      expect(parseLrc(lrc).lines.first.time, Duration.zero);
    });

    test('multiple timestamps on one line emit one line each', () {
      final lyrics = parseLrc('[00:01.00][00:03.00]repeat');
      expect(lyrics.lines.length, 2);
      expect(lyrics.lines.every((l) => l.text == 'repeat'), isTrue);
    });

    test('parses word-level timings', () {
      final lyrics =
          parseLrc('[00:01.00]<00:01.00>Hey <00:01.50>there');
      final line = lyrics.lines.single;
      expect(line.hasWordTimings, isTrue);
      expect(line.words.map((w) => w.text.trim()), ['Hey', 'there']);
      expect(line.words[1].start, const Duration(milliseconds: 1500));
      expect(line.text, 'Hey there');
    });
  });

  group('parsePlainLyrics', () {
    test('keeps non-empty lines, unsynced', () {
      final lyrics = parsePlainLyrics('one\n\n  two  \n');
      expect(lyrics.synced, isFalse);
      expect(lyrics.lines.map((l) => l.text), ['one', 'two']);
    });
  });

  group('parseLyrics auto-detect', () {
    test('detects LRC vs plain', () {
      expect(parseLyrics('[00:01.00]hi').synced, isTrue);
      expect(parseLyrics('just text').synced, isFalse);
    });
  });

  group('currentLineIndex', () {
    final lyrics = parseLrc('[00:01.00]a\n[00:03.00]b\n[00:05.00]c');
    test('returns -1 before the first line', () {
      expect(currentLineIndex(lyrics.lines, Duration.zero), -1);
    });
    test('finds the active line', () {
      expect(currentLineIndex(lyrics.lines, const Duration(seconds: 3)), 1);
      expect(currentLineIndex(lyrics.lines, const Duration(seconds: 4)), 1);
      expect(currentLineIndex(lyrics.lines, const Duration(seconds: 10)), 2);
    });
  });
}
