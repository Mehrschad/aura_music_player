import '../models/song.dart';

/// A set of tag changes. Only non-null fields are written; null means "leave
/// unchanged" — which is exactly what's needed for batch editing, where only
/// the fields the user actually touched are applied across the selection.
class SongTagEdit {
  const SongTagEdit({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.composer,
    this.comment,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.bpm,
    this.compilation,
    this.hasArtwork,
  });

  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final String? composer;
  final String? comment;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? bpm;
  final bool? compilation;
  final bool? hasArtwork;

  bool get isEmpty =>
      title == null &&
      artist == null &&
      albumArtist == null &&
      album == null &&
      genre == null &&
      composer == null &&
      comment == null &&
      year == null &&
      trackNumber == null &&
      discNumber == null &&
      bpm == null &&
      compilation == null &&
      hasArtwork == null;

  /// Applies the edit to [song], leaving untouched fields as-is.
  Song applyTo(Song song) => song.copyWith(
        title: title,
        artist: artist,
        albumArtist: albumArtist,
        album: album,
        genre: genre,
        composer: composer,
        comment: comment,
        year: year,
        trackNumber: trackNumber,
        discNumber: discNumber,
        bpm: bpm,
        compilation: compilation,
        hasArtwork: hasArtwork,
      );

  List<Song> applyToAll(List<Song> songs) =>
      [for (final s in songs) applyTo(s)];
}

/// The shared value of a field across a selection, for batch editing.
class FieldCommon<T> {
  const FieldCommon(this.value, this.multiple);

  /// The shared value (when not [multiple]); may itself be null.
  final T? value;

  /// True when the selection holds more than one distinct value ("Multiple
  /// values").
  final bool multiple;
}

/// Computes whether a field is shared across [songs] or differs.
FieldCommon<T> commonValue<T>(List<Song> songs, T? Function(Song) selector) {
  if (songs.isEmpty) return const FieldCommon(null, false);
  final first = selector(songs.first);
  for (final s in songs.skip(1)) {
    if (selector(s) != first) return FieldCommon<T>(null, true);
  }
  return FieldCommon<T>(first, false);
}
