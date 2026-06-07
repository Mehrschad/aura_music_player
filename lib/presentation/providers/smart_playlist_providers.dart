import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/in_memory_smart_playlist_repository.dart';
import '../../domain/library/smart_playlist.dart';
import '../../domain/library/smart_playlist_eval.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/smart_playlist_repository.dart';
import 'library_providers.dart';

final smartPlaylistRepositoryProvider = Provider<SmartPlaylistRepository>(
  (ref) => InMemorySmartPlaylistRepository(),
);

/// All smart-playlist definitions.
final smartPlaylistsProvider = FutureProvider<List<SmartPlaylist>>(
  (ref) => ref.watch(smartPlaylistRepositoryProvider).all(),
);

/// A single definition by id (null if not loaded / not found).
final smartPlaylistByIdProvider =
    Provider.family<SmartPlaylist?, String>((ref, id) {
  final list = ref.watch(smartPlaylistsProvider).valueOrNull;
  if (list == null) return null;
  for (final p in list) {
    if (p.id == id) return p;
  }
  return null;
});

/// The live songs for a smart playlist: its rules evaluated against the
/// (edit-aware) library, re-running whenever either changes.
final smartPlaylistSongsProvider =
    Provider.family<AsyncValue<List<Song>>, String>((ref, id) {
  final def = ref.watch(smartPlaylistByIdProvider(id));
  return ref.watch(effectiveSongsProvider).whenData(
        (songs) => def == null ? <Song>[] : evaluateSmartPlaylist(def, songs),
      );
});

/// Persists a definition and refreshes the list. Returns the stored playlist.
Future<SmartPlaylist> saveSmartPlaylist(WidgetRef ref, SmartPlaylist p) async {
  final saved = await ref.read(smartPlaylistRepositoryProvider).save(p);
  ref.invalidate(smartPlaylistsProvider);
  return saved;
}

Future<void> deleteSmartPlaylist(WidgetRef ref, String id) async {
  await ref.read(smartPlaylistRepositoryProvider).delete(id);
  ref.invalidate(smartPlaylistsProvider);
}
