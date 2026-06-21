import 'dart:io';

import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

/// Extracts and caches a normalised amplitude envelope (0.0–1.0 per sample)
/// from a local audio file using [JustWaveform] (MediaCodec on Android,
/// AVFoundation on iOS).
///
/// Callers that need real-time energy readings should:
///  1. Call [getAmplitudes] once per song (fire-and-forget) to populate the cache.
///  2. Call [getCachedAmplitudes] synchronously when driving animations — it
///     returns [null] until extraction completes, so callers fall back gracefully
///     to synthetic data (see [generateWaveform] in waveform.dart).
class WaveformAnalysisService {
  final Map<String, List<double>> _cache = {};
  final Set<String> _pending = {};

  /// Returns cached amplitudes for [songId], or [null] if not yet analysed.
  List<double>? getCachedAmplitudes(String songId) => _cache[songId];

  /// Analyses [filePath] in the background, caches the result, and returns it.
  /// Safe to call multiple times for the same [songId]: duplicate calls while
  /// analysis is in-flight are ignored; subsequent calls return the cache.
  /// All exceptions are swallowed — the caller always gets [null] on failure.
  Future<List<double>?> getAmplitudes(
    String songId,
    String filePath,
  ) async {
    if (_cache.containsKey(songId)) return _cache[songId];
    if (_pending.contains(songId)) return null;
    _pending.add(songId);

    try {
      final tmpDir = await getTemporaryDirectory();
      final waveFile = File('${tmpDir.path}/aura_wave_$songId.dat');

      // Re-use a previously written waveform file if it exists.
      if (await waveFile.exists()) {
        final waveform = await Waveform.parse(waveOutFile: waveFile);
        _cache[songId] = _normalise(waveform);
        return _cache[songId];
      }

      // One sample per ~186 ms at 44 100 Hz (8 192 samples/pixel).
      // A 3-min track yields ~970 points — enough rhythmic detail while keeping
      // extraction fast (< 1 s on a mid-range device).
      final stream = JustWaveform.extract(
        audioInFile: File(filePath),
        waveOutFile: waveFile,
        zoom: const WaveformZoom.pixelsPerStep(8192),
      );

      Waveform? result;
      await for (final progress in stream) {
        if (progress.waveform != null) result = progress.waveform;
      }

      if (result != null) {
        _cache[songId] = _normalise(result);
        return _cache[songId];
      }
    } catch (_) {
      // Platform channel not available (tests), unsupported format, or
      // missing permission — silently fall through to return null.
    } finally {
      _pending.remove(songId);
    }

    return null;
  }

  List<double> _normalise(Waveform waveform) {
    final len = waveform.length;
    if (len == 0) return const [];
    return List<double>.generate(len, (i) {
      final hi = waveform.getPixelMax(i).abs();
      final lo = waveform.getPixelMin(i).abs();
      return ((hi + lo) / 2 / 32768.0).clamp(0.0, 1.0).toDouble();
    });
  }
}
