import '../library/path_utils.dart';
import 'song.dart';

/// A filesystem folder that contains (directly or, in the tree view, beneath it)
/// music. Derived on the fly from the song index — never persisted.
class MusicFolder {
  const MusicFolder({required this.path, required this.songs});

  /// Absolute directory path (no trailing slash).
  final String path;

  /// The songs counted toward this folder (recursive in the browser, direct in
  /// the flat view — the builder decides which list it passes).
  final List<Song> songs;

  String get name => PathUtils.basename(path);
  int get trackCount => songs.length;
  String get storageLabel => PathUtils.storageLabel(path);

  Duration get totalDuration {
    var ms = 0;
    for (final s in songs) {
      ms += s.duration.inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }

  /// First track's art is used as the folder thumbnail.
  Song? get displaySong => songs.isEmpty ? null : songs.first;

  List<String> get songIds => [for (final s in songs) s.id];
}

/// One level of a hierarchical folder browse: the immediate child folders and
/// the songs that live directly in the current directory.
class FolderListing {
  const FolderListing({required this.folders, required this.songs});
  final List<MusicFolder> folders;
  final List<Song> songs;

  bool get isEmpty => folders.isEmpty && songs.isEmpty;
}
