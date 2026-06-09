import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real background audio engine: notification, lock-screen controls,
  // Bluetooth/headset buttons, audio focus on Android & iOS.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.aura.audio',
    androidNotificationChannelName: 'Aura playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

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

  runApp(const ProviderScope(child: AuraApp()));
}

