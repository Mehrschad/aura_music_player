/// A versioned, portable snapshot of all user data.
class BackupBundle {
  const BackupBundle({
    required this.formatVersion,
    required this.appVersion,
    required this.createdAtMs,
    required this.sections,
  });

  /// Bump when the on-disk shape changes incompatibly.
  static const int currentFormatVersion = 1;

  final int formatVersion;
  final String appVersion;
  final int createdAtMs;

  /// Section id → arbitrary JSON-serialisable payload for that section.
  final Map<String, dynamic> sections;

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'appVersion': appVersion,
        'createdAt': createdAtMs,
        'sections': sections,
      };

  /// Parses a bundle, throwing [BackupFormatException] on malformed input or
  /// an unsupported (newer) format version.
  static BackupBundle fromJson(Map<String, dynamic> json) {
    final fv = json['formatVersion'];
    if (fv is! int) throw const BackupFormatException('missing formatVersion');
    if (fv > currentFormatVersion) {
      throw const BackupFormatException('unsupported newer backup');
    }
    final sections = json['sections'];
    if (sections is! Map) throw const BackupFormatException('missing sections');
    return BackupBundle(
      formatVersion: fv,
      appVersion: (json['appVersion'] as String?) ?? 'unknown',
      createdAtMs: (json['createdAt'] as int?) ?? 0,
      sections: Map<String, dynamic>.from(sections),
    );
  }

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  /// Number of top-level sections present (for a UI summary).
  int get sectionCount => sections.length;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Stable section ids used as keys inside [BackupBundle.sections].
class BackupSections {
  static const settings = 'settings';
  static const ratings = 'ratings';
  static const bookmarks = 'bookmarks';
  static const favoriteArtists = 'favoriteArtists';
  static const hiddenSongs = 'hiddenSongs';
  static const namedQueues = 'namedQueues';
  static const playHistory = 'playHistory';
}
