import 'package:flutter/foundation.dart';

import 'song.dart';

/// Repeat behaviour for the queue.
enum RepeatMode {
  /// Stop after the last track.
  off,

  /// Loop the whole queue.
  all,

  /// Loop the current track.
  one,
}

/// The engine's processing state, abstracted away from any specific backend
/// (mirrors just_audio's ProcessingState without leaking the dependency).
enum PlaybackStatus { idle, loading, ready, completed }

/// An immutable snapshot of everything the UI needs to render the player,
/// *except* the play position — which changes several times a second and rides
/// its own stream so it never forces a full player rebuild.
@immutable
class PlaybackState {
  const PlaybackState({
    this.queue = const [],
    this.currentIndex,
    this.playing = false,
    this.status = PlaybackStatus.idle,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.duration = Duration.zero,
  });

  /// The active queue, in its original (un-shuffled) order.
  final List<Song> queue;

  /// Index into [queue] of the current track, or null when nothing is loaded.
  final int? currentIndex;

  final bool playing;
  final PlaybackStatus status;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  /// Duration of the current track (the engine's reported duration, which may
  /// refine the tag-reported value once decoding starts).
  final Duration duration;

  static const PlaybackState empty = PlaybackState();

  Song? get currentSong {
    final i = currentIndex;
    if (i == null || i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  bool get hasMedia => currentSong != null;

  bool get hasNext {
    final i = currentIndex;
    if (i == null) return false;
    return repeatMode == RepeatMode.all || i < queue.length - 1;
  }

  bool get hasPrevious {
    final i = currentIndex;
    if (i == null) return false;
    return repeatMode == RepeatMode.all || i > 0;
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.currentIndex == currentIndex &&
      other.playing == playing &&
      other.status == status &&
      other.shuffleEnabled == shuffleEnabled &&
      other.repeatMode == repeatMode &&
      other.duration == duration &&
      listEquals(other.queue, queue);

  @override
  int get hashCode => Object.hash(
        currentIndex,
        playing,
        status,
        shuffleEnabled,
        repeatMode,
        duration,
        Object.hashAll(queue),
      );
}
