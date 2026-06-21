import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/waveform_analysis_service.dart';

/// Singleton service that analyses audio files into a beat grid (via energy-flux
/// onset detection) and caches it. Widgets call [waveformAnalysisServiceProvider]
/// once per song change to kick off background analysis; the beat scheduler then
/// reads [WaveformAnalysisService.getCachedBeats] synchronously each frame.
final waveformAnalysisServiceProvider = Provider<WaveformAnalysisService>(
  (_) => WaveformAnalysisService(),
);
