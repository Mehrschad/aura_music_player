# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# audio_service — keep the background service and media session classes
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# just_audio — ExoPlayer / media3
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# on_audio_query
-keep class com.lucasjosino.on_audio_query.** { *; }

# Keep Kotlin metadata for reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Prevent stripping of enum values used via reflection
-keepclassmembers enum * { *; }
