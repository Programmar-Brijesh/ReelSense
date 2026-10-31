package `in`.developerbrijesh.reelsense.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import androidx.core.content.ContextCompat
import `in`.developerbrijesh.reelsense.service.ReelSenseMonitoringService

class ReelSenseAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ReelSenseAccessibility"
        const val INSTAGRAM_PACKAGE = "com.instagram.android"

        @Volatile
        var instance: ReelSenseAccessibilityService? = null
            private set

        fun isServiceEnabled(context: Context): Boolean {
            val expectedServiceName = "${context.packageName}/${ReelSenseAccessibilityService::class.java.canonicalName}"
            val enabledServicesSetting = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServicesSetting)

            while (colonSplitter.hasNext()) {
                val componentName = colonSplitter.next()
                if (componentName.equals(expectedServiceName, ignoreCase = true) ||
                    componentName.contains("ReelSenseAccessibilityService", ignoreCase = true)) {
                    return true
                }
            }
            return false
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingExitRunnable: Runnable? = null
    private var lastReportedPackage: String? = null

    // Packages that must NEVER trigger an exit from Instagram
    private val ignoredPackages = setOf(
        "in.developerbrijesh.reelsense", // Our own app & floating overlay window
        "com.google.android.googlequicksearchbox", // Android SpeechRecognizer engine
        "android.speech",
        "com.google.android.tts",
        "com.android.systemui", // System status bar, navigation bar, volume panel
        "android", // System alerts & permissions
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "ReelSenseAccessibilityService connected and ready.")
    }

    override fun onDestroy() {
        cancelPendingExit()
        instance = null
        Log.d(TAG, "ReelSenseAccessibilityService destroyed.")
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val pkg = event.packageName?.toString() ?: return

            // 1. Filter out ignored packages (our overlay, speech engine, keyboards, system UI)
            if (isIgnoredPackage(pkg)) {
                // Do not treat internal or system overlay windows as foreground changes
                return
            }

            if (pkg == INSTAGRAM_PACKAGE) {
                // Ensure the background monitoring service is started if auto-start is configured
                ensureMonitoringServiceStartedIfNeeded()

                // User is in Instagram! Cancel any pending exit and notify immediately
                cancelPendingExit()
                if (lastReportedPackage != INSTAGRAM_PACKAGE) {
                    lastReportedPackage = INSTAGRAM_PACKAGE
                    Log.d(TAG, "Instagram foreground detected: $pkg")
                    ReelSenseMonitoringService.onForegroundPackageChanged(INSTAGRAM_PACKAGE, isInstagram = true)
                }
            } else {
                // An external non-Instagram package arrived (e.g. Launcher or WhatsApp)
                // Debounce exit check to prevent transient window switches from closing the overlay
                scheduleDebouncedExitCheck(pkg)
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted.")
    }

    private fun isIgnoredPackage(pkg: String): Boolean {
        if (ignoredPackages.contains(pkg)) return true
        if (pkg.contains("inputmethod", ignoreCase = true) ||
            pkg.contains("keyboard", ignoreCase = true) ||
            pkg.contains("gboard", ignoreCase = true) ||
            pkg.contains("swiftkey", ignoreCase = true)) {
            return true
        }
        return false
    }

    private fun scheduleDebouncedExitCheck(newPackage: String) {
        cancelPendingExit()

        pendingExitRunnable = Runnable {
            // Verify if Instagram is truly no longer in the foreground
            if (isInstagramStillInForeground()) {
                Log.d(TAG, "Debounced check: Instagram is still the active window. Retaining controller.")
                return@Runnable
            }

            Log.d(TAG, "Confirmed Instagram left. New foreground package: $newPackage")
            lastReportedPackage = newPackage
            ReelSenseMonitoringService.onForegroundPackageChanged(newPackage, isInstagram = false)
        }

        // Wait 450ms before finalizing exit so transient dialogs or app launches don't flicker
        mainHandler.postDelayed(pendingExitRunnable!!, 450)
    }

    private fun cancelPendingExit() {
        pendingExitRunnable?.let { mainHandler.removeCallbacks(it) }
        pendingExitRunnable = null
    }

    private fun ensureMonitoringServiceStartedIfNeeded() {
        if (ReelSenseMonitoringService.instance != null) return

        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isAutoStartEnabled = prefs.getBoolean("flutter.reelsense_auto_start_enabled", false)

            if (isAutoStartEnabled) {
                val mode = prefs.getString("flutter.reelsense_auto_start_controller_mode", "voice") ?: "voice"
                val recognitionMode = prefs.getString("flutter.reelsense_auto_start_recognition_mode", "offline") ?: "offline"
                val locale = prefs.getString("flutter.reelsense_auto_start_locale", "en-US") ?: "en-US"

                Log.d(TAG, "Starting ReelSenseMonitoringService from AccessibilityService (auto-start enabled: mode=$mode)")
                val intent = Intent(this, ReelSenseMonitoringService::class.java).apply {
                    action = ReelSenseMonitoringService.ACTION_START_MONITORING
                    putExtra(ReelSenseMonitoringService.EXTRA_CONTROLLER_MODE, mode)
                    putExtra(ReelSenseMonitoringService.EXTRA_RECOGNITION_MODE, recognitionMode)
                    putExtra(ReelSenseMonitoringService.EXTRA_LOCALE, locale)
                }
                ContextCompat.startForegroundService(this, intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start monitoring service from AccessibilityService: ${e.message}")
        }
    }

    private fun isInstagramStillInForeground(): Boolean {
        try {
            // Check active window root package
            val root = rootInActiveWindow
            if (root != null) {
                val rootPkg = root.packageName?.toString()
                if (rootPkg == INSTAGRAM_PACKAGE) {
                    return true
                }
            }
        } catch (_: Exception) {}

        try {
            // Check focused application window in window hierarchy
            val windowList = windows
            for (w in windowList) {
                if (w.isFocused && w.type == AccessibilityWindowInfo.TYPE_APPLICATION) {
                    val root = w.root
                    if (root?.packageName == INSTAGRAM_PACKAGE) {
                        return true
                    }
                }
            }
        } catch (_: Exception) {}

        return false
    }

    // --- Reel Control Gestures ---

    fun performReelAction(action: String, onComplete: ((Boolean) -> Unit)? = null) {
        Log.d(TAG, "Performing accessibility gesture for action: $action")
        when (action.uppercase()) {
            "NEXT_REEL" -> swipeUp(onComplete = onComplete)
            "PREVIOUS_REEL" -> swipeDown(onComplete = onComplete)
            "LIKE_REEL" -> doubleTap(onComplete = onComplete)
            "PAUSE_PLAY" -> singleTap(onComplete = onComplete)
            "REPLAY_REEL" -> replayReel(onComplete = onComplete)
            else -> {
                Log.w(TAG, "Unknown action: $action")
                onComplete?.invoke(false)
            }
        }
    }

    fun swipeUp(durationMs: Long = 250, onComplete: ((Boolean) -> Unit)? = null) {
        val dm = resources.displayMetrics
        val width = dm.widthPixels.toFloat()
        val height = dm.heightPixels.toFloat()

        val startX = width * 0.5f
        val startY = height * 0.76f
        val endX = width * 0.5f
        val endY = height * 0.22f

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        dispatchPathGesture(path, durationMs, onComplete)
    }

    fun swipeDown(durationMs: Long = 250, onComplete: ((Boolean) -> Unit)? = null) {
        val dm = resources.displayMetrics
        val width = dm.widthPixels.toFloat()
        val height = dm.heightPixels.toFloat()

        val startX = width * 0.5f
        val startY = height * 0.22f
        val endX = width * 0.5f
        val endY = height * 0.76f

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        dispatchPathGesture(path, durationMs, onComplete)
    }

    fun doubleTap(onComplete: ((Boolean) -> Unit)? = null) {
        val dm = resources.displayMetrics
        val x = dm.widthPixels * 0.5f
        val y = dm.heightPixels * 0.5f

        val path1 = Path().apply { moveTo(x, y) }
        val stroke1 = GestureDescription.StrokeDescription(path1, 0, 50)

        val path2 = Path().apply { moveTo(x, y) }
        val stroke2 = GestureDescription.StrokeDescription(path2, 120, 50)

        val gesture = GestureDescription.Builder()
            .addStroke(stroke1)
            .addStroke(stroke2)
            .build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Double tap (LIKE_REEL) completed.")
                onComplete?.invoke(true)
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w(TAG, "Double tap (LIKE_REEL) cancelled.")
                onComplete?.invoke(false)
            }
        }, null)
    }

    fun singleTap(onComplete: ((Boolean) -> Unit)? = null) {
        val dm = resources.displayMetrics
        val x = dm.widthPixels * 0.5f
        val y = dm.heightPixels * 0.5f

        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 60)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Single tap (PAUSE_PLAY) completed.")
                onComplete?.invoke(true)
            }
            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w(TAG, "Single tap (PAUSE_PLAY) cancelled.")
                onComplete?.invoke(false)
            }
        }, null)
    }

    fun replayReel(onComplete: ((Boolean) -> Unit)? = null) {
        swipeDown(durationMs = 180) { ok ->
            if (ok) {
                swipeUp(durationMs = 200, onComplete = onComplete)
            } else {
                onComplete?.invoke(false)
            }
        }
    }

    private fun dispatchPathGesture(path: Path, durationMs: Long, onComplete: ((Boolean) -> Unit)?) {
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Path gesture completed successfully.")
                onComplete?.invoke(true)
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w(TAG, "Path gesture cancelled.")
                onComplete?.invoke(false)
            }
        }, null)
    }
}
