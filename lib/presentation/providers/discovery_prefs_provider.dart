import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tiny mutable set-of-ids notifier (session-scoped, mirroring the existing
/// favourites store) used for the discovery preferences below.
class IdSetNotifier extends StateNotifier<Set<String>> {
  IdSetNotifier() : super(const {});

  void add(String id) => state = {...state, id};
  void remove(String id) => state = Set<String>.of(state)..remove(id);
  bool contains(String id) => state.contains(id);
}

/// Smart-collection ids the user has dismissed from the home ("Hide"). Filtered
/// out of [smartCollectionsProvider]. Session-scoped.
final hiddenCollectionsProvider =
    StateNotifierProvider<IdSetNotifier, Set<String>>(
  (ref) => IdSetNotifier(),
);

/// Song ids the user marked "Not interested". These are excluded from
/// recommendations and feed a negative signal into the taste profile (their
/// artists are down-weighted), so the engine learns from the rejection.
final notInterestedProvider =
    StateNotifierProvider<IdSetNotifier, Set<String>>(
  (ref) => IdSetNotifier(),
);

/// Familiar ↔ new bias for recommendations: 0 = lean familiar, 0.5 = balanced,
/// 1 = lean discovery. Driven by the home's balance slider. Session-scoped.
final discoveryBalanceProvider = StateProvider<double>((ref) => 0.5);
