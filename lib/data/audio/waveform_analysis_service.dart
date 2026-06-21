import 'dart:io';

import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

/// Extracts a loudness envelope from a local audio file and derives a **beat
/// grid** from it via energy-flux onset detection. The Now Playing ambient
/// lights pulse on each detected beat, so a fast track throbs fast and a slow
/// one slow — read from the real audio, not an (often wrong) BPM tag.
///
/// Pipeline (all on-device, no network / paid API):
///  1. [JustWaveform.extract] decodes the file to a normalised amplitude
///     envelope at ~50 samples/second (MediaCodec on Android).
///  2. [_detectBeats] runs half-wave-rectified energy-flux onset detection with
///     an adaptive threshold to find beat timestamps (ms).
///
/// Callers:
///  • Call [analyze] once per song (fire-and-forget) to populate the cache.
///  • Read [getCachedBeats] synchronously each frame; it returns [null] until
///    extraction finishes, so callers fall back gracefully (a paused, calm look).
class WaveformAnalysisService {
  final Map<String, List<int>> _beats = {};
  final Set<String> _pending = {};

  /// Sampling resolution. 50 px/s → one amplitude sample every 20 ms, fine
  /// enough to time onsets to within a frame while keeping extraction quick.
  static const int _pixelsPerSecond = 50;
  static const double _msPerSample = 1000.0 / _pixelsPerSecond;

  /// Returns the cached beat timestamps (ms, ascending) for [songId], or [null]
  /// if analysis has not finished (or failed).
  List<int>? getCachedBeats(String songId) => _beats[songId];

  /// Analyses [filePath] in the background and caches its beat grid. Safe to
  /// call repeatedly for the same [songId]: in-flight duplicates are ignored and
  /// completed ones return immediately from cache. Never throws.
  Future<void> analyze(String songId, String filePath) async {
    if (_beats.containsKey(songId) || _pending.contains(songId)) return;
    _pending.add(songId);

    try {
      final tmpDir = await getTemporaryDirectory();
      final waveFile = File('${tmpDir.path}/aura_wave_$songId.wave');

      final stream = JustWaveform.extract(
        audioInFile: File(filePath),
        waveOutFile: waveFile,
        zoom: const WaveformZoom.pixelsPerSecond(_pixelsPerSecond),
      );

      Waveform? result;
      await for (final progress in stream) {
        if (progress.waveform != null) result = progress.waveform;
      }

      if (result != null) {
        final amps = _envelope(result);
        _beats[songId] = _detectBeats(amps);
      }
    } catch (_) {
      // Platform channel unavailable (tests), unsupported format, or missing
      // permission — leave the cache empty so callers use the calm fallback.
    } finally {
      _pending.remove(songId);
    }
  }

  /// Normalised peak envelope (0..1) — average of |min| and |max| per pixel.
  List<double> _envelope(Waveform w) {
    final len = w.length;
    if (len == 0) return const [];
    return List<double>.generate(len, (i) {
      final hi = w.getPixelMax(i).abs();
      final lo = w.getPixelMin(i).abs();
      return ((hi + lo) / 2 / 32768.0).clamp(0.0, 1.0).toDouble();
    });
  }

  /// Energy-flux onset detection. Returns ascending beat times in milliseconds.
  ///
  /// For each sample we take the half-wave-rectified rise in loudness (a sudden
  /// jump up = an onset). A sample is a beat when its flux is a local maximum
  /// AND clears an adaptive threshold (local mean × sensitivity + floor), with a
  /// minimum gap between beats so a single hit isn't counted twice.
  List<int> _detectBeats(List<double> amps) {
    final n = amps.length;
    if (n < 4) return const [];

    final flux = List<double>.filled(n, 0.0);
    for (var i = 1; i < n; i++) {
      final d = amps[i] - amps[i - 1];
      flux[i] = d > 0 ? d : 0.0;
    }

    const window = 10; // ~±200 ms local context for the adaptive threshold
    const sensitivity = 1.6;
    const floor = 0.018;
    const minGapMs = 170.0; // ≤ ~350 BPM ceiling; kills double-triggers

    final beats = <int>[];
    var lastBeatMs = -10000.0;
    for (var i = 1; i < n - 1; i++) {
      var sum = 0.0;
      var cnt = 0;
      final lo = (i - window) < 0 ? 0 : i - window;
      final hi = (i + window) >= n ? n - 1 : i + window;
      for (var j = lo; j <= hi; j++) {
        sum += flux[j];
        cnt++;
      }
      final mean = cnt > 0 ? sum / cnt : 0.0;
      final threshold = mean * sensitivity + floor;
      if (flux[i] > threshold &&
          flux[i] >= flux[i - 1] &&
          flux[i] >= flux[i + 1]) {
        final ms = i * _msPerSample;
        if (ms - lastBeatMs >= minGapMs) {
          beats.add(ms.round());
          lastBeatMs = ms;
        }
      }
    }
    return beats;
  }
}
