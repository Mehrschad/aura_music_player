import '../models/song.dart';
import 'path_utils.dart';

/// Renders a tag-based path/filename pattern for a [Song].
///
/// Supported tokens (case-insensitive):
///   `{artist} {albumartist} {album} {title} {genre} {year}`
///   `{track} {track:02} {disc} {disc:02} {ext}`
///
/// `/` in the pattern denotes a real directory separator; `/` inside a token
/// *value* is sanitised away so a slash in a title can never spawn folders.
///
/// Example:
///   `{albumartist}/{album} ({year})/{track:02} - {title}.{ext}`
/// →  `Radiohead/Kid A (2000)/03 - The National Anthem.flac`
abstract final class RenamePattern {
  const RenamePattern._();

  static final RegExp _token = RegExp(r'\{(\w+)(?::(\d+))?\}');
  // Characters illegal in FAT/exFAT/ext filenames (SD cards are usually FAT).
  static final RegExp _illegal = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Renders [pattern] for [song]. [ext] overrides the file extension (defaults
  /// to the song's current extension).
  static String render(String pattern, Song song, {String? ext}) {
    final extension = (ext ?? PathUtils.extension(song.filePath));

    final replaced = pattern.replaceAllMapped(_token, (m) {
      final key = m.group(1)!.toLowerCase();
      final pad = m.group(2);
      final raw = _value(key, song, extension);
      if (key == 'ext') return raw; // extension stays unsanitised (already safe)
      final padded = (pad != null && _isNumeric(key))
          ? raw.padLeft(int.parse(pad), '0')
          : raw;
      return _sanitize(padded);
    });

    return _collapse(replaced);
  }

  /// Builds a preview of up to [limit] renames for the UI.
  static List<({Song song, String result})> preview(
    List<Song> songs,
    String pattern, {
    int limit = 5,
  }) {
    return [
      for (final s in songs.take(limit))
        (song: s, result: render(pattern, s)),
    ];
  }

  // ── internals ─────────────────────────────────────────────────────────────

  static bool _isNumeric(String key) =>
      key == 'track' || key == 'disc' || key == 'year';

  static String _value(String key, Song song, String ext) {
    switch (key) {
      case 'artist':
        return song.artist;
      case 'albumartist':
        return song.albumArtist?.isNotEmpty == true
            ? song.albumArtist!
            : song.artist;
      case 'album':
        return song.album;
      case 'title':
        return song.title;
      case 'genre':
        return song.genre ?? '';
      case 'year':
        return song.year?.toString() ?? '';
      case 'track':
        return song.trackNumber?.toString() ?? '';
      case 'disc':
        return song.discNumber?.toString() ?? '';
      case 'ext':
        return ext;
      default:
        return '';
    }
  }

  static String _sanitize(String value) {
    final cleaned = value.replaceAll(_illegal, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    // Trim leading/trailing dots so we never produce ".." or hidden segments.
    return cleaned.replaceAll(RegExp(r'^\.+|\.+$'), '').trim();
  }

  /// Drops empty path segments (e.g. a missing `{year}` leaving `()`), collapses
  /// duplicate separators, and trims a leading slash so the result is relative.
  static String _collapse(String path) {
    final parts = path.split(PathUtils.separator);
    final kept = <String>[];
    for (final raw in parts) {
      final seg = raw.trim();
      // An "empty-ish" directory like "()" or "" is dropped, but the final
      // filename segment is always kept even if odd.
      if (seg.isEmpty) continue;
      kept.add(seg);
    }
    return kept.join(PathUtils.separator);
  }
}
