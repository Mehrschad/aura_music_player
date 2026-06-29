import '../models/equalizer.dart';

/// Gains (dB) for each built-in preset — one value per band in [kEqBands].
const Map<EqPreset, List<double>> _presetGains = {
  EqPreset.flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  EqPreset.bassBoost: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
  EqPreset.vocalClarity: [-2, -1, 0, 2, 4, 4, 3, 2, 0, -1],
  EqPreset.electronic: [5, 4, 1, 0, -2, 2, 1, 1, 4, 5],
  EqPreset.acoustic: [4, 3, 2, 0, 1, 1, 2, 3, 3, 2],
  EqPreset.hipHop: [6, 5, 2, 3, -1, -1, 1, 0, 1, 2],
  EqPreset.classical: [4, 3, 2, 1, -1, -1, 0, 2, 3, 4],
  EqPreset.rock: [5, 4, 2, -1, -2, 0, 2, 3, 4, 5],
  // Hi-Fi: air shelf (+2 dB @ 16 kHz), presence (+1 dB @ 4 kHz), gentle bass
  // warmth (+1 dB @ 64 Hz), slight mud cut (−0.5 dB @ 500 Hz).
  // All gains ≤ 2 dB — zero risk of clipping or tonal damage.
  EqPreset.hifi: [0.0, 1.0, 0.5, 0.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0],
};

List<double> presetGains(EqPreset preset) => List<double>.of(_presetGains[preset]!);

/// Clamps a gain to the valid [kEqMinGain, kEqMaxGain] range.
double clampGain(double db) => db.clamp(kEqMinGain, kEqMaxGain);

/// The preset whose gains exactly match [gains], or null ("Custom").
EqPreset? matchPreset(List<double> gains) {
  for (final entry in _presetGains.entries) {
    if (_listClose(entry.value, gains)) return entry.key;
  }
  return null;
}

bool _listClose(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 0.01) return false;
  }
  return true;
}

/// Interpolated gain (dB) at normalised position [t] (0 = first band, 1 = last)
/// across the band points. Linear between adjacent bands. Used by the curve
/// painter to draw a smooth response and unit-tested in isolation.
double eqGainAt(List<double> gains, double t) {
  if (gains.isEmpty) return 0;
  if (gains.length == 1) return gains.first;
  final clamped = t.clamp(0.0, 1.0);
  final pos = clamped * (gains.length - 1);
  final i = pos.floor();
  if (i >= gains.length - 1) return gains.last;
  final frac = pos - i;
  return gains[i] + (gains[i + 1] - gains[i]) * frac;
}
