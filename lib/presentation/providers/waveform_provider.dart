import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/waveform_analysis_service.dart';

/// Singleton service that analyses audio files and caches their amplitude
/// envelopes. Widgets call [waveformAnalysisServiceProvider] once per song
/// change to kick off background extraction; subsequent position-stream
/// callbacks read cached results synchronously.
final waveformAnalysisServiceProvider = Provider<WaveformAnalysisService>(
  (_) => WaveformAnalysisService(),
);
