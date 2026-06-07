import 'package:flutter/foundation.dart';

import 'playback.dart';
import 'song.dart';

/// The snapshot of player state rendered by the home-screen widgets (mini /
/// standard / large) and pushed to the platform. Plain, serialisable data — no
/// Flutter types — so it maps cleanly onto `home_widget` key/values and onto
/// native RemoteViews / Compose-Glance layouts.
@immutable
class HomeWidgetState {
  const HomeWidgetState({
    required this.hasMedia,
    required this.title,
    required this.artist,
    required this.artworkSeed,
    required this.hasArtwork,
    required this.playing,
    required this.shuffle,
    required this.repeat,
    required this.position,
    required this.duration,
  });

  static const HomeWidgetState empty = HomeWidgetState(
    hasMedia: false,
    title: '',
    artist: '',
    artworkSeed: '',
    hasArtwork: false,
    playing: false,
    shuffle: false,
    repeat: RepeatMode.off,
    position: Duration.zero,
    duration: Duration.zero,
  );

  final bool hasMedia;
  final String title;
  final String artist;
  final String artworkSeed;
  final bool hasArtwork;
  final bool playing;
  final bool shuffle;
  final RepeatMode repeat;
  final Duration position;
  final Duration duration;

  /// Progress 0–1 for the large widget's bar (0 when no duration).
  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Flat key/value map for `home_widget.saveWidgetData`.
  Map<String, String> toData() => {
        'hasMedia': '$hasMedia',
        'title': title,
        'artist': artist,
        'artworkSeed': artworkSeed,
        'hasArtwork': '$hasArtwork',
        'playing': '$playing',
        'shuffle': '$shuffle',
        'repeat': repeat.name,
        'positionMs': '${position.inMilliseconds}',
        'durationMs': '${duration.inMilliseconds}',
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
      other.shuffle == shuffle &&
      other.repeat == repeat &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(hasMedia, title, artist, artworkSeed,
      hasArtwork, playing, shuffle, repeat, position, duration);
}

/// Builds the widget snapshot from playback state, the current song, and the
/// play position at push time.
HomeWidgetState homeWidgetStateFrom(
  PlaybackState state,
  Song? song,
  Duration position,
) {
  if (song == null) return HomeWidgetState.empty;
  return HomeWidgetState(
    hasMedia: true,
    title: song.title,
    artist: song.artist,
    artworkSeed: song.artworkSeed,
    hasArtwork: song.hasArtwork,
    playing: state.playing,
    shuffle: state.shuffleEnabled,
    repeat: state.repeatMode,
    position: position,
    duration: song.duration,
  );
}
