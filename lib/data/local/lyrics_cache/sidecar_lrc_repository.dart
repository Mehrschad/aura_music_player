import 'dart:io';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Reads a sidecar lyrics file sitting next to the audio file — the long-standing
/// convention shared by foobar2000, MusicBee, Poweramp, etc.: `Song.mp3` pairs
/// with `Song.lrc` (synced) or `Song.txt` (plain) in the same folder.
///
/// This is the fastest possible source — local disk, zero network — so the
/// composite checks it first. On Android 11+ scoped storage may deny direct
/// path access for some libraries; every failure simply yields `null` and the
/// resolver moves on, so this can never break lookup.
class SidecarLrcRepository implements LyricsRepository {
  const SidecarLrcRepository();

  /// Extensions tried in order; `.lrc` (synced) is strongly preferred.
  static const List<String> _exts = ['.lrc', '.txt'];

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    final path = song.filePath;
    if (path.isEmpty) return null;
    final dot = path.lastIndexOf('.');
    final stem = dot > 0 ? path.substring(0, dot) : path;

    for (final ext in _exts) {
      try {
        final file = File('$stem$ext');
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) continue;
        final lyrics = await runOffMainThread(parseLyrics, raw);
        if (!lyrics.isEmpty) return lyrics;
      } catch (_) {
        // Unreadable (permissions / encoding) — try the next extension.
      }
    }
    return null;
  }
}
