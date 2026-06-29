/// Fields a smart rule can test, per the spec.
enum RuleField {
  title,
  artist,
  album,
  genre,
  year,
  duration,
  playCount,
  rating,
  lastPlayed,
  dateAdded,
  bitrate,
  hasLyrics,
  hasArtwork,
}

/// The value kind a [RuleField] holds, which determines the applicable
/// operators and how the rule value is parsed.
enum RuleFieldKind { text, integer, duration, date, boolean }

RuleFieldKind ruleFieldKind(RuleField f) => switch (f) {
      RuleField.title ||
      RuleField.artist ||
      RuleField.album ||
      RuleField.genre =>
        RuleFieldKind.text,
      RuleField.year ||
      RuleField.playCount ||
      RuleField.rating ||
      RuleField.bitrate =>
        RuleFieldKind.integer,
      RuleField.duration => RuleFieldKind.duration,
      RuleField.lastPlayed || RuleField.dateAdded => RuleFieldKind.date,
      RuleField.hasLyrics || RuleField.hasArtwork => RuleFieldKind.boolean,
    };

enum RuleOperator {
  is_,
  isNot,
  contains,
  doesNotContain,
  startsWith,
  greaterThan,
  lessThan,
  inRange,
}

/// Operators valid for a field kind (also drives the editor's operator menu).
List<RuleOperator> operatorsFor(RuleFieldKind kind) => switch (kind) {
      RuleFieldKind.text => const [
          RuleOperator.is_,
          RuleOperator.isNot,
          RuleOperator.contains,
          RuleOperator.doesNotContain,
          RuleOperator.startsWith,
        ],
      RuleFieldKind.integer ||
      RuleFieldKind.duration ||
      RuleFieldKind.date =>
        const [
          RuleOperator.is_,
          RuleOperator.isNot,
          RuleOperator.greaterThan,
          RuleOperator.lessThan,
          RuleOperator.inRange,
        ],
      RuleFieldKind.boolean => const [RuleOperator.is_, RuleOperator.isNot],
    };

/// Whether to match all rules (AND) or any (OR).
enum RuleMatch { all, any }

enum SmartLimitKind { none, songs, minutes }

class SmartLimit {
  const SmartLimit({required this.kind, this.value = 0});
  static const SmartLimit none = SmartLimit(kind: SmartLimitKind.none);

  final SmartLimitKind kind;
  final int value;
}

/// A single rule: [field] [op] [value] (with [value2] for `inRange`).
///
/// Date fields compare against an *age in days* (e.g. `dateAdded lessThan 30`
/// = added within the last 30 days); duration is in seconds.
class SmartRule {
  const SmartRule({
    required this.field,
    required this.op,
    this.value = '',
    this.value2 = '',
  });

  final RuleField field;
  final RuleOperator op;
  final String value;
  final String value2;

  SmartRule copyWith({
    RuleField? field,
    RuleOperator? op,
    String? value,
    String? value2,
  }) =>
      SmartRule(
        field: field ?? this.field,
        op: op ?? this.op,
        value: value ?? this.value,
        value2: value2 ?? this.value2,
      );
}

/// A rule-based, auto-updating playlist definition.
class SmartPlaylist {
  const SmartPlaylist({
    required this.id,
    required this.name,
    this.match = RuleMatch.all,
    this.rules = const [],
    this.sortField = RuleField.title,
    this.sortDescending = false,
    this.limit = SmartLimit.none,
  });

  final String id;
  final String name;
  final RuleMatch match;
  final List<SmartRule> rules;
  final RuleField sortField;
  final bool sortDescending;
  final SmartLimit limit;

  SmartPlaylist copyWith({
    String? name,
    RuleMatch? match,
    List<SmartRule>? rules,
    RuleField? sortField,
    bool? sortDescending,
    SmartLimit? limit,
  }) =>
      SmartPlaylist(
        id: id,
        name: name ?? this.name,
        match: match ?? this.match,
        rules: rules ?? this.rules,
        sortField: sortField ?? this.sortField,
        sortDescending: sortDescending ?? this.sortDescending,
        limit: limit ?? this.limit,
      );
}
