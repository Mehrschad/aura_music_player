import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/audio/just_audio_controller.dart';
import 'data/repositories/shared_preferences_settings_repository.dart';
import 'domain/audio/audio_controller.dart';
import 'presentation/providers/playback_providers.dart';
import 'presentation/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize the background audio service (media notification, lock-screen
  // controls, audio focus). Falls back to a plain JustAudioController if the
  // service fails to start (e.g. missing permissions on first cold start).
  AudioController audioController;
  try {
    audioController = await AudioService.init<JustAudioController>(
      builder: () => JustAudioController(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ryanheise.aura.channel.audio',
        androidNotificationChannelName: 'Aura',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    audioController = JustAudioController();
  }

  runApp(ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(settingsRepo, initialSettings),
      ),
      audioControllerProvider.overrideWithValue(audioController),
    ],
    child: const AuraApp(),
  ));
}
