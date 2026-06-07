import '../models/playback.dart';
import '../models/song.dart';

/// The data shown on the home-screen widgets (mini / standard / large). Mapped
/// from playback state; serialised to the primitive key-value map that
/// `home_widget` hands to the native widget providers.
class HomeWidgetState {
  const HomeWidgetState({
    required this.hasMedia,
    this.title = '',
    this.artist = '',
    this.artworkSeed = '',
    this.hasArtwork = false,
    this.playing = false,
    this.progress = 0,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
  });

  static const HomeWidgetState empty = HomeWidgetState(hasMedia: false);

  final bool hasMedia;
  final String title;
  final String artist;
  final String artworkSeed;
  final bool hasArtwork;
  final bool playing;

  /// Track progress, 0..1 (large widget).
  final double progress;
  final bool shuffle;
  final RepeatMode repeat;

  /// Flat map for `HomeWidget.saveWidgetData` (native side reads these keys).
  Map<String, String> toWidgetData() => {
        'has_media': '$hasMedia',
        'title': title,
        'artist': artist,
        'artwork_seed': artworkSeed,
        'has_artwork': '$hasArtwork',
        'playing': '$playing',
        'progress': progress.toStringAsFixed(4),
        'shuffle': '$shuffle',
        'repeat': repeat.name,
      };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetState &&
      other.hasMedia == hasMedia &&
      other.title == title &&
      other.artist == artist &&
      other.artworkSeed == artworkSeed &&
      other.hasArtwork == hasArtwork &&
      other.playing == playing &&
      other.progress == progress &&
      other.shuffle == shuffle &&
      other.repeat == repeat;

  @override
  int get hashCode => Object.hash(hasMedia, title, artist, artworkSeed,
      hasArtwork, playing, progress, shuffle, repeat);
}

/// Builds the widget state from the current [song], [state] and [position].
HomeWidgetState homeWidgetStateFrom({
  required Song? song,
  required PlaybackState state,
  required Duration position,
}) {
  if (song == null) return HomeWidgetState.empty;
  final ms = song.duration.inMilliseconds;
  final progress =
      ms <= 0 ? 0.0 : (position.inMilliseconds / ms).clamp(0.0, 1.0);
  return HomeWidgetState(
    hasMedia: true,
    title: song.title,
    artist: song.artist,
    artworkSeed: song.artworkSeed,
    hasArtwork: song.hasArtwork,
    playing: state.playing,
    progress: progress,
    shuffle: state.shuffleEnabled,
    repeat: state.repeatMode,
  );
}
