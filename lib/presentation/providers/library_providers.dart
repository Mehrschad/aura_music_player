import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/audio_query/device_library_repository.dart';
import '../../data/local/tag_editor/audiotagger_tag_writer.dart';
import '../../domain/library/library_grouping.dart';
import '../../domain/library/song_search.dart';
import '../../domain/library/song_sorting.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/library_sort.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/library_repository.dart';
import 'settings_providers.dart';

/// The active library data source — backed by the device media store.
/// Rebuilt whenever [sourceFolders] changes so the scan is always in sync
/// with the user's folder selection.
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final folders = ref.watch(settingsProvider.select((s) => s.sourceFolders));
  return DeviceLibraryRepository(sourceFolders: folders);
});

/// The raw song index, loaded asynchronously from the device media store.
final songsProvider = FutureProvider<List<Song>>((ref) {
  return ref.watch(libraryRepositoryProvider).fetchSongs();
});

/// Triggers a forced rescan and refreshes [songsProvider].
final rescanProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(libraryRepositoryProvider).fetchSongs(forceRescan: true);
    ref.invalidate(songsProvider);
  };
});

/// Session tag edits, keyed by song id (results of the tag editor, step 10).
/// Applied on top of the repository scan so edits show across the whole library
/// without a rescan. Persists to the file tags / database on device; the
/// `audiotagger` write is documented in `AudiotaggerTagWriter`.
class TagOverrides extends StateNotifier<Map<String, Song>> {
  TagOverrides() : super(const {});

  void apply(List<Song> edited) =>
      state = {...state, for (final s in edited) s.id: s};
}

final tagOverridesProvider =
    StateNotifierProvider<TagOverrides, Map<String, Song>>(
  (ref) => TagOverrides(),
);

/// The device tag writer. Active is a no-op (the override layer reflects edits
/// in-app); override with the real `audiotagger` writer on device so saves
/// persist to the files.
final tagWriterProvider = Provider<TagWriter>((ref) => const NoopTagWriter());

/// The song index with any tag edits applied. Everything downstream (library,
/// albums, artists, search, playlists) reads this rather than the raw scan.
final effectiveSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final overrides = ref.watch(tagOverridesProvider);
  return ref.watch(songsProvider).whenData((list) {
    if (overrides.isEmpty) return list;
    return [for (final s in list) overrides[s.id] ?? s];
  });
});

// ── Per-section UI state ───────────────────────────────────────────────────

/// Sort selection for the Library (all-songs) section.
final librarySortProvider =
    StateProvider<LibrarySort>((ref) => LibrarySort.defaultSort);

/// Display mode for the Library section.
final libraryDisplayModeProvider =
    StateProvider<DisplayMode>((ref) => DisplayMode.list);

/// Display mode for the Albums section (grid by default — it's artwork-forward).
final albumsDisplayModeProvider =
    StateProvider<DisplayMode>((ref) => DisplayMode.grid);

/// Live search query for the Search section.
final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Derived views ────────────────────────────────────────────────────────

/// The library songs, sorted per [librarySortProvider]. Preserves the async
/// loading/error envelope from [songsProvider].
final sortedSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final songs = ref.watch(effectiveSongsProvider);
  final sort = ref.watch(librarySortProvider);
  return songs.whenData((list) => sortSongs(list, sort));
});

final albumsProvider = Provider<AsyncValue<List<Album>>>((ref) {
  return ref.watch(effectiveSongsProvider).whenData(groupAlbums);
});

final artistsProvider = Provider<AsyncValue<List<Artist>>>((ref) {
  return ref.watch(effectiveSongsProvider).whenData(groupArtists);
});

/// Songs of a given album, in track order — used by album detail later.
final albumSongsProvider =
    Provider.family<AsyncValue<List<Song>>, String>((ref, albumId) {
  return ref.watch(effectiveSongsProvider).whenData((list) {
    final out = list.where((s) => s.albumId == albumId).toList()
      ..sort((a, b) => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0));
    return out;
  });
});

/// Search results for the current query.
final searchResultsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(effectiveSongsProvider).whenData((list) => searchSongs(list, query));
});
