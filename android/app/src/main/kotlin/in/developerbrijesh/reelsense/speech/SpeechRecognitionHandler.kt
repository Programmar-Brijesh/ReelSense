package `in`.developerbrijesh.reelsense.speech

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.Locale

class SpeechRecognitionHandler(
    private val context: Context,
    private var activity: Activity?
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val METHOD_CHANNEL = "in.developerbrijesh.reelsense/speech_recognition"
        const val EVENT_CHANNEL = "in.developerbrijesh.reelsense/speech_events"
        private const val PERMISSION_REQUEST_RECORD_AUDIO = 2001
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var speechRecognizer: SpeechRecognizer? = null
    private var activeMode: String = "offline"
    private var activeLocale: String = "en-US"
    private var isListening: Boolean = false

    private var pendingPermissionResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@SpeechRecognitionHandler)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@SpeechRecognitionHandler)
        }
    }

    fun setActivity(act: Activity?) {
        this.activity = act
    }

    fun unregister() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        destroyRecognizer()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasRecordAudioPermission" -> {
                result.success(hasAudioPermission())
            }
            "requestRecordAudioPermission" -> {
                requestAudioPermission(result)
            }
            "checkAvailability" -> {
                val locale = call.argument<String>("locale") ?: "en-US"
                checkAvailability(locale, result)
            }
            "triggerModelDownload" -> {
                val locale = call.argument<String>("locale") ?: "en-US"
                triggerModelDownload(locale, result)
            }
            "openVoiceSettings" -> {
                openVoiceSettings(result)
            }
            "startListening" -> {
                val mode = call.argument<String>("mode") ?: "offline"
                val locale = call.argument<String>("locale") ?: "en-US"
                startListening(mode, locale, result)
            }
            "stopListening" -> {
                stopListening(result)
            }
            "cancelListening" -> {
                cancelListening(result)
            }
            else -> result.notImplemented()
        }
    }

    // --- Permissions ---

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (hasAudioPermission()) {
            result.success(true)
            return
        }

        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity is not available to request permission", null)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            act,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_RECORD_AUDIO
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_RECORD_AUDIO) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    // --- Availability Checking ---

    private fun checkAvailability(requestedLocale: String, result: MethodChannel.Result) {
        val isGeneralRecognitionAvailable = SpeechRecognizer.isRecognitionAvailable(context)

        var isOnDeviceAvailable = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                isOnDeviceAvailable = SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
            } catch (e: Exception) {
                isOnDeviceAvailable = false
            }
        }

        // On Android 13+ (API 33+), use checkRecognitionSupport
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && isGeneralRecognitionAvailable) {
            try {
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, requestedLocale)
                }

                // If on-device recognizer can be created, query support directly
                val queryRecognizer = if (isOnDeviceAvailable) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }

                queryRecognizer.checkRecognitionSupport(
                    intent,
                    ContextCompat.getMainExecutor(context),
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                            val installedList = recognitionSupport.installedOnDeviceLanguages
                            val supportedList = recognitionSupport.supportedOnDeviceLanguages
                            val onlineList = recognitionSupport.onlineLanguages

                            val isInstalled = matchesLocaleInList(requestedLocale, installedList)
                            val isSupported = matchesLocaleInList(requestedLocale, supportedList)
                            val isOnline = matchesLocaleInList(requestedLocale, onlineList) || isGeneralRecognitionAvailable

                            val response = mapOf(
                                "isRecognitionAvailable" to isGeneralRecognitionAvailable,
                                "isOnDeviceAvailable" to isOnDeviceAvailable,
                                "isOfflineLocaleInstalled" to isInstalled,
                                "isOfflineLocaleSupported" to isSupported,
                                "isOnlineAvailable" to isOnline,
                                "installedOfflineLanguages" to installedList,
                                "androidApiVersion" to Build.VERSION.SDK_INT,
                                "statusMessage" to if (isInstalled) "Offline language pack ready" else "Offline language pack not installed"
                            )

                            try {
                                queryRecognizer.destroy()
                            } catch (_: Exception) {}

                            mainHandler.post {
                                result.success(response)
                            }
                        }

                        override fun onError(errorCode: Int) {
                            try {
                                queryRecognizer.destroy()
                            } catch (_: Exception) {}

                            // Fallback response based on isOnDeviceAvailable
                            val response = mapOf(
                                "isRecognitionAvailable" to isGeneralRecognitionAvailable,
                                "isOnDeviceAvailable" to isOnDeviceAvailable,
                                "isOfflineLocaleInstalled" to false,
                                "isOfflineLocaleSupported" to isOnDeviceAvailable,
                                "isOnlineAvailable" to isGeneralRecognitionAvailable,
                                "installedOfflineLanguages" to emptyList<String>(),
                                "androidApiVersion" to Build.VERSION.SDK_INT,
                                "statusMessage" to "Recognition support query returned code $errorCode"
                            )
                            mainHandler.post {
                                result.success(response)
                            }
                        }
                    }
                )
                return
            } catch (e: Exception) {
                // If checkRecognitionSupport fails, fall back to basic heuristics
            }
        }

        // Fallback for API < 33 or when checkRecognitionSupport fails
        val response = mapOf(
            "isRecognitionAvailable" to isGeneralRecognitionAvailable,
            "isOnDeviceAvailable" to isOnDeviceAvailable,
            "isOfflineLocaleInstalled" to false, // Cannot guarantee without checkRecognitionSupport
            "isOfflineLocaleSupported" to isOnDeviceAvailable,
            "isOnlineAvailable" to isGeneralRecognitionAvailable,
            "installedOfflineLanguages" to emptyList<String>(),
            "androidApiVersion" to Build.VERSION.SDK_INT,
            "statusMessage" to if (isOnDeviceAvailable) "On-device engine present" else "Online recognition available"
        )
        result.success(response)
    }

    private fun matchesLocaleInList(targetLocale: String, list: List<String>): Boolean {
        if (list.isEmpty()) return false
        val targetNormalized = targetLocale.replace("_", "-").lowercase(Locale.ROOT)
        val targetLangOnly = targetNormalized.split("-")[0]

        return list.any { item ->
            val itemNormalized = item.replace("_", "-").lowercase(Locale.ROOT)
            val itemLangOnly = itemNormalized.split("-")[0]
            itemNormalized == targetNormalized || itemLangOnly == targetLangOnly
        }
    }

    // --- Model Download ---

    private fun triggerModelDownload(locale: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val recognizer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }

                val downloadIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                }

                recognizer.triggerModelDownload(downloadIntent)
                result.success(true)
                return
            } catch (e: Exception) {
                // Fallback to opening settings
            }
        }

        // Fallback: Open system voice or locale settings
        openVoiceSettings(result)
    }

    private fun openVoiceSettings(result: MethodChannel.Result) {
        val intents: List<Intent> = listOf(
            Intent("com.google.android.googlequicksearchbox.action.MANUAL_DOWNLOAD").apply {
                addCategory(Intent.CATEGORY_DEFAULT)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent(Settings.ACTION_VOICE_INPUT_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent(Settings.ACTION_LOCALE_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )

        for (intent in intents) {
            try {
                if (intent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(intent)
                    result.success(true)
                    return
                }
            } catch (_: Exception) {}
        }

        result.success(false)
    }

    // --- Speech Recognition Listening ---

    private fun startListening(mode: String, locale: String, result: MethodChannel.Result) {
        if (!hasAudioPermission()) {
            result.error("PERMISSION_DENIED", "RECORD_AUDIO permission is required.", null)
            return
        }

        activeMode = mode
        activeLocale = locale

        mainHandler.post {
            try {
                destroyRecognizer()

                val recognizer = if (mode == "offline") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                    } else {
                        SpeechRecognizer.createSpeechRecognizer(context)
                    }
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }

                speechRecognizer = recognizer

                val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)

                    if (mode == "offline") {
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                }

                recognizer.setRecognitionListener(createRecognitionListener())
                recognizer.startListening(recognizerIntent)
                isListening = true

                result.success(true)
            } catch (e: Exception) {
                isListening = false
                result.error("RECOGNITION_ERROR", "Failed to start recognition: ${e.message}", null)
            }
        }
    }

    private fun stopListening(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                isListening = false
                result.success(true)
            } catch (e: Exception) {
                result.error("STOP_ERROR", e.message, null)
            }
        }
    }

    private fun cancelListening(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                destroyRecognizer()
                isListening = false
                result.success(true)
            } catch (e: Exception) {
                result.error("CANCEL_ERROR", e.message, null)
            }
        }
    }

    private fun destroyRecognizer() {
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
        isListening = false
    }

    private fun createRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                sendEvent(mapOf("event" to "ready"))
            }

            override fun onBeginningOfSpeech() {
                sendEvent(mapOf("event" to "beginning"))
            }

            override fun onRmsChanged(rmsdB: Float) {
                sendEvent(mapOf("event" to "rms", "rmsdB" to rmsdB))
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                sendEvent(mapOf("event" to "endOfSpeech"))
            }

            override fun onError(error: Int) {
                isListening = false
                val message = getErrorMessage(error)
                sendEvent(mapOf(
                    "event" to "error",
                    "code" to error,
                    "message" to message,
                    "mode" to activeMode
                ))
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val scores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

                val primaryText = matches?.firstOrNull() ?: ""
                val confidence = scores?.firstOrNull()?.toDouble() ?: 1.0

                sendEvent(mapOf(
                    "event" to "result",
                    "text" to primaryText,
                    "alternatives" to (matches ?: emptyList<String>()),
                    "confidence" to confidence,
                    "mode" to activeMode
                ))
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val partialText = matches?.firstOrNull() ?: ""
                if (partialText.isNotEmpty()) {
                    sendEvent(mapOf(
                        "event" to "partial",
                        "text" to partialText,
                        "mode" to activeMode
                    ))
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    private fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client-side recognition error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error during online recognition"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout during online recognition"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognition match found"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognition engine busy"
            SpeechRecognizer.ERROR_SERVER -> "Recognition server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input detected"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "Language not supported for chosen recognition mode"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "Language model not available on-device"
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "Recognition server disconnected"
            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "Too many recognition requests"
            else -> "Speech recognition error code: $errorCode"
        }
    }

    private fun sendEvent(eventData: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(eventData)
        }
    }

    // --- EventChannel.StreamHandler ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        destroyRecognizer()
    }
}
