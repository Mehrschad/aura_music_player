import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom playlist cover image paths, keyed by playlist id and persisted to
/// SharedPreferences. Stored separately from the [Playlist] record so choosing
/// a cover needs no model or repository change. Best-effort: load/save failures
/// (e.g. no platform channel in tests) are swallowed.
class PlaylistCoversNotifier extends StateNotifier<Map<String, String>> {
  PlaylistCoversNotifier() : super(const {}) {
    _load();
  }

  static const String _key = 'playlist_covers_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final map = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      if (mounted) state = map;
    } catch (_) {/* tests / first launch */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state));
    } catch (_) {/* tests */}
  }

  void setCover(String playlistId, String path) {
    state = {...state, playlistId: path};
    _save();
  }

  void removeCover(String playlistId) {
    if (!state.containsKey(playlistId)) return;
    state = Map<String, String>.of(state)..remove(playlistId);
    _save();
  }
}

final playlistCoversProvider =
    StateNotifierProvider<PlaylistCoversNotifier, Map<String, String>>(
  (ref) => PlaylistCoversNotifier(),
);

/// A single playlist's custom cover path, or null when none is set.
final playlistCoverProvider = Provider.family<String?, String>(
  (ref, id) => ref.watch(playlistCoversProvider)[id],
);

/// Opens the system image picker and, on selection, copies the chosen image
/// into the app's documents dir (so it survives the source being cleared) and
/// records it as [playlistId]'s cover. Returns true when a cover was set.
Future<bool> pickPlaylistCover(WidgetRef ref, String playlistId) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image);
  final source = result?.files.single.path;
  if (source == null) return false;
  String dest = source;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${dir.path}/playlist_covers');
    if (!coversDir.existsSync()) coversDir.createSync(recursive: true);
    final dot = source.lastIndexOf('.');
    final ext = dot >= 0 ? source.substring(dot) : '.img';
    dest = '${coversDir.path}/$playlistId$ext';
    await File(source).copy(dest);
  } catch (_) {
    // Fall back to referencing the picked path directly.
    dest = source;
  }
  ref.read(playlistCoversProvider.notifier).setCover(playlistId, dest);
  return true;
}
