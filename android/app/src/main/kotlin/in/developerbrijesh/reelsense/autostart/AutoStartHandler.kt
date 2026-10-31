package `in`.developerbrijesh.reelsense.autostart

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import `in`.developerbrijesh.reelsense.accessibility.ReelSenseAccessibilityService
import `in`.developerbrijesh.reelsense.service.ReelSenseMonitoringService

class AutoStartHandler(
    private val context: Context,
    private var activity: Activity?
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "in.developerbrijesh.reelsense/auto_start"
    }

    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL_NAME).apply {
            setMethodCallHandler(this@AutoStartHandler)
        }
    }

    fun setActivity(act: Activity?) {
        this.activity = act
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessibilityServiceEnabled" -> {
                result.success(ReelSenseAccessibilityService.isServiceEnabled(context))
            }
            "openAccessibilitySettings" -> {
                openAccessibilitySettings(result)
            }
            "isOverlayPermissionGranted" -> {
                result.success(Settings.canDrawOverlays(context))
            }
            "requestOverlayPermission" -> {
                requestOverlayPermission(result)
            }
            "isMonitoringServiceRunning" -> {
                result.success(ReelSenseMonitoringService.isRunning)
            }
            "startMonitoringService" -> {
                val mode = call.argument<String>("controllerMode") ?: "voice"
                val recognitionMode = call.argument<String>("recognitionMode") ?: "offline"
                val locale = call.argument<String>("locale") ?: "en-US"
                startMonitoringService(mode, recognitionMode, locale, result)
            }
            "stopMonitoringService" -> {
                stopMonitoringService(result)
            }
            "updateConfig" -> {
                val mode = call.argument<String>("controllerMode") ?: "voice"
                val recognitionMode = call.argument<String>("recognitionMode") ?: "offline"
                val locale = call.argument<String>("locale") ?: "en-US"
                updateConfig(mode, recognitionMode, locale, result)
            }
            "pauseController" -> {
                ReelSenseMonitoringService.instance?.pauseController()
                result.success(true)
            }
            "resumeController" -> {
                ReelSenseMonitoringService.instance?.resumeController()
                result.success(true)
            }
            "stopController" -> {
                ReelSenseMonitoringService.instance?.manualStopController()
                result.success(true)
            }
            "getServiceStatus" -> {
                val status = mapOf(
                    "isMonitoringRunning" to ReelSenseMonitoringService.isRunning,
                    "isAccessibilityEnabled" to ReelSenseAccessibilityService.isServiceEnabled(context),
                    "isOverlayGranted" to Settings.canDrawOverlays(context),
                    "hasAccessibilityInstance" to (ReelSenseAccessibilityService.instance != null)
                )
                result.success(status)
            }
            else -> result.notImplemented()
        }
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INTENT_ERROR", e.message, null)
        }
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                result.success(true)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("INTENT_ERROR", e.message, null)
        }
    }

    private fun startMonitoringService(
        mode: String,
        recognitionMode: String,
        locale: String,
        result: MethodChannel.Result
    ) {
        try {
            val intent = Intent(context, ReelSenseMonitoringService::class.java).apply {
                action = ReelSenseMonitoringService.ACTION_START_MONITORING
                putExtra(ReelSenseMonitoringService.EXTRA_CONTROLLER_MODE, mode)
                putExtra(ReelSenseMonitoringService.EXTRA_RECOGNITION_MODE, recognitionMode)
                putExtra(ReelSenseMonitoringService.EXTRA_LOCALE, locale)
            }
            ContextCompat.startForegroundService(context, intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_START_FAILED", "Failed to start monitoring service: ${e.message}", null)
        }
    }

    private fun stopMonitoringService(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, ReelSenseMonitoringService::class.java).apply {
                action = ReelSenseMonitoringService.ACTION_STOP_MONITORING
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_STOP_FAILED", e.message, null)
        }
    }

    private fun updateConfig(
        mode: String,
        recognitionMode: String,
        locale: String,
        result: MethodChannel.Result
    ) {
        try {
            if (ReelSenseMonitoringService.isRunning) {
                val intent = Intent(context, ReelSenseMonitoringService::class.java).apply {
                    action = ReelSenseMonitoringService.ACTION_UPDATE_CONFIG
                    putExtra(ReelSenseMonitoringService.EXTRA_CONTROLLER_MODE, mode)
                    putExtra(ReelSenseMonitoringService.EXTRA_RECOGNITION_MODE, recognitionMode)
                    putExtra(ReelSenseMonitoringService.EXTRA_LOCALE, locale)
                }
                context.startService(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("UPDATE_CONFIG_FAILED", e.message, null)
        }
    }
}
