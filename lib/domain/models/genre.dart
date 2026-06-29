import 'package:flutter/foundation.dart';

/// A grouped genre, derived from the song index (see `library_grouping.dart`).
@immutable
class Genre {
  const Genre({
    required this.name,
    required this.songCount,
    this.hasArtwork = false,
    this.firstSongId,
  });

  final String name; // Empty string means "no genre tag".
  final int songCount;

  /// True when at least one song in this genre has embedded artwork.
  final bool hasArtwork;

  /// Media-store ID of a representative song for artwork.
  final int? firstSongId;

  String get artworkSeed => name;

  bool get isUnknown => name.isEmpty;

  @override
  bool operator ==(Object other) => other is Genre && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
