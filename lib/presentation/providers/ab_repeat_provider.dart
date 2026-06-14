import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ABRepeatState {
  const ABRepeatState({this.songId, this.pointA, this.pointB});

  final String? songId;
  final Duration? pointA;
  final Duration? pointB;

  bool get hasA => pointA != null;
  bool get hasB => pointB != null;
  bool get isActive => pointA != null && pointB != null;

  @override
  bool operator ==(Object other) =>
      other is ABRepeatState &&
      other.songId == songId &&
      other.pointA == pointA &&
      other.pointB == pointB;

  @override
  int get hashCode => Object.hash(songId, pointA, pointB);
}

class ABRepeatNotifier extends StateNotifier<ABRepeatState> {
  ABRepeatNotifier() : super(const ABRepeatState());

  void setA(String songId, Duration position) {
    // Changing song resets B so the loop region stays coherent.
    final clearB = songId != state.songId;
    state = ABRepeatState(
      songId: songId,
      pointA: position,
      pointB: clearB ? null : state.pointB,
    );
  }

  void setB(String songId, Duration position) {
    final a = state.songId == songId ? state.pointA : null;
    state = ABRepeatState(songId: songId, pointA: a, pointB: position);
  }

  void clear() => state = const ABRepeatState();

  /// Returns true when [position] has reached or passed point B for [songId].
  /// The caller should seek to [state.pointA] after this returns true.
  bool shouldLoop(String songId, Duration position) {
    if (!isActive || state.songId != songId) return false;
    return position >= state.pointB!;
  }

  bool get isActive => state.isActive;
}

final abRepeatProvider =
    StateNotifierProvider<ABRepeatNotifier, ABRepeatState>(
  (_) => ABRepeatNotifier(),
);
