package `in`.developerbrijesh.reelsense

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import `in`.developerbrijesh.reelsense.autostart.AutoStartHandler
import `in`.developerbrijesh.reelsense.service.ReelSenseMonitoringService
import `in`.developerbrijesh.reelsense.speech.SpeechRecognitionHandler

class MainActivity : FlutterActivity() {
    private var speechHandler: SpeechRecognitionHandler? = null
    private var autoStartHandler: AutoStartHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        speechHandler = SpeechRecognitionHandler(applicationContext, this).apply {
            register(flutterEngine.dartExecutor.binaryMessenger)
        }

        autoStartHandler = AutoStartHandler(applicationContext, this).apply {
            register(flutterEngine.dartExecutor.binaryMessenger)
        }

        ensureMonitoringServiceIfAutoStartEnabled()
    }

    override fun onResume() {
        super.onResume()
        ensureMonitoringServiceIfAutoStartEnabled()
    }

    private fun ensureMonitoringServiceIfAutoStartEnabled() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isAutoStartEnabled = prefs.getBoolean("flutter.reelsense_auto_start_enabled", false)
            if (isAutoStartEnabled && !ReelSenseMonitoringService.isRunning) {
                val mode = prefs.getString("flutter.reelsense_auto_start_controller_mode", "voice") ?: "voice"
                val recognitionMode = prefs.getString("flutter.reelsense_auto_start_recognition_mode", "offline") ?: "offline"
                val locale = prefs.getString("flutter.reelsense_auto_start_locale", "en-US") ?: "en-US"

                val intent = Intent(this, ReelSenseMonitoringService::class.java).apply {
                    action = ReelSenseMonitoringService.ACTION_START_MONITORING
                    putExtra(ReelSenseMonitoringService.EXTRA_CONTROLLER_MODE, mode)
                    putExtra(ReelSenseMonitoringService.EXTRA_RECOGNITION_MODE, recognitionMode)
                    putExtra(ReelSenseMonitoringService.EXTRA_LOCALE, locale)
                }
                ContextCompat.startForegroundService(this, intent)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        speechHandler?.unregister()
        speechHandler = null

        autoStartHandler?.unregister()
        autoStartHandler = null

        super.onDestroy()
    }
}
