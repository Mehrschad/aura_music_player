import 'package:flutter/foundation.dart';

/// A user-created playlist: an ordered list of song ids.
///
/// Song ids (not full [Song] objects) are stored so a playlist survives library
/// rescans and stays a thin record; the UI resolves ids against the live song
/// index when displaying.
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get length => songIds.length;

  Playlist copyWith({
    String? name,
    List<String>? songIds,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Value equality includes the mutable fields (not just [id]) so Riverpod's
  // providers actually re-notify when a playlist's songs, name, or timestamp
  // change — otherwise a same-id result deduped and the detail page kept showing
  // the old (empty) track list after adding songs.
  @override
  bool operator ==(Object other) =>
      other is Playlist &&
      other.id == id &&
      other.updatedAt == updatedAt &&
      other.name == name &&
      listEquals(other.songIds, songIds);

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

/// The built-in, auto-updating playlists. Not stored — each is derived from the
/// live song index (and, for [favorites], the favourites store).
enum AutoPlaylist {
  recentlyAdded,
  mostPlayed,
  recentlyPlayed,
  favorites,
  topRated,
}
