import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';

/// SharedPreferences-backed [PlaylistRepository]. Playlists survive app
/// restarts. Uses the same stream-based API as [InMemoryPlaylistRepository]
/// so nothing in the UI changes.
class SharedPrefsPlaylistRepository implements PlaylistRepository {
  SharedPrefsPlaylistRepository() {
    _load();
  }

  static const String _key = 'playlists_v1';

  final List<Playlist> _playlists = [];
  final _controller = StreamController<List<Playlist>>.broadcast();
  int _seq = 0;
  bool _loaded = false;
  final _readyCompleter = Completer<void>();

  String _newId() => 'pl_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _playlists.addAll(list.map(_fromJson));
      } catch (_) {}
    }
    _loaded = true;
    _readyCompleter.complete();
    _emit();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_playlists.map(_toJson).toList()));
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(List.unmodifiable(_playlists));
  }

  int _indexOf(String id) => _playlists.indexWhere((p) => p.id == id);

  static Map<String, dynamic> _toJson(Playlist p) => {
        'id': p.id,
        'name': p.name,
        'songIds': p.songIds,
        'createdAt': p.createdAt.millisecondsSinceEpoch,
        'updatedAt': p.updatedAt.millisecondsSinceEpoch,
      };

  static Playlist _fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        songIds: (j['songIds'] as List).cast<String>(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int),
      );

  @override
  Stream<List<Playlist>> watchPlaylists() async* {
    await _readyCompleter.future;
    yield List.unmodifiable(_playlists);
    yield* _controller.stream;
  }

  @override
  List<Playlist> get current => List.unmodifiable(_playlists);

  @override
  Future<Playlist> create(String name) async {
    await _readyCompleter.future;
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
    await _save();
    return playlist;
  }

  @override
  Future<void> rename(String id, String name) async {
    final i = _indexOf(id);
    if (i == -1) return;
    _playlists[i] =
        _playlists[i].copyWith(name: name.trim(), updatedAt: DateTime.now());
    _emit();
    await _save();
  }

  @override
  Future<void> delete(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    _emit();
    await _save();
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
    await _save();
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
    await _save();
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
    await _save();
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
