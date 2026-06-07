import '../models/playlist.dart';
import '../models/song.dart';

/// Window for the "Recently added" auto-playlist.
const Duration kRecentlyAddedWindow = Duration(days: 30);

/// Derives the songs for an [AutoPlaylist] from the library [songs] (and, for
/// favourites, the [favoriteIds] set). Pure and deterministic.
///
/// [now] is injectable so "recently added" is testable without wall-clock time.
List<Song> autoPlaylistSongs(
  AutoPlaylist type,
  List<Song> songs, {
  required Set<String> favoriteIds,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  switch (type) {
    case AutoPlaylist.recentlyAdded:
      final cutoff = clock.subtract(kRecentlyAddedWindow);
      return [
        for (final s in songs)
          if (s.dateAdded.isAfter(cutoff)) s,
      ]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    case AutoPlaylist.mostPlayed:
      return [
        for (final s in songs)
          if (s.playCount > 0) s,
      ]..sort((a, b) => b.playCount.compareTo(a.playCount));
    case AutoPlaylist.recentlyPlayed:
      return [
        for (final s in songs)
          if (s.lastPlayed != null) s,
      ]..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    case AutoPlaylist.favorites:
      // Preserve library order; only keep favourited tracks.
      return [
        for (final s in songs)
          if (favoriteIds.contains(s.id)) s,
      ];
  }
}

/// Builds the contents of an extended M3U (`.m3u8`) playlist file for [songs].
///
/// Standard format: an `#EXTM3U` header, then per track an `#EXTINF` line with
/// duration (seconds) and "Artist - Title", followed by the file path. Pure, so
/// it's unit-tested; the device export writes this string to a `.m3u8` file via
/// the file picker, while in-app "export" copies it to the clipboard.
String buildM3u8(List<Song> songs) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (final s in songs) {
    buffer
      ..write('#EXTINF:')
      ..write(s.duration.inSeconds)
      ..write(',')
      ..write(s.artist)
      ..write(' - ')
      ..write(s.title)
      ..write('\n')
      ..write(s.filePath)
      ..write('\n');
  }
  return buffer.toString();
}
