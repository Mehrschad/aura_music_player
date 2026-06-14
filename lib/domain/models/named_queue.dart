import 'package:flutter/foundation.dart';

import 'playback.dart';

/// How a queue is treated for resume / speed / silence-skip defaults.
enum QueueKind {
  /// A normal music queue.
  normal,

  /// Resume-on-launch and per-queue speed memory are enabled.
  audiobook,

  /// Like [audiobook], with skip-silence on by default.
  podcast,
}

/// A named, independently-stateful play queue. Only one queue is "live" (driving
/// the audio engine) at a time; the rest are inspectable and editable in the
/// background. Stores song ids (not [Song]s) so it survives library rescans.
@immutable
class NamedQueue {
  const NamedQueue({
    required this.id,
    required this.name,
    required this.songIds,
    this.currentIndex = 0,
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.positionMs = 0,
    this.colorIndex = 0,
    this.kind = QueueKind.normal,
    this.playCount = 0,
    required this.lastTouched,
  });

  final String id;
  final String name;
  final List<String> songIds;

  /// Remembered playback cursor — restored when the queue is made live again.
  final int currentIndex;
  final bool shuffle;
  final RepeatMode repeatMode;
  final int positionMs;

  /// Index into [QueueColors.palette].
  final int colorIndex;
  final QueueKind kind;

  /// How many times this queue has been made live.
  final int playCount;
  final DateTime lastTouched;

  int get length => songIds.length;
  bool get isEmpty => songIds.isEmpty;

  NamedQueue copyWith({
    String? name,
    List<String>? songIds,
    int? currentIndex,
    bool? shuffle,
    RepeatMode? repeatMode,
    int? positionMs,
    int? colorIndex,
    QueueKind? kind,
    int? playCount,
    DateTime? lastTouched,
  }) {
    return NamedQueue(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      currentIndex: currentIndex ?? this.currentIndex,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      positionMs: positionMs ?? this.positionMs,
      colorIndex: colorIndex ?? this.colorIndex,
      kind: kind ?? this.kind,
      playCount: playCount ?? this.playCount,
      lastTouched: lastTouched ?? this.lastTouched,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
        'currentIndex': currentIndex,
        'shuffle': shuffle,
        'repeatMode': repeatMode.index,
        'positionMs': positionMs,
        'colorIndex': colorIndex,
        'kind': kind.index,
        'playCount': playCount,
        'lastTouched': lastTouched.millisecondsSinceEpoch,
      };

  factory NamedQueue.fromJson(Map<String, dynamic> j) => NamedQueue(
        id: j['id'] as String,
        name: j['name'] as String,
        songIds: (j['songIds'] as List).cast<String>(),
        currentIndex: (j['currentIndex'] as int?) ?? 0,
        shuffle: (j['shuffle'] as bool?) ?? false,
        repeatMode: RepeatMode.values[(j['repeatMode'] as int?) ?? 0],
        positionMs: (j['positionMs'] as int?) ?? 0,
        colorIndex: (j['colorIndex'] as int?) ?? 0,
        kind: QueueKind.values[(j['kind'] as int?) ?? 0],
        playCount: (j['playCount'] as int?) ?? 0,
        lastTouched: DateTime.fromMillisecondsSinceEpoch(
            (j['lastTouched'] as int?) ?? 0),
      );

  @override
  bool operator ==(Object other) => other is NamedQueue && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
