import '../../domain/lyrics/lrc_parser.dart';
import '../../domain/models/lyrics.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/lyrics_repository.dart';

/// Bundled lyrics for the sample library, so the lyrics view — synced scroll,
/// karaoke word-fill, and the dual-language view — is fully exercisable offline.
/// On device this is replaced by the cache → embedded-tag → LRCLIB chain.
class SampleLyricsRepository implements LyricsRepository {
  const SampleLyricsRepository();

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    switch (song.id) {
      case 's1':
        return _auroraSkyline();
      case 's4':
        return parseLrc(_cinderAndSmoke);
      case 's7':
        return parsePlainLyrics(_glasshousePlain);
      default:
        return null;
    }
  }

  // Word-level (karaoke) LRC, with translations attached for the dual view.
  static Lyrics _auroraSkyline() {
    final base = parseLrc(_auroraLrc);
    const translations = [
      'نور از خط لبریز می‌شود',
      'آسمان رو به محو را دنبال می‌کنیم',
      'تا صبح طاقت بیاور',
      'افق شفق',
    ];
    final lines = [
      for (var i = 0; i < base.lines.length; i++)
        LyricsLine(
          time: base.lines[i].time,
          text: base.lines[i].text,
          words: base.lines[i].words,
          translation: i < translations.length ? translations[i] : null,
        ),
    ];
    return Lyrics(lines: lines, synced: true, offset: base.offset);
  }

  static const _auroraLrc = '''
[offset:0]
[00:01.00]<00:01.00>Light <00:01.40>spills <00:01.90>over <00:02.30>the <00:02.60>line
[00:05.00]<00:05.00>We <00:05.30>chase <00:05.80>the <00:06.10>fading <00:06.70>sky
[00:09.50]<00:09.50>Hold <00:09.90>on <00:10.30>till <00:10.70>morning
[00:14.00]<00:14.00>Aurora <00:14.60>skyline
''';

  static const _cinderAndSmoke = '''
[ar:The Hollow Pines]
[ti:Cinder & Smoke]
[00:00.50]Cinder and smoke
[00:04.00]Drifting through the pines
[00:08.20]A long way down
[00:12.00]We'll find our way back home
[00:16.50]And the embers glow
''';

  static const _glasshousePlain = '''
In a glasshouse
every light shows.
Nothing left to hide,
nowhere left to go.
''';
}
