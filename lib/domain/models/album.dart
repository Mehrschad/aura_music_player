import 'package:flutter/foundation.dart';

/// A grouped album, derived from the song index (see `library_grouping.dart`).
@immutable
class Album {
  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.songCount,
    this.year,
    this.hasArtwork = false,
  });

  final String id;
  final String name;
  final String artist;
  final int songCount;
  final int? year;
  final bool hasArtwork;

  /// Seed for the placeholder artwork gradient.
  String get artworkSeed => id;

  @override
  bool operator ==(Object other) => other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
