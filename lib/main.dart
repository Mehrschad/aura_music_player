import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background audio: notification, lock-screen controls, Bluetooth buttons,
  // audio focus.  Wrapped in try-catch so a service-binding failure on some
  // Samsung / MIUI devices never prevents the app from starting.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.aura.audio',
      androidNotificationChannelName: 'Aura playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (e, st) {
    debugPrint('JustAudioBackground init failed — continuing without '
        'notification controls.\n$e\n$st');
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

  runApp(const ProviderScope(child: AuraApp()));
}

