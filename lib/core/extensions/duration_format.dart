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
}
