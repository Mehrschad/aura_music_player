import '../../../core/utils/background.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';
import 'embedded_lyrics_reader.dart';

/// Exposes [readEmbeddedLyrics] as a [LyricsRepository] so the composite can
/// place in-file lyrics (ID3 USLT / FLAC Vorbis comments) ahead of the network.
/// The byte parsing runs on a background isolate to keep the UI thread free.
class EmbeddedLyricsRepository implements LyricsRepository {
  const EmbeddedLyricsRepository();

  @override
  Future<Lyrics?> lyricsFor(Song song) {
    if (song.filePath.isEmpty) return Future.value(null);
    return runOffMainThread(readEmbeddedLyrics, song.filePath);
  }
}
