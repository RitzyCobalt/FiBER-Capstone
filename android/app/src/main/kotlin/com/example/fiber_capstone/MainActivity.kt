package com.example.fiber_capstone

import android.media.MediaPlayer
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "fiber_audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "playDataUri") {
                    val dataUri = call.argument<String>("dataUri") ?: ""
                    val volume = (call.argument<Double>("volume") ?: 0.5).toFloat()
                    playBase64Wav(dataUri, volume)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun playBase64Wav(dataUri: String, volume: Float) {
        try {
            val commaIndex = dataUri.indexOf(',')
            if (commaIndex == -1) return
            val base64Part = dataUri.substring(commaIndex + 1)
            val audioBytes = Base64.decode(base64Part, Base64.DEFAULT)

            val tempFile = File.createTempFile("fiber_sfx_", ".wav", cacheDir)
            tempFile.deleteOnExit()
            FileOutputStream(tempFile).use { it.write(audioBytes) }

            val mediaPlayer = MediaPlayer()
            mediaPlayer.setDataSource(tempFile.absolutePath)
            mediaPlayer.setVolume(volume, volume)
            mediaPlayer.setOnCompletionListener { mp ->
                mp.release()
                tempFile.delete()
            }
            mediaPlayer.prepare()
            mediaPlayer.start()
        } catch (_: Exception) {
        }
    }
}