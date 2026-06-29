import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/library/folder_logic.dart';
import '../../domain/library/path_utils.dart';
import '../../domain/models/music_folder.dart';
import '../../domain/models/song.dart';
import 'library_providers.dart';

/// Sort order for the flat folder list.
final folderSortProvider = StateProvider<FolderSort>((ref) => FolderSort.name);

/// The directory the hierarchical browser is currently showing. Null means
/// "start at the library's common ancestor" (computed by [folderRootProvider]).
final folderBrowsePathProvider = StateProvider<String?>((ref) => null);

/// Deepest directory that contains the whole library — the browser's home.
final folderRootProvider = Provider<String>((ref) {
  final songs = ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
  return FolderLogic.commonAncestor(songs);
});

/// Flat list of every music-containing folder, sorted by [folderSortProvider].
final musicFoldersProvider = Provider<AsyncValue<List<MusicFolder>>>((ref) {
  final sort = ref.watch(folderSortProvider);
  return ref
      .watch(effectiveSongsProvider)
      .whenData((songs) => FolderLogic.groupByFolder(songs, sort: sort));
});

/// One level of the hierarchical browse for the current path.
final folderListingProvider = Provider<AsyncValue<FolderListing>>((ref) {
  final override = ref.watch(folderBrowsePathProvider);
  final String path =
      (override == null) ? ref.watch(folderRootProvider) : override;
  return ref
      .watch(effectiveSongsProvider)
      .whenData((songs) => FolderLogic.browse(songs, path));
});

/// All songs at or beneath [path] (folder-as-playlist / Play All actions),
/// in track order within each folder.
final folderSongsProvider =
    Provider.family<List<Song>, String>((ref, path) {
  final songs = ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
  return [
    for (final s in songs)
      if (PathUtils.isWithin(PathUtils.parentDir(s.filePath), path)) s,
  ];
});
