/// A single track submission for Last.fm scrobbling.
class ScrobbleEntry {
  const ScrobbleEntry({
    required this.track,
    required this.artist,
    required this.album,
    required this.songId,
    required this.timestampSec,
    required this.durationSec,
  });

  final String track;
  final String artist;
  final String album;
  final String songId;
  // Unix epoch seconds when playback started.
  final int timestampSec;
  final int durationSec;

  Map<String, dynamic> toJson() => {
        'track': track,
        'artist': artist,
        'album': album,
        'songId': songId,
        'timestampSec': timestampSec,
        'durationSec': durationSec,
      };

  static ScrobbleEntry fromJson(Map<String, dynamic> j) => ScrobbleEntry(
        track: j['track'] as String,
        artist: j['artist'] as String,
        album: j['album'] as String,
        songId: j['songId'] as String,
        timestampSec: j['timestampSec'] as int,
        durationSec: j['durationSec'] as int,
      );
}
