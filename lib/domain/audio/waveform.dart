import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A normalised waveform: amplitudes in `[0, 1]`, one per sample.
@immutable
class WaveformData {
  const WaveformData(this.amplitudes);

  final List<double> amplitudes;

  bool get isEmpty => amplitudes.isEmpty;
}

/// Generates a deterministic, plausible waveform for a track from its [seed]
/// (the song/album id).
///
/// This stands in for real PCM analysis: on device, a decode pass (or a
/// waveform-extraction package) replaces this with amplitudes sampled from the
/// actual audio, while the scrubber and painter stay unchanged. Until then this
/// gives every track a *stable* shape — the same seed always produces the same
/// waveform, so it never flickers between rebuilds — with a gentle centre-weighted
/// envelope so it reads as a real song rather than uniform noise.
WaveformData generateWaveform(String seed, {int resolution = 240}) {
  assert(resolution > 0);
  // Simple LCG seeded from the id; deterministic within a run.
  var s = (seed.hashCode & 0x7fffffff);
  double next() {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return s / 0x7fffffff;
  }

  final amps = List<double>.filled(resolution, 0);
  for (var i = 0; i < resolution; i++) {
    final t = i / resolution;
    // Centre-weighted envelope: quieter intro/outro, fuller middle.
    final envelope = 0.45 + 0.55 * math.sin(math.pi * t);
    final noise = 0.35 + 0.65 * next();
    amps[i] = (noise * envelope).clamp(0.06, 1.0);
  }
  return WaveformData(amps);
}

/// Resamples [src] amplitudes to exactly [count] buckets by averaging, so a
/// fixed-resolution waveform can be drawn at whatever bar count the available
/// width allows while keeping a track's overall shape recognisable.
List<double> resampleAmplitudes(List<double> src, int count) {
  if (count <= 0 || src.isEmpty) return const [];
  if (src.length == count) return List<double>.of(src);

  final out = List<double>.filled(count, 0);
  for (var i = 0; i < count; i++) {
    final start = (i * src.length / count).floor();
    final end = ((i + 1) * src.length / count).ceil().clamp(1, src.length);
    var sum = 0.0;
    var n = 0;
    for (var j = start; j < end; j++) {
      sum += src[j];
      n++;
    }
    out[i] = n == 0 ? src[start.clamp(0, src.length - 1)] : sum / n;
  }
  return out;
}
