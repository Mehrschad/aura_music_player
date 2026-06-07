import 'package:aura_music_player/data/repositories/in_memory_playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryPlaylistRepository repo;
  setUp(() => repo = InMemoryPlaylistRepository());
  tearDown(() => repo.dispose());

  test('create, rename, delete', () async {
    final p = await repo.create('Roadtrip');
    expect(repo.current.any((x) => x.id == p.id), isTrue);
    await repo.rename(p.id, 'Roadtrip 2026');
    expect(repo.current.firstWhere((x) => x.id == p.id).name, 'Roadtrip 2026');
    await repo.delete(p.id);
    expect(repo.current.any((x) => x.id == p.id), isFalse);
  });

  test('addSongs dedupes and removeSongAt works', () async {
    final p = await repo.create('P');
    await repo.addSongs(p.id, ['a', 'b', 'a', 'c']);
    expect(repo.current.firstWhere((x) => x.id == p.id).songIds,
        ['a', 'b', 'c']);
    await repo.removeSongAt(p.id, 1);
    expect(repo.current.firstWhere((x) => x.id == p.id).songIds, ['a', 'c']);
  });

  test('reorder moves a song', () async {
    final p = await repo.create('P');
    await repo.addSongs(p.id, ['a', 'b', 'c']);
    await repo.reorder(p.id, 0, 2);
    expect(repo.current.firstWhere((x) => x.id == p.id).songIds,
        ['b', 'c', 'a']);
  });

  test('watchPlaylists emits the current list immediately', () async {
    final first = await repo.watchPlaylists().first;
    expect(first, isNotEmpty); // seeded with one playlist
  });
}
