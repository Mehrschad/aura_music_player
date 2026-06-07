import 'package:flutter/foundation.dart';

/// The dimensions a song list can be sorted by.
///
/// Maps directly to the spec's sort options. Title gets an explicit direction
/// (A–Z / Z–A); the rest default to the natural "most useful first" direction
/// resolved in [LibrarySort.defaultDirectionFor].
enum SortField {
  title,
  artist,
  album,
  dateAdded, // "Recently Added"
  year,
  duration,
  playCount,
  lastPlayed,
}

enum SortDirection { ascending, descending }

/// Immutable sort selection for a library section.
@immutable
class LibrarySort {
  const LibrarySort(this.field, this.direction);

  final SortField field;
  final SortDirection direction;

  static const LibrarySort defaultSort =
      LibrarySort(SortField.title, SortDirection.ascending);

  /// The sensible default direction when a user first picks a field — e.g.
  /// "Recently Added" should lead with the newest, "Play Count" with the most
  /// played.
  static SortDirection defaultDirectionFor(SortField field) {
    switch (field) {
      case SortField.title:
      case SortField.artist:
      case SortField.album:
      case SortField.duration:
        return SortDirection.ascending;
      case SortField.dateAdded:
      case SortField.year:
      case SortField.playCount:
      case SortField.lastPlayed:
        return SortDirection.descending;
    }
  }

  LibrarySort withField(SortField field) =>
      LibrarySort(field, defaultDirectionFor(field));

  LibrarySort toggleDirection() => LibrarySort(
        field,
        direction == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending,
      );

  @override
  bool operator ==(Object other) =>
      other is LibrarySort &&
      other.field == field &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(field, direction);
}

/// How a section renders its items.
enum DisplayMode {
  /// Artwork tiles in a 2–3 column grid.
  grid,

  /// Compact rows with a thumbnail.
  list,

  /// Text-only, ultra-dense.
  compact,
}
