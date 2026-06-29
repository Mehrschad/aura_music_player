import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/audio/just_audio_controller.dart';
import 'data/audio/visual_equalizer_controller.dart';
import 'data/platform/playback_persistence.dart';
import 'data/repositories/shared_preferences_settings_repository.dart';
import 'domain/audio/audio_controller.dart';
import 'presentation/providers/equalizer_providers.dart';
import 'presentation/providers/playback_persistence_provider.dart';
import 'presentation/providers/playback_providers.dart';
import 'presentation/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission (Android 13+ requires this for media notifications).
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Edge-to-edge: the Liquid Glass nav bar floats over content.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Load persisted settings before the first frame.
  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SharedPreferencesSettingsRepository(prefs);
  final initialSettings = await settingsRepo.load();

  // Remembers the last playback session so the player resumes where it left off.
  final playbackPersistence = PlaybackPersistence(prefs);

  // Create the equalizer controller before the audio service so the same
  // instance is shared by both the UI provider and the JustAudioController's
  // AudioPipeline bridge.
  final eqController = VisualEqualizerController();

  // Initialize the background audio service (media notification, lock-screen
  // controls, audio focus). Falls back to a plain JustAudioController if the
  // service fails to start (e.g. missing permissions on first cold start).
  AudioController audioController;
  try {
    audioController = await AudioService.init<JustAudioController>(
      builder: () => JustAudioController(eqController: eqController),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'io.mehrschad.aura.channel.audio',
        androidNotificationChannelName: 'Aura',
        androidNotificationChannelDescription: 'Music playback controls',
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        notificationColor: Color(0xFF1A1A2E),
      ),
    );
  } catch (e, st) {
    debugPrint('[Aura] AudioService.init failed — running without media session.\n$e\n$st');
    audioController = JustAudioController(eqController: eqController);
  }

  runApp(ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(settingsRepo, initialSettings),
      ),
      audioControllerProvider.overrideWithValue(audioController),
      // Override equalizerControllerProvider with the same instance passed to
      // JustAudioController so UI changes immediately propagate to the DSP.
      equalizerControllerProvider.overrideWithValue(eqController),
      playbackPersistenceProvider.overrideWithValue(playbackPersistence),
    ],
    child: const AuraApp(),
  ));
}
