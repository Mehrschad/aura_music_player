import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/audio_query/device_library_repository.dart';
import '../../data/local/tag_editor/audiotagger_tag_writer.dart';
import '../../domain/library/folder_logic.dart';
import '../../domain/library/library_grouping.dart';
import '../../domain/library/song_search.dart';
import '../../domain/library/song_sorting.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/genre.dart';
import '../../domain/models/library_sort.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/library_repository.dart';
import 'hidden_songs_providers.dart';
import 'settings_providers.dart';
import 'song_ratings_provider.dart';

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

/// The song index with tag edits applied, soft-hidden tracks removed, and the
/// folder rules (excluded folders, dot-folders, min-duration) enforced.
/// Everything downstream (library, albums, artists, search, playlists, folders)
/// reads this rather than the raw scan, so a hidden/excluded track disappears
/// everywhere at once.
final effectiveSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final overrides = ref.watch(tagOverridesProvider);
  final hidden = ref.watch(hiddenSongsProvider);
  final ratings = ref.watch(songRatingsProvider);
  final excluded = ref.watch(settingsProvider.select((s) => s.excludedFolders));
  final hideDot = ref.watch(settingsProvider.select((s) => s.hideDotFolders));
  final minSecs = ref.watch(settingsProvider.select((s) => s.minTrackSeconds));
  return ref.watch(songsProvider).whenData((list) {
    final base = (overrides.isEmpty && hidden.isEmpty && ratings.isEmpty)
        ? list
        : [
            for (final s in list)
              if (!hidden.contains(s.id))
                _withRating(overrides[s.id] ?? s, ratings),
          ];
    return FolderLogic.filter(
      base,
      excludedFolders: excluded,
      hideDotFolders: hideDot,
      minTrackSeconds: minSecs,
    );
  });
});

/// Applies a user rating to [song] when one exists, leaving the scan value
/// otherwise. Keeps the rating merge identical to the tag-overrides pattern.
Song _withRating(Song song, Map<String, int> ratings) {
  final r = ratings[song.id];
  if (r == null || r == song.rating) return song;
  return song.copyWith(rating: r);
}

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

final genresProvider = Provider<AsyncValue<List<Genre>>>((ref) {
  return ref.watch(effectiveSongsProvider).whenData(groupGenres);
});

/// Songs of a given genre, sorted by artist → album → track.
final genreSongsProvider =
    Provider.family<AsyncValue<List<Song>>, String>((ref, genreName) {
  return ref.watch(effectiveSongsProvider).whenData((list) {
    return list.where((s) => (s.genre ?? '').trim() == genreName).toList()
      ..sort((a, b) {
        final artistCmp = a.artist.compareTo(b.artist);
        if (artistCmp != 0) return artistCmp;
        final albumCmp = a.album.compareTo(b.album);
        if (albumCmp != 0) return albumCmp;
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });
  });
});

/// Songs of a given album, in track order — used by album detail later.
final albumSongsProvider =
    Provider.family<AsyncValue<List<Song>>, String>((ref, albumId) {
  return ref.watch(effectiveSongsProvider).whenData((list) {
    final out = list.where((s) => s.albumId == albumId).toList()
      ..sort((a, b) {
        final discCmp = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
        if (discCmp != 0) return discCmp;
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });
    return out;
  });
});

/// Search results for the current query.
final searchResultsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(effectiveSongsProvider).whenData((list) => searchSongs(list, query));
});

/// Songs by a given artist, in album/track order.
final artistSongsProvider =
    Provider.family<AsyncValue<List<Song>>, String>((ref, artistId) {
  return ref.watch(effectiveSongsProvider).whenData((list) {
    return list.where((s) => s.artistId == artistId || s.artist == artistId).toList()
      ..sort((a, b) {
        final albumCmp = (a.album).compareTo(b.album);
        if (albumCmp != 0) return albumCmp;
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });
  });
});

/// Albums by a given artist.
final artistAlbumsProvider =
    Provider.family<AsyncValue<List<Album>>, String>((ref, artistId) {
  return ref.watch(effectiveSongsProvider).whenData((list) {
    final artistSongs =
        list.where((s) => s.artistId == artistId || s.artist == artistId).toList();
    return groupAlbums(artistSongs);
  });
});
