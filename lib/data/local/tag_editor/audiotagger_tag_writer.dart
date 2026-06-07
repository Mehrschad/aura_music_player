import '../../../domain/library/tag_edit.dart';
import '../../../domain/models/song.dart';

/// Writes tag edits back to the actual audio files via `audiotagger` (Android).
///
/// Documented stub — it does not import `audiotagger`, so the project compiles
/// and runs with the in-app override layer (`tagOverridesProvider`) as the
/// source of truth. On device, the tag editor's save path calls this in
/// addition to updating the override, so changes persist to the files.
///
/// Real implementation:
/// ```dart
/// import 'package:audiotagger/audiotagger.dart';
/// import 'package:audiotagger/models/tag.dart';
///
/// class AudiotaggerTagWriter implements TagWriter {
///   final _tagger = Audiotagger();
///   @override
///   Future<void> write(Song song, SongTagEdit edit) async {
///     final merged = edit.applyTo(song);
///     await _tagger.writeTags(
///       path: song.filePath,
///       tag: Tag(
///         title: merged.title,
///         artist: merged.artist,
///         album: merged.album,
///         albumArtist: merged.albumArtist,
///         genre: merged.genre,
///         year: merged.year?.toString(),
///         trackNumber: merged.trackNumber?.toString(),
///         discNumber: merged.discNumber?.toString(),
///         comment: merged.comment,
///         // composer / bpm / compilation / artwork bytes likewise
///       ),
///     );
///   }
/// }
/// ```
/// Artwork bytes (from the cover-art fetch) are written with the tagger's
/// artwork field; iOS uses an equivalent native bridge.
abstract interface class TagWriter {
  Future<void> write(Song song, SongTagEdit edit);
}

/// Active no-network writer: the override layer already reflects edits in-app,
/// so this performs no file I/O. Swapped for the real `audiotagger` writer on
/// device.
class NoopTagWriter implements TagWriter {
  const NoopTagWriter();

  @override
  Future<void> write(Song song, SongTagEdit edit) async {}
}
