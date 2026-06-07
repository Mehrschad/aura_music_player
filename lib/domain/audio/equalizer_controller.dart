import '../models/equalizer.dart';

/// Controls the equalizer effect. Mirrors the audio/library seam: the UI
/// depends only on this interface.
///
///   • [VisualEqualizerController] is active — a cross-platform 10-band state
///     model (the visual EQ). It holds and streams settings; wiring it to a
///     DSP effect (e.g. an AVAudioUnitEQ chain on iOS, or a just_audio
///     `AudioPipeline`) is the device step.
///   • [SystemEqualizerController] bridges Android's `android.media.audiofx`
///     equalizer via `equalizer_flutter`.
abstract interface class EqualizerController {
  Stream<EqualizerSettings> get settingsStream;
  EqualizerSettings get settings;

  Future<void> setEnabled(bool enabled);
  Future<void> setBandGain(int index, double db);
  Future<void> setGains(List<double> gains);
  Future<void> applyPreset(EqPreset preset);
  Future<void> setBassBoost(int milliBels);
  Future<void> setStereoWidth(double width);

  Future<void> dispose();
}
