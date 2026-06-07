import '../../domain/audio/equalizer_controller.dart';
import '../../domain/models/equalizer.dart';

/// Bridges Android's system equalizer (`android.media.audiofx.Equalizer`) via
/// `equalizer_flutter`.
///
/// Documented stub — it doesn't import `equalizer_flutter`, so the project
/// compiles and runs on [VisualEqualizerController]. To enable on Android:
///   1. Add `equalizer_flutter` to `pubspec.yaml` (commented placeholder is
///      there) and `volume_controller` if using the system volume hooks.
///   2. Initialise with the audio session id from just_audio
///      (`AudioPlayer.androidAudioSessionId`), then map band gains onto the
///      system equalizer's bands (which report the device's actual centre
///      frequencies — surface those instead of [kEqBands]).
///   3. Mirror enable/preset/bass-boost onto the platform effect and emit
///      [EqualizerSettings] from its callbacks.
///   4. Provide this for Android via `equalizerControllerProvider`; iOS and
///      other platforms keep the visual controller.
class SystemEqualizerController implements EqualizerController {
  Never _unimplemented() => throw UnimplementedError(
        'SystemEqualizerController requires equalizer_flutter on Android. '
        'VisualEqualizerController is active until then.',
      );

  @override
  Stream<EqualizerSettings> get settingsStream => _unimplemented();

  @override
  EqualizerSettings get settings => _unimplemented();

  @override
  Future<void> setEnabled(bool enabled) => _unimplemented();

  @override
  Future<void> setBandGain(int index, double db) => _unimplemented();

  @override
  Future<void> setGains(List<double> gains) => _unimplemented();

  @override
  Future<void> applyPreset(EqPreset preset) => _unimplemented();

  @override
  Future<void> setBassBoost(int milliBels) => _unimplemented();

  @override
  Future<void> setStereoWidth(double width) => _unimplemented();

  @override
  Future<void> dispose() async {}
}
