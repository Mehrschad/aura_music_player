import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/widgets/home_widget_sync.dart';
import '../../domain/widgets/home_widget_state.dart';
import '../../domain/widgets/media_browser_tree.dart';
import 'library_providers.dart';
import 'playback_providers.dart';

/// The active widget sync. Override with `HomeWidgetPlugin()` on device.
final homeWidgetSyncProvider =
    Provider<HomeWidgetSync>((ref) => const NoopHomeWidgetSync());

/// The live home-widget state, derived from playback. Recomputes as the track,
/// play state or position changes; equality means only real changes propagate.
final homeWidgetStateProvider = Provider<HomeWidgetState>((ref) {
  final song = ref.watch(currentSongProvider);
  final state = ref.watch(playbackStateProvider).valueOrNull;
  if (song == null || state == null) return HomeWidgetState.empty;
  final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
  return homeWidgetStateFrom(song: song, state: state, position: position);
});

/// Children of a media-browser node, evaluated against the (edit-aware) library
/// — the content an `audio_service` handler serves to Android Auto.
final mediaBrowserChildrenProvider =
    Provider.family<List<MediaNode>, String>((ref, parentId) {
  final songs = ref.watch(effectiveSongsProvider).valueOrNull ?? const [];
  return mediaChildren(parentId, songs);
});
