package com.urbanpets.verify.urban_pets_verify

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// AndroidX biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.urbanpets.verify/sound"
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (_: Exception) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "playScanBeep") {
                try {
                    if (toneGenerator == null) {
                        toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                    }
                    toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            toneGenerator?.release()
            toneGenerator = null
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
