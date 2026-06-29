import 'dart:math';

import '../models/app_settings.dart';
import '../models/song.dart';

/// Pure math for ReplayGain volume normalisation.
class ReplayGainLogic {
  static const double _fallbackDb = -6.0;
  static const double _maxGainDb = 6.0;
  static const double _minGainDb = -18.0;

  /// Returns the linear gain multiplier to apply for [song] under [mode].
  static double gainFor(Song song, ReplayGainMode mode) {
    final db = switch (mode) {
      ReplayGainMode.off => 0.0,
      ReplayGainMode.track =>
        song.trackGain ?? song.albumGain ?? _fallbackDb,
      ReplayGainMode.album =>
        song.albumGain ?? song.trackGain ?? _fallbackDb,
    };
    final clamped = db.clamp(_minGainDb, _maxGainDb);
    return dbToLinear(clamped);
  }

  /// Converts decibels to a linear amplitude multiplier.
  static double dbToLinear(double db) => pow(10, db / 20).toDouble();

  /// Converts a linear amplitude multiplier to decibels.
  static double linearToDb(double linear) =>
      linear <= 0 ? _minGainDb : 20 * log(linear) / ln10;
}
