import '../models/music_folder.dart';
import '../models/song.dart';
import 'path_utils.dart';

/// How a flat folder list is ordered.
enum FolderSort { name, trackCount, duration, lastModified }

/// Pure folder/exclusion logic over the song index. No Flutter, no `dart:io`.
abstract final class FolderLogic {
  const FolderLogic._();

  /// True when [path] is the same as, or nested under, any excluded folder.
  static bool isExcluded(String path, List<String> excludedFolders) {
    for (final ex in excludedFolders) {
      if (ex.isNotEmpty && PathUtils.isWithin(path, ex)) return true;
    }
    return false;
  }

  /// Whether a song survives the hidden-item rules.
  static bool passesHiddenRules(
    Song song, {
    required bool hideDotFolders,
    required int minTrackSeconds,
  }) {
    if (minTrackSeconds > 0 &&
        song.duration.inSeconds < minTrackSeconds) {
      return false;
    }
    if (hideDotFolders) {
      for (final seg in PathUtils.segments(PathUtils.parentDir(song.filePath))) {
        if (seg.startsWith('.')) return false;
      }
    }
    return true;
  }

  /// Applies exclusion + hidden rules to [songs] in one pass. This is the
  /// single chokepoint the library pipeline uses so excluded/hidden tracks
  /// disappear everywhere at once.
  static List<Song> filter(
    List<Song> songs, {
    List<String> excludedFolders = const [],
    bool hideDotFolders = true,
    int minTrackSeconds = 0,
  }) {
    if (excludedFolders.isEmpty && !hideDotFolders && minTrackSeconds <= 0) {
      return songs;
    }
    return [
      for (final s in songs)
        if (!isExcluded(PathUtils.parentDir(s.filePath), excludedFolders) &&
            passesHiddenRules(s,
                hideDotFolders: hideDotFolders,
                minTrackSeconds: minTrackSeconds))
          s,
    ];
  }

  /// Groups [songs] by their immediate containing directory (flat view).
  static List<MusicFolder> groupByFolder(
    List<Song> songs, {
    FolderSort sort = FolderSort.name,
  }) {
    final byDir = <String, List<Song>>{};
    for (final s in songs) {
      (byDir[PathUtils.parentDir(s.filePath)] ??= []).add(s);
    }
    final folders = [
      for (final e in byDir.entries) MusicFolder(path: e.key, songs: e.value),
    ];
    sortFolders(folders, sort);
    return folders;
  }

  /// Deepest directory that contains every path in [songs] (browse root).
  static String commonAncestor(List<Song> songs) {
    if (songs.isEmpty) return '';
    List<String> common =
        PathUtils.segments(PathUtils.parentDir(songs.first.filePath));
    for (final s in songs.skip(1)) {
      final segs = PathUtils.segments(PathUtils.parentDir(s.filePath));
      var i = 0;
      while (i < common.length && i < segs.length && common[i] == segs[i]) {
        i++;
      }
      common = common.sublist(0, i);
      if (common.isEmpty) break;
    }
    return common.isEmpty ? '' : '${PathUtils.separator}${common.join(PathUtils.separator)}';
  }

  /// One level of hierarchical browsing: the immediate child folders of
  /// [currentPath] (each carrying every song beneath it, recursively) plus the
  /// songs that sit directly in [currentPath].
  static FolderListing browse(List<Song> songs, String currentPath) {
    final here = <Song>[];
    final beneath = <String, List<Song>>{}; // immediate child dir → all songs
    final prefixSegs = PathUtils.segments(currentPath).length;

    for (final s in songs) {
      final dir = PathUtils.parentDir(s.filePath);
      if (dir == currentPath) {
        here.add(s);
        continue;
      }
      if (!PathUtils.isWithin(dir, currentPath)) continue;
      // The immediate child directory is currentPath + the next segment.
      final segs = PathUtils.segments(dir);
      if (segs.length <= prefixSegs) continue;
      final childDir =
          '${PathUtils.separator}${segs.sublist(0, prefixSegs + 1).join(PathUtils.separator)}';
      (beneath[childDir] ??= []).add(s);
    }

    final folders = [
      for (final e in beneath.entries) MusicFolder(path: e.key, songs: e.value),
    ];
    sortFolders(folders, FolderSort.name);
    return FolderListing(folders: folders, songs: here);
  }

  static void sortFolders(List<MusicFolder> folders, FolderSort sort) {
    switch (sort) {
      case FolderSort.name:
        folders.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case FolderSort.trackCount:
        folders.sort((a, b) => b.trackCount.compareTo(a.trackCount));
      case FolderSort.duration:
        folders.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
      case FolderSort.lastModified:
        // Approximated by the most recent dateAdded among a folder's tracks.
        DateTime newest(MusicFolder f) {
          var t = DateTime.fromMillisecondsSinceEpoch(0);
          for (final s in f.songs) {
            if (s.dateAdded.isAfter(t)) t = s.dateAdded;
          }
          return t;
        }

        folders.sort((a, b) => newest(b).compareTo(newest(a)));
    }
  }
}
