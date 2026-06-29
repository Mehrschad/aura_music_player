/// Pure math for crossfade volume ramping.
class CrossfadeLogic {
  /// Returns true when the current position is inside the fade-out window.
  static bool inFadeOut(
      Duration position, Duration duration, double crossfadeSeconds) {
    if (crossfadeSeconds <= 0) return false;
    final remaining = duration - position;
    return remaining.inMilliseconds <=
            (crossfadeSeconds * 1000).round() &&
        remaining >= Duration.zero;
  }

  /// Gain [0..1] for the fade-out: 1.0 at window start, 0.0 at window end.
  static double fadeOutGain(Duration remaining, double crossfadeSeconds) {
    if (crossfadeSeconds <= 0) return 1.0;
    final fraction =
        remaining.inMilliseconds / (crossfadeSeconds * 1000);
    return fraction.clamp(0.0, 1.0);
  }
}
