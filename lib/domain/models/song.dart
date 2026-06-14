import 'package:flutter/foundation.dart';

/// An immutable audio track in the library.
///
/// Plain hand-written immutable class (not freezed) so the project compiles
/// and runs without a code-generation step. The field set is chosen to satisfy
/// downstream features now: sorting (step 2), the smart-playlist rules engine
/// (step 11 — Title/Artist/Album/Genre/Year/Duration/PlayCount/LastPlayed/
/// DateAdded/Bitrate/HasLyrics/HasArtwork all live here), and the tag editor
/// (step 10).
@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.artistId,
    required this.duration,
    required this.filePath,
    required this.dateAdded,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.bitrate,
    this.composer,
    this.comment,
    this.bpm,
    this.compilation = false,
    this.playCount = 0,
    this.lastPlayed,
    this.rating,
    this.hasLyrics = false,
    this.hasArtwork = false,
    this.trackGain,
    this.albumGain,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final String artistId;

  /// Track length.
  final Duration duration;

  /// Absolute path on the device file system.
  final String filePath;

  /// When the file was added to / first seen by the library.
  final DateTime dateAdded;

  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;

  /// Bitrate in kbps, when known.
  final int? bitrate;

  final String? composer;
  final String? comment;
  final int? bpm;
  final bool compilation;

  final int playCount;
  final DateTime? lastPlayed;

  /// User star rating, 0–5, or null when unrated.
  final int? rating;

  final bool hasLyrics;
  final bool hasArtwork;

  // ReplayGain track gain in dB (null = no tag).
  final double? trackGain;
  // ReplayGain album gain in dB (null = no tag).
  final double? albumGain;

  /// Stable seed used to render a deterministic placeholder artwork gradient
  /// when [hasArtwork] is false. Keyed on the album so a whole album shares
  /// one placeholder.
  String get artworkSeed => albumId;

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    int? bitrate,
    String? composer,
    String? comment,
    int? bpm,
    bool? compilation,
    int? playCount,
    DateTime? lastPlayed,
    int? rating,
    bool? hasLyrics,
    bool? hasArtwork,
    Object? trackGain = _sentinel,
    Object? albumGain = _sentinel,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId,
      artistId: artistId,
      duration: duration,
      filePath: filePath,
      dateAdded: dateAdded,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      bitrate: bitrate ?? this.bitrate,
      composer: composer ?? this.composer,
      comment: comment ?? this.comment,
      bpm: bpm ?? this.bpm,
      compilation: compilation ?? this.compilation,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      rating: rating ?? this.rating,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      hasArtwork: hasArtwork ?? this.hasArtwork,
      trackGain: identical(trackGain, _sentinel) ? this.trackGain : trackGain as double?,
      albumGain: identical(albumGain, _sentinel) ? this.albumGain : albumGain as double?,
    );
  }

  // Sentinel for nullable copyWith fields.
  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
