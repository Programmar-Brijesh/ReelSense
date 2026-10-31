package `in`.developerbrijesh.reelsense.service

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import `in`.developerbrijesh.reelsense.MainActivity
import `in`.developerbrijesh.reelsense.accessibility.ReelSenseAccessibilityService
import `in`.developerbrijesh.reelsense.commands.NativeCommandMatcher
import `in`.developerbrijesh.reelsense.gestures.CustomGestureClassifier
import `in`.developerbrijesh.reelsense.gestures.CustomGestureTemplate
import `in`.developerbrijesh.reelsense.gestures.GestureCameraManager
import `in`.developerbrijesh.reelsense.gestures.GestureHandler
import `in`.developerbrijesh.reelsense.gestures.HandGesture
import `in`.developerbrijesh.reelsense.overlay.OverlayState
import `in`.developerbrijesh.reelsense.overlay.ReelSenseOverlayManager

class ReelSenseMonitoringService : LifecycleService() {

    companion object {
        private const val TAG_MONITOR = "ReelSenseMonitor"
        private const val TAG_SPEECH = "ReelSenseSpeech"
        private const val TAG_GESTURE = "ReelSenseGesture"

        const val NOTIFICATION_ID = 3001
        const val CHANNEL_ID = "reelsense_monitoring_channel"

        const val ACTION_START_MONITORING = "in.developerbrijesh.reelsense.START_MONITORING"
        const val ACTION_STOP_MONITORING = "in.developerbrijesh.reelsense.STOP_MONITORING"
        const val ACTION_UPDATE_CONFIG = "in.developerbrijesh.reelsense.UPDATE_CONFIG"
        const val ACTION_MANUAL_STOP = "in.developerbrijesh.reelsense.MANUAL_STOP"
        const val ACTION_PAUSE = "in.developerbrijesh.reelsense.PAUSE"
        const val ACTION_RESUME = "in.developerbrijesh.reelsense.RESUME"

        const val EXTRA_CONTROLLER_MODE = "controller_mode" // "voice" or "gesture"
        const val EXTRA_RECOGNITION_MODE = "recognition_mode" // "offline" or "online"
        const val EXTRA_LOCALE = "locale"

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var instance: ReelSenseMonitoringService? = null
            private set

        fun onForegroundPackageChanged(packageName: String, isInstagram: Boolean = (packageName == ReelSenseAccessibilityService.INSTAGRAM_PACKAGE)) {
            instance?.handlePackageChanged(packageName, isInstagram)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var overlayManager: ReelSenseOverlayManager? = null
    private var commandMatcher: NativeCommandMatcher? = null

    // Configuration
    private var controllerMode: String = "voice"
    private var recognitionMode: String = "offline"
    private var selectedLocale: String = "en-US"

    // State
    private var currentForegroundPackage: String? = null
    private var isControllerActive: Boolean = false
    private var isManuallyStopped: Boolean = false
    private var isPaused: Boolean = false

    // Speech Recognition Loop Management (Voice Mode)
    private var speechRecognizer: SpeechRecognizer? = null
    private var isSpeechListening: Boolean = false
    private var isSpeechStarting: Boolean = false
    private var restartRunnable: Runnable? = null

    // Camera Gesture Recognition Management (Gesture Mode)
    private var gestureCameraManager: GestureCameraManager? = null

    // Screen Receiver
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG_MONITOR, "Screen off detected, pausing recognition.")
                    pauseController()
                }
                Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG_MONITOR, "Screen on detected.")
                    if (currentForegroundPackage == ReelSenseAccessibilityService.INSTAGRAM_PACKAGE && !isManuallyStopped) {
                        resumeController()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        commandMatcher = NativeCommandMatcher(applicationContext)

        overlayManager = ReelSenseOverlayManager(
            context = applicationContext,
            onPauseRequested = { pauseController() },
            onResumeRequested = { resumeController() },
            onStopRequested = { manualStopController() }
        )

        createNotificationChannel()
        registerReceiver(screenReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        })

        Log.d(TAG_MONITOR, "ReelSenseMonitoringService created.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        val action = intent?.action ?: ACTION_START_MONITORING

        when (action) {
            ACTION_STOP_MONITORING -> {
                Log.d(TAG_MONITOR, "ACTION_STOP_MONITORING received. Stopping service.")
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_CONFIG, ACTION_START_MONITORING -> {
                val previousMode = controllerMode
                intent?.getStringExtra(EXTRA_CONTROLLER_MODE)?.let { controllerMode = it }
                intent?.getStringExtra(EXTRA_RECOGNITION_MODE)?.let { recognitionMode = it }
                intent?.getStringExtra(EXTRA_LOCALE)?.let { selectedLocale = it }
                commandMatcher?.reloadCommands()

                Log.d(TAG_MONITOR, "Monitoring config updated: mode=$controllerMode, recognition=$recognitionMode, locale=$selectedLocale")

                if (isControllerActive && previousMode != controllerMode) {
                    if (controllerMode == "voice") {
                        stopGestureCamera()
                        startSpeechLoop()
                    } else if (controllerMode == "gesture") {
                        stopSpeechLoop()
                        startGestureCamera()
                    }
                    overlayManager?.show(controllerMode)
                }

                startForegroundWithNotification()
            }
            ACTION_MANUAL_STOP -> manualStopController()
            ACTION_PAUSE -> pauseController()
            ACTION_RESUME -> resumeController()
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent): IBinder? {
        super.onBind(intent)
        return null
    }

    override fun onDestroy() {
        Log.d(TAG_MONITOR, "ReelSenseMonitoringService stopping or destroyed.")
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}

        deactivateController(reason = "Service destroyed")
        releaseGestureCamera()
        overlayManager?.hide(reason = "Service destroyed")
        overlayManager = null

        isRunning = false
        instance = null
        super.onDestroy()
    }

    // --- Foreground State Management ---

    fun handlePackageChanged(packageName: String, isInstagram: Boolean) {
        val wasInInstagram = currentForegroundPackage == ReelSenseAccessibilityService.INSTAGRAM_PACKAGE
        currentForegroundPackage = if (isInstagram) ReelSenseAccessibilityService.INSTAGRAM_PACKAGE else packageName

        Log.d(TAG_MONITOR, "handlePackageChanged: pkg=$packageName, isInstagram=$isInstagram, wasInInstagram=$wasInInstagram, isControllerActive=$isControllerActive")

        if (isInstagram) {
            // Instagram is in foreground
            if (isManuallyStopped) {
                Log.d(TAG_MONITOR, "Instagram foreground detected, but session was manually stopped by user. Keeping controller off.")
                return
            }

            if (!isControllerActive) {
                Log.d(TAG_MONITOR, "Instagram foreground detected. Activating controller.")
                activateController()
            }
        } else if (wasInInstagram || isControllerActive) {
            // Left Instagram: Reset manual stop flag and deactivate
            Log.d(TAG_MONITOR, "Instagram is no longer foreground (now $packageName). Deactivating controller.")
            isManuallyStopped = false
            isPaused = false
            deactivateController(reason = "Instagram exited to $packageName")
        }
    }

    private fun activateController() {
        mainHandler.post {
            if (isControllerActive) return@post
            isControllerActive = true
            isPaused = false

            Log.d(TAG_MONITOR, "Activating $controllerMode controller for Instagram.")
            overlayManager?.show(controllerMode)
            updateNotification(isActive = true)

            if (controllerMode == "voice") {
                stopGestureCamera()
                startSpeechLoop()
            } else if (controllerMode == "gesture") {
                stopSpeechLoop()
                startGestureCamera()
            }
        }
    }

    private fun deactivateController(reason: String = "Controller deactivated") {
        mainHandler.post {
            if (!isControllerActive) return@post
            isControllerActive = false

            Log.d(TAG_MONITOR, "Deactivating controller. Reason: $reason")
            cancelPendingRestart()
            stopSpeechLoop()
            stopGestureCamera()
            overlayManager?.hide(reason = reason)
            updateNotification(isActive = false)
        }
    }

    fun pauseController() {
        mainHandler.post {
            if (!isControllerActive) return@post
            isPaused = true
            cancelPendingRestart()
            stopSpeechLoop()
            stopGestureCamera()
            overlayManager?.setPaused(true)
            updateNotification(isActive = false, customText = "Controller Paused")
            Log.d(TAG_MONITOR, "Controller paused by user.")
        }
    }

    fun resumeController() {
        mainHandler.post {
            if (!isControllerActive) {
                if (currentForegroundPackage == ReelSenseAccessibilityService.INSTAGRAM_PACKAGE) {
                    isManuallyStopped = false
                    activateController()
                }
                return@post
            }

            isPaused = false
            isManuallyStopped = false
            overlayManager?.setPaused(false)
            updateNotification(isActive = true)

            if (controllerMode == "voice") {
                startSpeechLoop()
            } else if (controllerMode == "gesture") {
                startGestureCamera()
            }
            Log.d(TAG_MONITOR, "Controller resumed.")
        }
    }

    fun manualStopController() {
        mainHandler.post {
            Log.d(TAG_MONITOR, "User manually stopped controller from overlay.")
            isManuallyStopped = true
            isPaused = false
            deactivateController(reason = "User manual stop via overlay")
            updateNotification(isActive = false, customText = "Controller stopped (Auto-starts on next Instagram open)")
        }
    }

    // --- Native Camera Gesture Recognition (Gesture Mode) ---

    private fun startGestureCamera() {
        mainHandler.post {
            if (!isControllerActive || isPaused || isManuallyStopped ||
                currentForegroundPackage != ReelSenseAccessibilityService.INSTAGRAM_PACKAGE) {
                Log.d(TAG_GESTURE, "startGestureCamera skipped: active=$isControllerActive, paused=$isPaused, stopped=$isManuallyStopped, pkg=$currentForegroundPackage")
                return@post
            }

            if (!hasCameraPermission()) {
                Log.w(TAG_GESTURE, "Cannot start camera: CAMERA permission missing.")
                overlayManager?.showError("Camera permission required")
                return@post
            }

            if (gestureCameraManager == null) {
                gestureCameraManager = GestureCameraManager(
                    context = applicationContext,
                    lifecycleOwner = this,
                    onActionTriggered = { gestureName, action ->
                        handleGestureAction(gestureName, action)
                    },
                    onStateUpdated = { gestureName, isHandPresent, action ->
                        handleGestureStateUpdated(gestureName, isHandPresent, action)
                    }
                )
            }

            // Always ensure the latest custom templates from SharedPreferences are loaded
            val cachedTemplates = CustomGestureClassifier.loadFromPrefs(applicationContext)
            gestureCameraManager?.updateCustomTemplates(cachedTemplates)
            Log.i("ReelSenseGestureSync", "startGestureCamera: loaded ${cachedTemplates.size} custom gestures from SharedPreferences.")

            gestureCameraManager?.start()
            overlayManager?.updateGestureTracking(isCameraActive = true, isHandPresent = false)
            Log.i(TAG_GESTURE, "GestureCameraManager started.")
        }
    }

    private fun handleGestureAction(gestureName: String, action: String) {
        mainHandler.post {
            if (!isControllerActive || isPaused || isManuallyStopped ||
                currentForegroundPackage != ReelSenseAccessibilityService.INSTAGRAM_PACKAGE) {
                return@post
            }

            Log.i(TAG_GESTURE, "Gesture confirmed: $gestureName -> Executing $action")
            overlayManager?.showGestureAction(gestureName, action)

            val a11y = ReelSenseAccessibilityService.instance
            if (a11y != null) {
                a11y.performReelAction(action)
                Log.i(TAG_GESTURE, "Accessibility action executed: $action")
            } else {
                Log.w(TAG_GESTURE, "AccessibilityService instance is null! Cannot dispatch gesture.")
            }

            GestureHandler.instance?.sendGestureEvent(gestureName, true, action)
        }
    }

    private fun handleGestureStateUpdated(gestureName: String?, isHandPresent: Boolean, action: String?) {
        mainHandler.post {
            if (!isControllerActive || isPaused || isManuallyStopped) return@post
            overlayManager?.updateGestureTracking(
                isCameraActive = true,
                isHandPresent = isHandPresent,
                gestureDisplayName = gestureName,
                gestureAction = action
            )
            GestureHandler.instance?.sendGestureEvent(gestureName ?: "Unknown", isHandPresent, null)
        }
    }

    fun updateCustomGestures(templates: List<CustomGestureTemplate>) {
        Log.i("ReelSenseGestureSync", "ReelSenseMonitoringService.updateCustomGestures: received ${templates.size} custom gestures.")
        gestureCameraManager?.updateCustomTemplates(templates)
    }

    private fun stopGestureCamera() {
        mainHandler.post {
            gestureCameraManager?.stop()
            overlayManager?.updateGestureTracking(isCameraActive = false, isHandPresent = false)
            Log.d(TAG_GESTURE, "Gesture camera stopped.")
        }
    }

    private fun releaseGestureCamera() {
        mainHandler.post {
            gestureCameraManager?.release()
            gestureCameraManager = null
        }
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    // --- Native Speech Recognition Continuous Loop (Voice Mode) ---

    private fun startSpeechLoop() {
        mainHandler.post {
            cancelPendingRestart()

            if (!isControllerActive || isPaused || isManuallyStopped ||
                currentForegroundPackage != ReelSenseAccessibilityService.INSTAGRAM_PACKAGE) {
                Log.d(TAG_SPEECH, "startSpeechLoop skipped: active=$isControllerActive, paused=$isPaused, stopped=$isManuallyStopped, pkg=$currentForegroundPackage")
                return@post
            }

            if (!hasAudioPermission()) {
                Log.w(TAG_SPEECH, "Cannot start speech recognition: RECORD_AUDIO permission missing.")
                overlayManager?.showError("Microphone permission required")
                return@post
            }

            if (isSpeechStarting) {
                Log.d(TAG_SPEECH, "startSpeechLoop already in progress, avoiding duplicate start.")
                return@post
            }

            isSpeechStarting = true
            Log.d(TAG_SPEECH, "Speech recognition starting (mode=$recognitionMode, locale=$selectedLocale)...")

            destroySpeechRecognizer()

            try {
                val recognizer = if (recognitionMode == "offline") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        SpeechRecognizer.isOnDeviceRecognitionAvailable(applicationContext)) {
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(applicationContext)
                    } else {
                        SpeechRecognizer.createSpeechRecognizer(applicationContext)
                    }
                } else {
                    SpeechRecognizer.createSpeechRecognizer(applicationContext)
                }

                speechRecognizer = recognizer

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, selectedLocale)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)

                    if (recognitionMode == "offline") {
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                }

                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        isSpeechStarting = false
                        isSpeechListening = true
                        Log.d(TAG_SPEECH, "Listening callback received: onReadyForSpeech")
                        overlayManager?.updateState(OverlayState.LISTENING)
                    }

                    override fun onBeginningOfSpeech() {
                        Log.d(TAG_SPEECH, "Listening callback received: onBeginningOfSpeech")
                        overlayManager?.updateState(OverlayState.SPEECH_DETECTED)
                    }

                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        isSpeechListening = false
                        Log.d(TAG_SPEECH, "Listening callback received: onEndOfSpeech")
                        overlayManager?.updateState(OverlayState.PROCESSING)
                    }

                    override fun onError(error: Int) {
                        isSpeechListening = false
                        isSpeechStarting = false
                        val errorName = getSpeechErrorName(error)
                        Log.d(TAG_SPEECH, "Recognition error code: $error ($errorName)")

                        if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                            Log.d(TAG_SPEECH, "No speech or timeout detected. Continuing continuous listening loop.")
                            scheduleRestartSpeechLoop(250)
                        } else if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY || error == SpeechRecognizer.ERROR_CLIENT) {
                            Log.d(TAG_SPEECH, "Recognizer busy/client error. Resetting engine and restarting.")
                            scheduleRestartSpeechLoop(400)
                        } else if (error == SpeechRecognizer.ERROR_NETWORK || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT) {
                            Log.w(TAG_SPEECH, "Network error encountered in $recognitionMode mode.")
                            overlayManager?.showError("Network unavailable")
                            scheduleRestartSpeechLoop(1200)
                        } else if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                            Log.e(TAG_SPEECH, "Insufficient audio permissions.")
                            overlayManager?.showError("Microphone permission required")
                        } else {
                            scheduleRestartSpeechLoop(350)
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        isSpeechListening = false
                        isSpeechStarting = false
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val spokenText = matches?.firstOrNull() ?: ""
                        Log.d(TAG_SPEECH, "Final result received: '$spokenText'")

                        if (spokenText.isNotBlank()) {
                            handleSpokenSpeech(spokenText)
                        } else {
                            overlayManager?.updateState(OverlayState.LISTENING)
                        }

                        scheduleRestartSpeechLoop(350)
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val partials = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val partialText = partials?.firstOrNull() ?: ""
                        if (partialText.isNotBlank()) {
                            Log.d(TAG_SPEECH, "Partial result received: '$partialText'")
                            overlayManager?.updateState(OverlayState.SPEECH_DETECTED, heardText = partialText)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                recognizer.startListening(intent)
                Log.d(TAG_SPEECH, "Speech recognition started in $recognitionMode mode ($selectedLocale).")
            } catch (e: Exception) {
                isSpeechStarting = false
                isSpeechListening = false
                Log.e(TAG_SPEECH, "Failed to start speech recognizer: ${e.message}")
                scheduleRestartSpeechLoop(800)
            }
        }
    }

    private fun handleSpokenSpeech(speechText: String) {
        val matched = commandMatcher?.match(speechText)
        if (matched != null) {
            Log.d(TAG_SPEECH, "Command matched: '${matched.phrase}' -> Action: ${matched.action}")
            overlayManager?.updateState(
                state = OverlayState.ACTION_EXECUTED,
                heardText = speechText,
                matchedCommand = matched.phrase,
                actionName = matched.action
            )

            val a11y = ReelSenseAccessibilityService.instance
            if (a11y != null) {
                a11y.performReelAction(matched.action)
                Log.d(TAG_SPEECH, "Action executed successfully via AccessibilityService: ${matched.action}")
            } else {
                Log.w(TAG_SPEECH, "AccessibilityService instance is null! Cannot dispatch gesture.")
            }
        } else {
            Log.d(TAG_SPEECH, "No command matched for speech: '$speechText'")
            overlayManager?.updateState(
                state = OverlayState.NO_MATCH,
                heardText = speechText
            )
        }
    }

    private fun scheduleRestartSpeechLoop(delayMs: Long) {
        cancelPendingRestart()

        if (!isControllerActive || isPaused || isManuallyStopped ||
            currentForegroundPackage != ReelSenseAccessibilityService.INSTAGRAM_PACKAGE) {
            Log.d(TAG_SPEECH, "Cancel restart: controller not eligible (active=$isControllerActive, paused=$isPaused, stopped=$isManuallyStopped, pkg=$currentForegroundPackage)")
            return
        }

        Log.d(TAG_SPEECH, "Recognition restart requested with delay ${delayMs}ms")
        overlayManager?.updateState(OverlayState.RESTARTING)

        restartRunnable = Runnable {
            if (isControllerActive && !isPaused && !isManuallyStopped &&
                currentForegroundPackage == ReelSenseAccessibilityService.INSTAGRAM_PACKAGE) {
                Log.d(TAG_SPEECH, "Recognition restart completed. Launching speech loop.")
                startSpeechLoop()
            } else {
                Log.d(TAG_SPEECH, "Restart aborted: state changed before execution.")
            }
        }
        mainHandler.postDelayed(restartRunnable!!, delayMs)
    }

    private fun cancelPendingRestart() {
        restartRunnable?.let {
            mainHandler.removeCallbacks(it)
            restartRunnable = null
        }
    }

    private fun stopSpeechLoop() {
        mainHandler.post {
            cancelPendingRestart()
            destroySpeechRecognizer()
        }
    }

    private fun destroySpeechRecognizer() {
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
        isSpeechListening = false
        isSpeechStarting = false
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun getSpeechErrorName(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "ERROR_AUDIO"
            SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
            SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
            SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
            SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
            else -> "ERROR_UNKNOWN ($errorCode)"
        }
    }

    // --- Foreground Service Notification ---

    private fun startForegroundWithNotification() {
        val notification = buildNotification(isActive = isControllerActive)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE

            if (controllerMode == "voice" && hasAudioPermission()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
            } else if (controllerMode == "gesture" && hasCameraPermission()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                }
            }

            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, fgsType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(isActive: Boolean, customText: String? = null) {
        val notification = buildNotification(isActive, customText)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(isActive: Boolean, customText: String? = null): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, ReelSenseMonitoringService::class.java).apply {
            action = ACTION_STOP_MONITORING
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isActive) {
            "ReelSense Active on Instagram"
        } else {
            "ReelSense Auto-Start"
        }

        val text = customText ?: if (isActive) {
            if (controllerMode == "voice") {
                "Listening for voice commands ($recognitionMode)"
            } else {
                "Tracking hand gestures with camera"
            }
        } else {
            "Monitoring in background. Opens hands-free controls when Instagram launches."
        }

        val iconRes = if (controllerMode == "voice") {
            android.R.drawable.ic_btn_speak_now
        } else {
            android.R.drawable.ic_menu_camera
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(iconRes)
            .setOngoing(true)
            .setContentIntent(contentPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Monitoring", stopPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "ReelSense Auto-Start Monitoring"
            val descriptionText = "Persistent background monitoring for Instagram hands-free navigation"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
