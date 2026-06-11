package io.mehrschad.aura

import com.ryanheise.audioservice.AudioServiceActivity

// Must extend AudioServiceActivity (NOT plain FlutterActivity) so the activity
// shares the audio_service plugin's cached FlutterEngine with the background
// AudioService. With a plain FlutterActivity the UI runs in its own engine
// while the service spins up a second one: audio plays, but the Android
// MediaSession (notification, lock screen, Bluetooth) never connects to the
// handler registered by AudioService.init().
class MainActivity : AudioServiceActivity()
