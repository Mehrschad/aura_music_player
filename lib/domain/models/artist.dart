import 'package:flutter/foundation.dart';

/// A grouped artist, derived from the song index (see `library_grouping.dart`).
@immutable
class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.albumCount,
    required this.songCount,
    this.hasArtwork = false,
    this.firstSongId,
  });

  final String id;
  final String name;
  final int albumCount;
  final int songCount;

  /// True when at least one song by this artist has embedded artwork.
  final bool hasArtwork;

  /// Media-store ID of a representative song used by [QueryArtworkWidget].
  final int? firstSongId;

  String get artworkSeed => id;

  @override
  bool operator ==(Object other) => other is Artist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
