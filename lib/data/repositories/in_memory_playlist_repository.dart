import 'dart:async';

import '../../domain/models/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';

/// Session-scoped [PlaylistRepository]. Fully functional — create, rename,
/// delete, add, remove, reorder all work and stream live to the UI — but held
/// in memory, so playlists reset on restart. The Isar implementation persists
/// them; nothing in the UI changes when it's swapped in.
///
/// Seeded with one example playlist so the Playlists tab isn't empty on first
/// run.
class InMemoryPlaylistRepository implements PlaylistRepository {
  InMemoryPlaylistRepository() {
    _playlists.add(
      Playlist(
        id: _newId(),
        name: 'Evening Wind-down',
        songIds: const ['s10', 's11', 's3', 's5'],
        createdAt: DateTime(2026, 5, 20),
        updatedAt: DateTime(2026, 5, 20),
      ),
    );
  }

  final List<Playlist> _playlists = [];
  final _controller = StreamController<List<Playlist>>.broadcast();
  int _seq = 0;

  String _newId() => 'pl_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _emit() {
    if (!_controller.isClosed) _controller.add(List.unmodifiable(_playlists));
  }

  int _indexOf(String id) => _playlists.indexWhere((p) => p.id == id);

  @override
  Stream<List<Playlist>> watchPlaylists() async* {
    yield List.unmodifiable(_playlists);
    yield* _controller.stream;
  }

  @override
  List<Playlist> get current => List.unmodifiable(_playlists);

  @override
  Future<Playlist> create(String name) async {
    final now = DateTime.now();
    final playlist = Playlist(
      id: _newId(),
      name: name.trim().isEmpty ? 'New playlist' : name.trim(),
      songIds: const [],
      createdAt: now,
      updatedAt: now,
    );
    _playlists.insert(0, playlist);
    _emit();
    return playlist;
  }

  @override
  Future<void> rename(String id, String name) async {
    final i = _indexOf(id);
    if (i == -1) return;
    _playlists[i] =
        _playlists[i].copyWith(name: name.trim(), updatedAt: DateTime.now());
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    _emit();
  }

  @override
  Future<void> addSongs(String id, List<String> songIds) async {
    final i = _indexOf(id);
    if (i == -1) return;
    final existing = _playlists[i].songIds;
    final seen = Set<String>.from(existing);
    final merged = [...existing];
    for (final s in songIds) {
      if (seen.add(s)) merged.add(s);
    }
    _playlists[i] =
        _playlists[i].copyWith(songIds: merged, updatedAt: DateTime.now());
    _emit();
  }

  @override
  Future<void> removeSongAt(String id, int index) async {
    final i = _indexOf(id);
    if (i == -1) return;
    final songs = List<String>.of(_playlists[i].songIds);
    if (index < 0 || index >= songs.length) return;
    songs.removeAt(index);
    _playlists[i] =
        _playlists[i].copyWith(songIds: songs, updatedAt: DateTime.now());
    _emit();
  }

  @override
  Future<void> reorder(String id, int oldIndex, int newIndex) async {
    final i = _indexOf(id);
    if (i == -1) return;
    final songs = List<String>.of(_playlists[i].songIds);
    if (oldIndex < 0 || oldIndex >= songs.length) return;
    final item = songs.removeAt(oldIndex);
    songs.insert(newIndex.clamp(0, songs.length), item);
    _playlists[i] =
        _playlists[i].copyWith(songIds: songs, updatedAt: DateTime.now());
    _emit();
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
