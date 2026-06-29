import '../models/library_sort.dart';
import '../models/song.dart';

/// Pure, side-effect-free sorting of songs by a [LibrarySort].
///
/// Returns a new list; the input is never mutated. Sorting is stable: ties
/// fall back to a case-insensitive title compare so ordering is deterministic
/// (important for tests, and so the list doesn't visibly "jitter" on rescans).
///
/// Missing values (year, lastPlayed) always sort *last* — in both ascending
/// and descending order — so absent metadata never floats to the top of the
/// list. Direction is applied only to the value comparison, never to the
/// null-presence ordering.
List<Song> sortSongs(List<Song> songs, LibrarySort sort) {
  final out = List<Song>.of(songs);
  final asc = sort.direction == SortDirection.ascending;

  int titleCompare(Song a, Song b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  // Directional comparison of an always-present value.
  int present(int cmp) => asc ? cmp : -cmp;

  out.sort((a, b) {
    final int primary;
    switch (sort.field) {
      case SortField.title:
        primary = present(titleCompare(a, b));
      case SortField.artist:
        primary =
            present(a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
      case SortField.album:
        primary =
            present(a.album.toLowerCase().compareTo(b.album.toLowerCase()));
      case SortField.dateAdded:
        primary = present(a.dateAdded.compareTo(b.dateAdded));
      case SortField.duration:
        primary = present(a.duration.compareTo(b.duration));
      case SortField.playCount:
        primary = present(a.playCount.compareTo(b.playCount));
      case SortField.year:
        primary = _nullableInt(a.year, b.year, present);
      case SortField.lastPlayed:
        primary = _nullableDate(a.lastPlayed, b.lastPlayed, present);
      case SortField.rating:
        primary = _nullableInt(a.rating, b.rating, present);
    }
    if (primary != 0) return primary;
    return titleCompare(a, b); // deterministic tie-break, always A-Z
  });
  return out;
}

/// Compares two nullable ints. Nulls rank last regardless of [present]'s
/// direction; only the value-to-value compare is directional.
int _nullableInt(int? a, int? b, int Function(int) present) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // a sorts after b
  if (b == null) return -1; // a sorts before b
  return present(a.compareTo(b));
}

int _nullableDate(DateTime? a, DateTime? b, int Function(int) present) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return present(a.compareTo(b));
}
