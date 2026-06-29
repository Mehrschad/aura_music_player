import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/platform/playback_persistence.dart';
import '../../../domain/models/playback.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_providers.dart';
import '../../providers/playback_persistence_provider.dart';
import '../../providers/playback_providers.dart';

/// Invisible bridge that remembers the last playback session and restores it on
/// the next cold start.
///
/// • **Save** — on every meaningful player change, on a slow heartbeat while
///   playing (to capture the moving position), and when the app is backgrounded.
/// • **Restore** — once the library finishes scanning, if nothing is already
///   playing, it re-resolves the saved song ids and loads them **paused** at the
///   exact track and position the user left off, with shuffle/repeat reapplied.
class PlaybackPersistor extends ConsumerStatefulWidget {
  const PlaybackPersistor({super.key});

  @override
  ConsumerState<PlaybackPersistor> createState() => _PlaybackPersistorState();
}

class _PlaybackPersistorState extends ConsumerState<PlaybackPersistor>
    with WidgetsBindingObserver {
  bool _restored = false;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    // When persistence isn't wired (tests, unsupported platforms) stay fully
    // inert: no observer, no timer — nothing to clean up, nothing to persist.
    if (ref.read(playbackPersistenceProvider) == null) return;
    WidgetsBinding.instance.addObserver(this);
    // Slow heartbeat: keeps the saved position roughly current while playing,
    // without writing on every position tick.
    _heartbeat = Timer.periodic(const Duration(seconds: 8), (_) {
      if (ref.read(hasMediaProvider)) _save();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The reliable moment to capture the latest position before we might be
    // killed in the background.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _save();
    }
  }

  void _save() {
    final persistence = ref.read(playbackPersistenceProvider);
    if (persistence == null) return;
    final s = ref.read(playbackStateProvider).valueOrNull;
    if (s == null || s.currentIndex == null || s.queue.isEmpty) return;
    final pos = ref.read(audioControllerProvider).position;
    persistence.save(PlaybackSnapshot(
      songIds: [for (final song in s.queue) song.id],
      index: s.currentIndex!,
      positionMs: pos.inMilliseconds,
      shuffle: s.shuffleEnabled,
      repeat: s.repeatMode,
    ));
  }

  Future<void> _maybeRestore(List<Song> library) async {
    if (_restored) return;
    _restored = true;

    final persistence = ref.read(playbackPersistenceProvider);
    if (persistence == null) return;
    // Never clobber a session that's already started (deep link, headset, etc.).
    if (ref.read(hasMediaProvider)) return;

    final snap = persistence.load();
    if (snap == null) return;

    final byId = {for (final s in library) s.id: s};
    final songs = [
      for (final id in snap.songIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (songs.isEmpty) return;

    // Re-map the saved index onto the surviving songs (some files may be gone).
    var index = snap.index.clamp(0, songs.length - 1);
    if (snap.index >= 0 && snap.index < snap.songIds.length) {
      final currentId = snap.songIds[snap.index];
      final mapped = songs.indexWhere((s) => s.id == currentId);
      if (mapped >= 0) index = mapped;
    }

    final ctrl = ref.read(audioControllerProvider);
    await ctrl.restoreQueue(
      songs,
      startIndex: index,
      position: Duration(milliseconds: snap.positionMs),
    );
    if (snap.shuffle) await ctrl.setShuffle(true);
    if (snap.repeat != RepeatMode.off) await ctrl.setRepeat(snap.repeat);
  }

  @override
  Widget build(BuildContext context) {
    // Persist whenever the track / queue / play state / modes change.
    ref.listen<AsyncValue<PlaybackState>>(playbackStateProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null && s.currentIndex != null) _save();
    });

    // Restore as soon as the library is available.
    ref.listen<AsyncValue<List<Song>>>(songsProvider, (_, next) {
      final lib = next.valueOrNull;
      if (lib != null && lib.isNotEmpty) _maybeRestore(lib);
    });

    // Cover the case where the scan finished before this widget mounted.
    final lib = ref.watch(songsProvider).valueOrNull;
    if (lib != null && lib.isNotEmpty && !_restored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeRestore(lib);
      });
    }

    return const SizedBox.shrink();
  }
}
