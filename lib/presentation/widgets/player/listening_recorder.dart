import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/play_event.dart';
import '../../../domain/models/song.dart';
import '../../providers/playback_providers.dart';
import '../../providers/stats_providers.dart';

/// Invisible widget that turns playback into a [PlayEvent] history.
///
/// It tracks the furthest position reached in the current track; when the track
/// changes it finalises an event for the *outgoing* track — counted as a "play"
/// when at least 50% or 30 s was heard, otherwise a "skip". Mounted once in the
/// shell alongside the playback persistor.
class ListeningRecorder extends ConsumerStatefulWidget {
  const ListeningRecorder({super.key});

  @override
  ConsumerState<ListeningRecorder> createState() => _ListeningRecorderState();
}

class _ListeningRecorderState extends ConsumerState<ListeningRecorder> {
  static const int _minMsForPlay = 30000; // 30 s
  static const double _minFractionForPlay = 0.5;

  int? _index;
  Song? _song;
  int _durationMs = 0;
  int _furthestMs = 0;

  @override
  Widget build(BuildContext context) {
    // Keep the furthest-reached position for the current track.
    ref.listen(positionProvider, (_, next) {
      final pos = next.valueOrNull;
      if (pos == null) return;
      final ms = pos.inMilliseconds;
      if (ms > _furthestMs) _furthestMs = ms;
    });

    // On track change, finalise the outgoing track then arm the new one.
    ref.listen(playbackStateProvider, (_, next) {
      final state = next.valueOrNull;
      if (state == null) return;
      final idx = state.currentIndex;
      if (idx == _index) {
        // Same track — just refresh duration once the engine reports it.
        if (_durationMs == 0) _durationMs = state.duration.inMilliseconds;
        return;
      }
      _finalizeOutgoing();
      _index = idx;
      _song = state.currentSong;
      _durationMs = state.duration.inMilliseconds;
      _furthestMs = 0;
    });

    return const SizedBox.shrink();
  }

  void _finalizeOutgoing() {
    final song = _song;
    if (song == null || _furthestMs <= 0) return;

    final threshold = _durationMs > 0
        ? (_durationMs * _minFractionForPlay).round()
        : _minMsForPlay;
    final completed =
        _furthestMs >= threshold || _furthestMs >= _minMsForPlay;

    ref.read(playHistoryProvider.notifier).record(
          PlayEvent(
            songId: song.id,
            artist: song.artist,
            album: song.album,
            genre: song.genre,
            atMs: DateTime.now().millisecondsSinceEpoch,
            msPlayed: _furthestMs,
            completed: completed,
          ),
        );
  }
}
