import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sample_cover_art_repository.dart';
import '../../domain/repositories/cover_art_repository.dart';

/// The active cover-art source. Override with `MusicBrainzCoverArtRepository()`
/// on device.
final coverArtRepositoryProvider = Provider<CoverArtRepository>(
  (ref) => const SampleCoverArtRepository(),
);

/// Cover-art candidates for an (artist, album) pair.
final coverArtSearchProvider = FutureProvider.family<List<CoverArtResult>,
    ({String artist, String album})>((ref, q) {
  return ref
      .watch(coverArtRepositoryProvider)
      .search(artist: q.artist, album: q.album);
});
