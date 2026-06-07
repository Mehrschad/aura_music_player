import 'dart:async';

import '../../domain/audio/equalizer_controller.dart';
import '../../domain/audio/equalizer_presets.dart';
import '../../domain/models/equalizer.dart';

/// The active, cross-platform equalizer: a 10-band state model whose changes
/// stream to the UI (driving the live response curve). It is the source of
/// truth for gains, bass boost and stereo width.
///
/// On device this is where the visual EQ connects to audio — e.g. mapping the
/// bands onto a just_audio `AudioPipeline` of biquad filters, or an
/// `AVAudioUnitEQ` chain on iOS. The fake audio engine produces no sound, so
/// here the controller simply holds and broadcasts settings; the UI is fully
/// functional regardless. Settings persist to shared preferences on device.
class VisualEqualizerController implements EqualizerController {
  final _controller = StreamController<EqualizerSettings>.broadcast();
  EqualizerSettings _settings = EqualizerSettings.initial;

  @override
  Stream<EqualizerSettings> get settingsStream => _controller.stream;

  @override
  EqualizerSettings get settings => _settings;

  void _emit(EqualizerSettings next) {
    if (next == _settings) return;
    _settings = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  @override
  Future<void> setEnabled(bool enabled) async =>
      _emit(_settings.copyWith(enabled: enabled));

  @override
  Future<void> setBandGain(int index, double db) async {
    if (index < 0 || index >= _settings.gains.length) return;
    final gains = List<double>.of(_settings.gains);
    gains[index] = clampGain(db);
    _emit(_settings.copyWith(gains: gains));
  }

  @override
  Future<void> setGains(List<double> gains) async {
    final clamped = [for (final g in gains) clampGain(g)];
    _emit(_settings.copyWith(gains: clamped));
  }

  @override
  Future<void> applyPreset(EqPreset preset) async =>
      _emit(_settings.copyWith(gains: presetGains(preset)));

  @override
  Future<void> setBassBoost(int milliBels) async =>
      _emit(_settings.copyWith(bassBoost: milliBels.clamp(0, kBassBoostMax)));

  @override
  Future<void> setStereoWidth(double width) async =>
      _emit(_settings.copyWith(stereoWidth: width.clamp(0.0, 1.0)));

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
