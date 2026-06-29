import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/library/selection_logic.dart';

/// Stable list identifiers, so each list keeps its own selection scope.
abstract final class SelectionScopes {
  const SelectionScopes._();
  static const String library = 'library';
  static const String search = 'search';
  static const String album = 'album';
  static const String artist = 'artist';
  static const String playlist = 'playlist';
}

/// Immutable snapshot of a list's selection: whether selection mode is engaged,
/// which item ids are picked, and the anchor used for range-select.
@immutable
class SelectionState {
  const SelectionState({
    this.active = false,
    this.ids = const <String>{},
    this.anchor,
  });

  /// True once the user enters selection mode (long-press), even with one item.
  final bool active;

  /// The chosen item ids (song ids, in our lists).
  final Set<String> ids;

  /// Last individually-touched id; the pivot for "select range".
  final String? anchor;

  int get count => ids.length;
  bool get isEmpty => ids.isEmpty;
  bool contains(String id) => ids.contains(id);

  @override
  bool operator ==(Object other) =>
      other is SelectionState &&
      other.active == active &&
      other.anchor == anchor &&
      setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(active, anchor, Object.hashAllUnordered(ids));
}

/// Generic, pure multi-select controller. Holds the selection for one list and
/// exposes the gestures the UI drives: enter, toggle, range-select, select-all,
/// invert, clear. No Flutter or platform dependency — fully unit-testable.
class SelectionController extends StateNotifier<SelectionState> {
  SelectionController() : super(const SelectionState());

  /// Enters selection mode with [id] as the first (and anchor) item.
  void enter(String id) =>
      state = SelectionState(active: true, ids: {id}, anchor: id);

  /// Flips [id]'s membership. Outside selection mode this enters it. When the
  /// last item is removed, selection mode exits.
  void toggle(String id) {
    if (!state.active) {
      enter(id);
      return;
    }
    final next = Set<String>.of(state.ids);
    if (!next.remove(id)) next.add(id);
    if (next.isEmpty) {
      state = const SelectionState();
    } else {
      state = SelectionState(active: true, ids: next, anchor: id);
    }
  }

  /// Adds every id between the current anchor and [targetId] (inclusive), in
  /// the list's [orderedIds] order. Without an anchor it behaves like [toggle].
  void selectRange(List<String> orderedIds, String targetId) {
    final anchor = state.anchor;
    if (!state.active || anchor == null) {
      toggle(targetId);
      return;
    }
    final range = idsInRange(orderedIds, anchor, targetId);
    state = SelectionState(
      active: true,
      ids: {...state.ids, ...range},
      anchor: targetId,
    );
  }

  /// Selects all of [allIds] (entering selection mode if needed).
  void selectAll(Iterable<String> allIds) {
    final ids = allIds.toSet();
    if (ids.isEmpty) {
      state = const SelectionState();
      return;
    }
    state = SelectionState(active: true, ids: ids, anchor: state.anchor);
  }

  /// Inverts the selection against [allIds]. Emptying it exits selection mode.
  void invert(Iterable<String> allIds) {
    final next = <String>{
      for (final id in allIds)
        if (!state.ids.contains(id)) id,
    };
    if (next.isEmpty) {
      state = const SelectionState();
    } else {
      state = SelectionState(active: true, ids: next, anchor: state.anchor);
    }
  }

  /// Leaves selection mode and drops every pick.
  void clear() => state = const SelectionState();
}

/// One [SelectionController] per list id (see [SelectionScopes]). Selection
/// survives tab switches because the family keeps the notifier alive until it's
/// explicitly cleared.
final selectionProvider =
    StateNotifierProvider.family<SelectionController, SelectionState, String>(
  (ref, listId) => SelectionController(),
);
