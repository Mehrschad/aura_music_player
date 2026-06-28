import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/song.dart';
import '../../domain/taste/smart_collection.dart';
import 'discovery_prefs_provider.dart';
import 'favorites_providers.dart';
import 'library_providers.dart';
import 'stats_providers.dart';
import 'taste_providers.dart';

/// The home's intelligent, *ephemeral* "For You" collections — recomputed live
/// from taste; nothing here is persisted until the user explicitly saves a
/// collection into their playlists.
final smartCollectionsProvider = Provider<List<SmartCollection>>((ref) {
  final library = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  if (library.isEmpty) return const [];

  final profile = ref.watch(tasteProfileProvider);
  // Cold start: stay quiet until we actually know the user's taste. A brand-new
  // install with no listening data shows no "For You" — it appears once enough
  // completed plays have accumulated.
  if (profile.playCount < kMinPlaysForRecommendations) return const [];

  final recommendations = ref.watch(recommendationsProvider);
  final history = ref.watch(playHistoryProvider);
  final favorites = ref.watch(favoritesProvider);

  final built = buildSmartCollections(
    library: library,
    profile: profile,
    recommendations: recommendations,
    history: history,
    favoriteIds: favorites,
  );

  // Drop collections the user has hidden from the home.
  final hidden = ref.watch(hiddenCollectionsProvider);
  if (hidden.isEmpty) return built;
  return [for (final c in built) if (!hidden.contains(c.id)) c];
});
