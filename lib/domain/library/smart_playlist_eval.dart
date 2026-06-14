import '../models/song.dart';
import 'smart_playlist.dart';

/// Evaluates [sp] against [songs]: filters by the rules (AND/OR), sorts by the
/// chosen field, then applies the limit. Pure — [now] is injectable so date
/// rules are deterministic in tests.
List<Song> evaluateSmartPlaylist(
  SmartPlaylist sp,
  List<Song> songs, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();

  final matched = sp.rules.isEmpty
      ? List<Song>.of(songs)
      : songs.where((s) {
          final results = sp.rules.map((r) => matchRule(r, s, ref));
          return sp.match == RuleMatch.all
              ? results.every((b) => b)
              : results.any((b) => b);
        }).toList();

  matched.sort((a, b) => _compareField(sp.sortField, a, b));
  if (sp.sortDescending) {
    final reversed = matched.reversed.toList();
    matched
      ..clear()
      ..addAll(reversed);
  }

  return _applyLimit(matched, sp.limit);
}

List<Song> _applyLimit(List<Song> songs, SmartLimit limit) {
  switch (limit.kind) {
    case SmartLimitKind.none:
      return songs;
    case SmartLimitKind.songs:
      return songs.take(limit.value).toList();
    case SmartLimitKind.minutes:
      final cap = Duration(minutes: limit.value);
      var total = Duration.zero;
      final out = <Song>[];
      for (final s in songs) {
        if (total + s.duration > cap) break;
        out.add(s);
        total += s.duration;
      }
      return out;
  }
}

/// Whether [song] satisfies a single [rule] (relative to [now] for dates).
bool matchRule(SmartRule rule, Song song, DateTime now) {
  switch (ruleFieldKind(rule.field)) {
    case RuleFieldKind.text:
      return _matchText(_textValue(rule.field, song), rule);
    case RuleFieldKind.integer:
      return _matchNum(_intValue(rule.field, song)?.toDouble(), rule);
    case RuleFieldKind.duration:
      return _matchNum(song.duration.inSeconds.toDouble(), rule);
    case RuleFieldKind.date:
      final date = _dateValue(rule.field, song);
      if (date == null) return false;
      return _matchNum(now.difference(date).inDays.toDouble(), rule);
    case RuleFieldKind.boolean:
      final field = _boolValue(rule.field, song);
      final target = rule.value.toLowerCase() == 'true';
      return rule.op == RuleOperator.isNot ? field != target : field == target;
  }
}

bool _matchText(String? raw, SmartRule rule) {
  final field = (raw ?? '').toLowerCase();
  final v = rule.value.toLowerCase();
  return switch (rule.op) {
    RuleOperator.is_ => field == v,
    RuleOperator.isNot => field != v,
    RuleOperator.contains => field.contains(v),
    RuleOperator.doesNotContain => !field.contains(v),
    RuleOperator.startsWith => field.startsWith(v),
    _ => false,
  };
}

bool _matchNum(double? field, SmartRule rule) {
  if (field == null) return false;
  final v = double.tryParse(rule.value);
  if (v == null && rule.op != RuleOperator.inRange) return false;
  switch (rule.op) {
    case RuleOperator.is_:
      return field == v;
    case RuleOperator.isNot:
      return field != v;
    case RuleOperator.greaterThan:
      return field > v!;
    case RuleOperator.lessThan:
      return field < v!;
    case RuleOperator.inRange:
      final lo = double.tryParse(rule.value);
      final hi = double.tryParse(rule.value2);
      if (lo == null || hi == null) return false;
      return field >= lo && field <= hi;
    default:
      return false;
  }
}

String? _textValue(RuleField f, Song s) => switch (f) {
      RuleField.title => s.title,
      RuleField.artist => s.artist,
      RuleField.album => s.album,
      RuleField.genre => s.genre,
      _ => null,
    };

int? _intValue(RuleField f, Song s) => switch (f) {
      RuleField.year => s.year,
      RuleField.playCount => s.playCount,
      RuleField.rating => s.rating,
      RuleField.bitrate => s.bitrate,
      _ => null,
    };

DateTime? _dateValue(RuleField f, Song s) => switch (f) {
      RuleField.dateAdded => s.dateAdded,
      RuleField.lastPlayed => s.lastPlayed,
      _ => null,
    };

bool _boolValue(RuleField f, Song s) => switch (f) {
      RuleField.hasLyrics => s.hasLyrics,
      RuleField.hasArtwork => s.hasArtwork,
      _ => false,
    };

int _compareField(RuleField field, Song a, Song b) {
  switch (ruleFieldKind(field)) {
    case RuleFieldKind.text:
      return (_textValue(field, a) ?? '')
          .toLowerCase()
          .compareTo((_textValue(field, b) ?? '').toLowerCase());
    case RuleFieldKind.integer:
      return _nullsLast(_intValue(field, a), _intValue(field, b));
    case RuleFieldKind.duration:
      return a.duration.compareTo(b.duration);
    case RuleFieldKind.date:
      return _nullsLast(
        _dateValue(field, a)?.millisecondsSinceEpoch,
        _dateValue(field, b)?.millisecondsSinceEpoch,
      );
    case RuleFieldKind.boolean:
      return (_boolValue(field, a) ? 1 : 0)
          .compareTo(_boolValue(field, b) ? 1 : 0);
  }
}

int _nullsLast(num? a, num? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
