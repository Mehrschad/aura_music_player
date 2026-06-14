/// A single recorded playback event — one row in the listening history.
///
/// Stores denormalised artist/album/genre so stats can be aggregated without
/// re-resolving the (possibly changed or deleted) song. [completed] is true when
/// the track counted as a "play" (≥ threshold listened), false for a "skip".
class PlayEvent {
  const PlayEvent({
    required this.songId,
    required this.artist,
    required this.album,
    required this.genre,
    required this.atMs,
    required this.msPlayed,
    required this.completed,
  });

  final String songId;
  final String artist;
  final String album;
  final String? genre;

  /// Wall-clock timestamp (ms since epoch) the event was recorded.
  final int atMs;

  /// How many milliseconds of the track were actually played.
  final int msPlayed;

  /// True = counted as a play; false = a skip.
  final bool completed;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);
  Duration get played => Duration(milliseconds: msPlayed);

  Map<String, dynamic> toJson() => {
        's': songId,
        'ar': artist,
        'al': album,
        'g': genre,
        't': atMs,
        'm': msPlayed,
        'c': completed,
      };

  factory PlayEvent.fromJson(Map<String, dynamic> j) => PlayEvent(
        songId: j['s'] as String,
        artist: (j['ar'] as String?) ?? '',
        album: (j['al'] as String?) ?? '',
        genre: j['g'] as String?,
        atMs: j['t'] as int,
        msPlayed: (j['m'] as int?) ?? 0,
        completed: (j['c'] as bool?) ?? true,
      );
}
