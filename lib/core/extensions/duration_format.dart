/// Human-readable duration formatting used across the player and library.
extension DurationFormat on Duration {
  /// `3:24`, or `1:02:09` when an hour or longer. Always shows two-digit
  /// seconds (and two-digit minutes when an hour is present).
  String get clock {
    final totalSeconds = inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final mm = minutes.toString().padLeft(2, '0');
      return '$hours:$mm:$ss';
    }
    return '$minutes:$ss';
  }

  /// Compact human form for totals: `45s`, `12m`, `3h`, `3h 20m`, `2d 4h`.
  String get humanized {
    final totalMinutes = inMinutes;
    if (totalMinutes < 1) return '${inSeconds}s';
    if (totalMinutes < 60) return '${totalMinutes}m';
    final hours = totalMinutes ~/ 60;
    if (hours < 24) {
      final m = totalMinutes % 60;
      return m == 0 ? '${hours}h' : '${hours}h ${m}m';
    }
    final days = hours ~/ 24;
    final h = hours % 24;
    return h == 0 ? '${days}d' : '${days}d ${h}h';
  }
}
