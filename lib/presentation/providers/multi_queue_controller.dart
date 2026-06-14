import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/named_queue.dart';
import '../../domain/models/song.dart';
import 'library_providers.dart';
import 'playback_providers.dart';
import 'queue_registry_provider.dart';

/// Ties the [QueueRegistry] to the live [AudioController]: saving the current
/// play queue as a named queue, creating queues from selections, and switching
/// the live queue while preserving each queue's remembered position.
class MultiQueueController {
  MultiQueueController(this._ref);

  final Ref _ref;

  /// Saves the current play queue as a new named queue and makes it the active
  /// pointer. Returns the created queue, or null at the cap / when empty.
  ///
  /// Reads the engine's synchronous [AudioController.state] / [position] rather
  /// than the stream providers, so it is correct even before the first stream
  /// emit (e.g. immediately after a programmatic queue change).
  NamedQueue? saveCurrentAs(String name, {int colorIndex = 0}) {
    final controller = _ref.read(audioControllerProvider);
    final state = controller.state;
    if (state.queue.isEmpty) return null;
    final created = _ref.read(queueRegistryProvider.notifier).create(
          name,
          [for (final s in state.queue) s.id],
          colorIndex: colorIndex,
          currentIndex: state.currentIndex ?? 0,
          shuffle: state.shuffleEnabled,
          repeatMode: state.repeatMode,
          positionMs: controller.position.inMilliseconds,
        );
    if (created != null) {
      _ref.read(activeQueueIdProvider.notifier).state = created.id;
    }
    return created;
  }

  /// Creates a queue from an arbitrary id list (selection, album, artist, …)
  /// without disturbing what is currently playing.
  NamedQueue? createFrom(
    String name,
    List<String> songIds, {
    int colorIndex = 0,
    QueueKind kind = QueueKind.normal,
  }) {
    return _ref.read(queueRegistryProvider.notifier).create(
          name,
          songIds,
          colorIndex: colorIndex,
          kind: kind,
        );
  }

  /// Persists the live cursor back into the active queue (called before
  /// switching away, and on app backgrounding).
  void snapshotActive() {
    final id = _ref.read(activeQueueIdProvider);
    if (id == null) return;
    final controller = _ref.read(audioControllerProvider);
    final state = controller.state;
    _ref.read(queueRegistryProvider.notifier).updateSnapshot(
          id,
          currentIndex: state.currentIndex,
          positionMs: controller.position.inMilliseconds,
          shuffle: state.shuffleEnabled,
          repeatMode: state.repeatMode,
        );
  }

  /// Makes queue [id] live: snapshots the outgoing queue, resolves the target's
  /// song ids against the library, loads it at its remembered position, and
  /// starts playing.
  Future<void> switchTo(String id) async {
    final registry = _ref.read(queueRegistryProvider.notifier);
    final target = registry.byId(id);
    if (target == null || target.isEmpty) return;

    // Save where the outgoing queue was before we replace the engine source.
    snapshotActive();

    final byId = <String, Song>{
      for (final s in _ref.read(effectiveSongsProvider).valueOrNull ?? const [])
        s.id: s,
    };
    final songs = <Song>[
      for (final sid in target.songIds)
        if (byId[sid] != null) byId[sid]!,
    ];
    if (songs.isEmpty) return;

    final startIndex = target.currentIndex.clamp(0, songs.length - 1);
    final controller = _ref.read(audioControllerProvider);

    await controller.restoreQueue(
      songs,
      startIndex: startIndex,
      position: Duration(milliseconds: target.positionMs),
    );
    await controller.setShuffle(target.shuffle);
    await controller.setRepeat(target.repeatMode);
    await controller.play();

    registry.markPlayed(id);
    _ref.read(activeQueueIdProvider.notifier).state = id;
  }
}

final multiQueueControllerProvider = Provider<MultiQueueController>(
  (ref) => MultiQueueController(ref),
);
