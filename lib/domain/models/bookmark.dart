import 'package:flutter/foundation.dart';

/// A position marker for a song, stored by the user.
@immutable
class Bookmark {
  const Bookmark({
    required this.songId,
    required this.positionMs,
    this.label = '',
  });

  final String songId;
  final int positionMs;
  final String label;

  Duration get position => Duration(milliseconds: positionMs);

  Bookmark copyWith({String? label}) => Bookmark(
        songId: songId,
        positionMs: positionMs,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {
        's': songId,
        'p': positionMs,
        'l': label,
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        songId: j['s'] as String,
        positionMs: j['p'] as int,
        label: (j['l'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is Bookmark &&
      other.songId == songId &&
      other.positionMs == positionMs;

  @override
  int get hashCode => Object.hash(songId, positionMs);
}
