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
  final visible = hidden.isEmpty
      ? List<SmartCollection>.of(built)
      : [for (final c in built) if (!hidden.contains(c.id)) c];

  // Context-aware: float the mood that fits the current hour up behind "Your
  // Mix", so the rail reads as "right now" — morning leans Focus, midday and
  // evening lean Energetic, late night leans Chill.
  return _contextReorder(visible);
});

List<SmartCollection> _contextReorder(List<SmartCollection> list) {
  if (list.length < 3) return list;
  final hour = DateTime.now().hour;
  final preferred = (hour >= 5 && hour < 11)
      ? 'mood_focus'
      : (hour >= 22 || hour < 5)
          ? 'mood_chill'
          : 'mood_energetic';
  final idx = list.indexWhere((c) => c.id == preferred);
  if (idx > 1) {
    final c = list.removeAt(idx);
    list.insert(1, c);
  }
  return list;
}
