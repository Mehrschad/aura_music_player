import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // To enable the real background audio engine (JustAudioController), initialise
  // the media session here, before runApp, then override `audioControllerProvider`
  // with `JustAudioController()`:
  //
  //   await JustAudioBackground.init(
  //     androidNotificationChannelId: 'com.aura.audio',
  //     androidNotificationChannelName: 'Aura playback',
  //     androidNotificationOngoing: true,
  //   );
  //
  // The active FakeAudioController needs no such setup, so the app runs as-is.

  // Edge-to-edge: the Liquid Glass nav bar floats over content, so we want the
  // app to draw behind the system bars and keep them transparent.
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
