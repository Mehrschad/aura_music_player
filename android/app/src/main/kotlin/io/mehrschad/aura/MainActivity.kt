package io.mehrschad.aura

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Must extend AudioServiceActivity (NOT plain FlutterActivity) so the activity
// shares the audio_service plugin's cached FlutterEngine with the background
// AudioService. With a plain FlutterActivity the UI runs in its own engine
// while the service spins up a second one: audio plays, but the Android
// MediaSession (notification, lock screen, Bluetooth) never connects to the
// handler registered by AudioService.init().
class MainActivity : AudioServiceActivity() {
    private val channelName = "io.mehrschad.aura/media"

    // The system delete confirmation dialog (Android 11+) returns asynchronously
    // via onActivityResult; we stash the pending Flutter result here until then.
    private var pendingDeleteResult: MethodChannel.Result? = null
    private val deleteRequestCode = 0xDE1E

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteSong" -> {
                        val id = call.argument<String>("id")?.toLongOrNull()
                        if (id == null) {
                            result.error("no_id", "Missing or invalid song id", null)
                        } else {
                            deleteSong(id, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deleteSong(id: Long, result: MethodChannel.Result) {
        val uri = ContentUris.withAppendedId(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+: the system shows a confirmation dialog and grants
                // a one-shot delete permission for this exact file.
                val pendingIntent =
                    MediaStore.createDeleteRequest(contentResolver, listOf(uri))
                pendingDeleteResult = result
                startIntentSenderForResult(
                    pendingIntent.intentSender, deleteRequestCode, null, 0, 0, 0
                )
            } else {
                val rows = contentResolver.delete(uri, null, null)
                result.success(rows > 0)
            }
        } catch (e: Exception) {
            result.error("delete_failed", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == deleteRequestCode) {
            val r = pendingDeleteResult
            pendingDeleteResult = null
            r?.success(resultCode == Activity.RESULT_OK)
        }
    }
}
