import 'package:flutter/foundation.dart';

import '../models/lyrics.dart';

/// Formats a duration as an LRC timestamp `mm:ss.xx` (centiseconds).
String formatLrcTimestamp(Duration d) {
  final clamped = d < Duration.zero ? Duration.zero : d;
  final m = clamped.inMinutes;
  final s = clamped.inSeconds % 60;
  final cs = (clamped.inMilliseconds % 1000) ~/ 10;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(m)}:${two(s)}.${two(cs)}';
}

/// Parses an `mm:ss.xx` / `mm:ss` timestamp back to a [Duration], or null if
/// malformed. Used by the manual timestamp editor.
Duration? parseLrcTimestamp(String input) {
  final m = RegExp(r'^(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?$')
      .firstMatch(input.trim());
  if (m == null) return null;
  final minutes = int.parse(m.group(1)!);
  final seconds = int.parse(m.group(2)!);
  if (seconds > 59) return null;
  final frac = m.group(3);
  var ms = 0;
  if (frac != null && frac.isNotEmpty) {
    ms = frac.length == 2
        ? int.parse(frac) * 10
        : int.parse(frac.padRight(3, '0').substring(0, 3));
  }
  return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
}

/// One line being synced: its [text] and the [time] stamped for it (null until
/// stamped).
@immutable
class SyncEntry {
  const SyncEntry({required this.text, this.time});

  final String text;
  final Duration? time;

  SyncEntry copyWith({Object? time = _sentinel}) => SyncEntry(
        text: text,
        time: identical(time, _sentinel) ? this.time : time as Duration?,
      );

  static const Object _sentinel = Object();
}

/// An immutable tap-to-sync draft. All mutating operations return a new draft,
/// so the logic is pure and unit-testable; the editor screen holds one and
/// rebuilds.
@immutable
class SyncDraft {
  const SyncDraft({required this.entries, required this.cursor});

  /// Builds an empty draft from raw line texts (blank lines dropped).
  factory SyncDraft.fromTexts(List<String> texts) {
    final entries = [
      for (final t in texts)
        if (t.trim().isNotEmpty) SyncEntry(text: t.trim()),
    ];
    return SyncDraft(entries: entries, cursor: 0);
  }

  /// Seeds from existing lyrics, pre-filling any times already present (so a
  /// synced file can be re-synced from where it is).
  factory SyncDraft.fromLyrics(Lyrics lyrics) {
    final entries = [
      for (final l in lyrics.lines)
        SyncEntry(text: l.text, time: lyrics.synced ? l.time : null),
    ];
    // Cursor points at the first unstamped line.
    final firstUnset = entries.indexWhere((e) => e.time == null);
    return SyncDraft(
        entries: entries, cursor: firstUnset == -1 ? entries.length : firstUnset);
  }

  final List<SyncEntry> entries;

  /// Index of the next line to stamp.
  final int cursor;

  bool get isComplete =>
      entries.isNotEmpty && entries.every((e) => e.time != null);

  bool get hasStarted => entries.any((e) => e.time != null);

  SyncEntry? get currentEntry =>
      cursor >= 0 && cursor < entries.length ? entries[cursor] : null;

  SyncDraft _with(List<SyncEntry> next, int nextCursor) =>
      SyncDraft(entries: next, cursor: nextCursor.clamp(0, next.length));

  /// Stamps the cursor line with [time] and advances to the next line.
  SyncDraft stamp(Duration time) {
    if (cursor < 0 || cursor >= entries.length) return this;
    final next = List<SyncEntry>.of(entries);
    next[cursor] = next[cursor].copyWith(time: _clamp(time));
    return _with(next, cursor + 1);
  }

  /// Clears the most recently stamped line and steps the cursor back to it.
  SyncDraft undo() {
    final target = cursor - 1;
    if (target < 0 || target >= entries.length) return this;
    final next = List<SyncEntry>.of(entries);
    next[target] = next[target].copyWith(time: null);
    return _with(next, target);
  }

  /// Re-stamps a specific line without disturbing the cursor.
  SyncDraft setTime(int index, Duration time) {
    if (index < 0 || index >= entries.length) return this;
    final next = List<SyncEntry>.of(entries);
    next[index] = next[index].copyWith(time: _clamp(time));
    return _with(next, cursor);
  }

  /// How many lines carry a timestamp.
  int get stampedCount => entries.where((e) => e.time != null).length;

  /// Clears one line's timestamp without moving the cursor, so a mis-stamped
  /// line can be dropped and redone without unwinding everything after it.
  SyncDraft clearTime(int index) {
    if (index < 0 || index >= entries.length) return this;
    final next = List<SyncEntry>.of(entries);
    next[index] = next[index].copyWith(time: null);
    return _with(next, cursor);
  }

  /// The stamped line playing at [position] — the last one stamped at or
  /// before it, or -1 before the first stamp. Drives the tune list's highlight
  /// and follow-scroll.
  int activeIndexAt(Duration position) {
    var best = -1;
    Duration? bestTime;
    for (var i = 0; i < entries.length; i++) {
      final t = entries[i].time;
      if (t == null || t > position) continue;
      if (bestTime == null || t >= bestTime) {
        bestTime = t;
        best = i;
      }
    }
    return best;
  }

  /// Shifts one line's time by [delta] (used for the fine-tune nudges).
  SyncDraft shiftLine(int index, Duration delta) {
    final entry = (index >= 0 && index < entries.length) ? entries[index] : null;
    if (entry?.time == null) return this;
    return setTime(index, entry!.time! + delta);
  }

  /// Shifts every stamped line by [delta] (global "shift all" offset).
  SyncDraft shiftAll(Duration delta) {
    final next = [
      for (final e in entries)
        e.time == null ? e : e.copyWith(time: _clamp(e.time! + delta)),
    ];
    return _with(next, cursor);
  }

  SyncDraft resetTimes() =>
      _with([for (final e in entries) e.copyWith(time: null)], 0);

  /// Emits LRC for the stamped lines, in time order.
  String toLrc() {
    final timed = [
      for (final e in entries)
        if (e.time != null) e,
    ]..sort((a, b) => a.time!.compareTo(b.time!));
    final buffer = StringBuffer();
    for (final e in timed) {
      buffer
        ..write('[')
        ..write(formatLrcTimestamp(e.time!))
        ..write(']')
        ..write(e.text)
        ..write('\n');
    }
    return buffer.toString();
  }

  static Duration _clamp(Duration d) => d < Duration.zero ? Duration.zero : d;
}
