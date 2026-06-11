import 'package:flutter/foundation.dart';

/// The ten band centre frequencies (Hz), per the spec's visual EQ.
const List<int> kEqBands = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

/// Gain range, in decibels.
const double kEqMinGain = -12;
const double kEqMaxGain = 12;

/// Bass-boost range, in millibels.
const int kBassBoostMax = 1000;

/// Short labels for the band frequencies (e.g. 32, 1K, 16K).
String eqBandLabel(int hz) => hz >= 1000 ? '${hz ~/ 1000}K' : '$hz';

/// Built-in equalizer presets.
enum EqPreset {
  flat,
  bassBoost,
  vocalClarity,
  electronic,
  acoustic,
  hipHop,
  classical,
  rock,
  /// Subtle high-fidelity enhancement: gentle air shelf, presence boost, and
  /// bass warmth. Designed to improve perceived quality without colouring the
  /// sound — safe on all headphones and speakers.
  hifi,
}

/// Immutable equalizer state: per-band gains (dB), bass boost (mB), stereo
/// width (0 = off … 1 = max), and an on/off flag.
@immutable
class EqualizerSettings {
  const EqualizerSettings({
    this.enabled = false,
    this.gains = _zeros,
    this.bassBoost = 0,
    this.stereoWidth = 0,
  });

  static const List<double> _zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  static const EqualizerSettings initial = EqualizerSettings();

  final bool enabled;
  final List<double> gains;
  final int bassBoost;
  final double stereoWidth;

  EqualizerSettings copyWith({
    bool? enabled,
    List<double>? gains,
    int? bassBoost,
    double? stereoWidth,
  }) {
    return EqualizerSettings(
      enabled: enabled ?? this.enabled,
      gains: gains ?? this.gains,
      bassBoost: bassBoost ?? this.bassBoost,
      stereoWidth: stereoWidth ?? this.stereoWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EqualizerSettings &&
      other.enabled == enabled &&
      other.bassBoost == bassBoost &&
      other.stereoWidth == stereoWidth &&
      listEquals(other.gains, gains);

  @override
  int get hashCode =>
      Object.hash(enabled, bassBoost, stereoWidth, Object.hashAll(gains));
}
