package `in`.developerbrijesh.reelsense.gestures

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import `in`.developerbrijesh.reelsense.service.ReelSenseMonitoringService
import org.json.JSONArray
import org.json.JSONObject

class GestureHandler(
    private val context: Context,
    private var activity: Activity?
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val METHOD_CHANNEL = "in.developerbrijesh.reelsense/gestures"
        const val EVENT_CHANNEL = "in.developerbrijesh.reelsense/gesture_events"
        private const val PERMISSION_REQUEST_CAMERA = 2002
        private const val TAG = "ReelSenseGestureHandler"

        @Volatile
        var instance: GestureHandler? = null
            private set
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPermissionResult: MethodChannel.Result? = null

    // Dedicated CameraManager for registration and live testing inside Flutter app
    private var previewCameraManager: GestureCameraManager? = null

    fun register(messenger: BinaryMessenger) {
        instance = this
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@GestureHandler)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@GestureHandler)
        }
    }

    fun setActivity(act: Activity?) {
        this.activity = act
    }

    fun unregister() {
        stopPreviewCamera()
        if (instance == this) instance = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCameraPermission" -> {
                result.success(hasCameraPermission())
            }
            "requestCameraPermission" -> {
                requestCameraPermission(result)
            }
            "isFrontCameraAvailable" -> {
                result.success(isFrontCameraAvailable())
            }
            "getGestureMappings" -> {
                val mappings = HandGesture.entries
                    .filter { it.action != null }
                    .map {
                        mapOf(
                            "gesture" to it.name,
                            "displayName" to it.displayName,
                            "action" to it.action
                        )
                    }
                result.success(mappings)
            }
            "syncCustomGestures" -> {
                handleSyncCustomGestures(call, result)
            }
            "startGestureRegistration" -> {
                handleStartGestureRegistration(result)
            }
            "stopGestureRegistration" -> {
                handleStopGestureRegistration(result)
            }
            "startGestureTest" -> {
                handleStartGestureTest(result)
            }
            "stopGestureTest" -> {
                handleStopGestureTest(result)
            }
            "validateGestureConflict" -> {
                handleValidateGestureConflict(call, result)
            }
            else -> result.notImplemented()
        }
    }

    // --- Custom Gestures Synchronization ---

    private fun handleSyncCustomGestures(call: MethodCall, result: MethodChannel.Result) {
        val tagSync = "ReelSenseGestureSync"
        try {
            val list = call.argument<List<Map<String, Any>>>("gestures") ?: emptyList()
            val jsonArray = JSONArray()
            val templates = ArrayList<CustomGestureTemplate>()

            Log.i(tagSync, "handleSyncCustomGestures: received ${list.size} gestures from Flutter.")

            for (map in list) {
                val id = map["id"] as? String ?: continue
                val name = map["name"] as? String ?: continue
                val action = map["action"] as? String ?: continue
                val templateJson = map["templateJson"] as? String ?: continue
                val threshold = (map["confidenceThreshold"] as? Number)?.toFloat() ?: 0.82f
                val isEnabled = map["isEnabled"] as? Boolean ?: true

                val obj = JSONObject().apply {
                    put("id", id)
                    put("name", name)
                    put("action", action)
                    put("templateJson", templateJson)
                    put("confidenceThreshold", threshold)
                    put("isEnabled", isEnabled)
                }
                jsonArray.put(obj)

                val t = CustomGestureTemplate.fromJson(templateJson, id, name, action, threshold, isEnabled)
                if (t != null) {
                    templates.add(t)
                    Log.d(tagSync, "Parsed gesture: id=$id, name='$name', action=$action, threshold=$threshold, enabled=$isEnabled, landmarks=${t.landmarks.size}")
                } else {
                    Log.w(tagSync, "Failed to parse template for gesture id=$id, name='$name'")
                }
            }

            // Save to shared preferences cache
            CustomGestureClassifier.saveToPrefs(context, jsonArray.toString())
            CustomGestureClassifier.sharedTemplates.clear()
            CustomGestureClassifier.sharedTemplates.addAll(templates)

            previewCameraManager?.updateCustomTemplates(templates)
            ReelSenseMonitoringService.instance?.updateCustomGestures(templates)

            Log.i(tagSync, "Successfully synced ${templates.size} custom gestures to SharedPreferences, sharedTemplates, and active engines.")
            result.success(true)
        } catch (e: Exception) {
            Log.e(tagSync, "Failed to sync custom gestures: ${e.message}", e)
            result.error("SYNC_ERROR", e.message, null)
        }
    }

    // --- Custom Gesture Registration Session ---

    private fun handleStartGestureRegistration(result: MethodChannel.Result) {
        val owner = activity as? LifecycleOwner
        if (owner == null) {
            result.error("NO_LIFECYCLE", "Activity does not implement LifecycleOwner", null)
            return
        }

        if (!hasCameraPermission()) {
            result.error("NO_PERMISSION", "Camera permission is required for gesture registration", null)
            return
        }

        ensurePreviewCamera(owner)
        previewCameraManager?.startRegistration { sampleCount, targetCount, isHandPresent, isComplete, templateJson, error ->
            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "type" to "registration_progress",
                        "sampleCount" to sampleCount,
                        "targetCount" to targetCount,
                        "isHandPresent" to isHandPresent,
                        "isComplete" to isComplete,
                        "templateJson" to templateJson,
                        "error" to error
                    )
                )
            }
        }
        result.success(true)
    }

    private fun handleStopGestureRegistration(result: MethodChannel.Result) {
        previewCameraManager?.stopRegistration()
        stopPreviewCamera()
        result.success(true)
    }

    // --- Custom Gesture Test Session ---

    private fun handleStartGestureTest(result: MethodChannel.Result) {
        val owner = activity as? LifecycleOwner
        if (owner == null) {
            result.error("NO_LIFECYCLE", "Activity does not implement LifecycleOwner", null)
            return
        }

        if (!hasCameraPermission()) {
            result.error("NO_PERMISSION", "Camera permission is required for testing gestures", null)
            return
        }

        ensurePreviewCamera(owner)
        previewCameraManager?.startTest { gestureName, similarity, action, isHandPresent ->
            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "type" to "test_event",
                        "gestureName" to gestureName,
                        "similarity" to similarity,
                        "action" to action,
                        "isHandPresent" to isHandPresent
                    )
                )
            }
        }
        result.success(true)
    }

    private fun handleStopGestureTest(result: MethodChannel.Result) {
        previewCameraManager?.stopTest()
        stopPreviewCamera()
        result.success(true)
    }

    // --- Conflict Validation ---

    private fun handleValidateGestureConflict(call: MethodCall, result: MethodChannel.Result) {
        val templateJson = call.argument<String>("templateJson")
        val excludeId = call.argument<String>("excludeGestureId")

        if (templateJson.isNullOrBlank()) {
            result.error("INVALID_ARGS", "templateJson is required", null)
            return
        }

        val cameraMgr = previewCameraManager
        val conflictResult = if (cameraMgr != null) {
            cameraMgr.validateConflict(templateJson, excludeId)
        } else {
            val classifier = GestureClassifier()
            val customClf = CustomGestureClassifier(context)
            try {
                val array = JSONArray(templateJson)
                val points = ArrayList<Point3D>(array.length())
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    points.add(
                        Point3D(
                            x = obj.getDouble("x").toFloat(),
                            y = obj.getDouble("y").toFloat(),
                            z = obj.getDouble("z").toFloat()
                        )
                    )
                }
                customClf.validateConflict(points, classifier, null, excludeId)
            } catch (e: Exception) {
                CustomGestureClassifier.ConflictResult(hasConflict = true, reason = e.message)
            }
        }

        result.success(
            mapOf(
                "hasConflict" to conflictResult.hasConflict,
                "conflictingGestureName" to conflictResult.conflictingGestureName,
                "isDefaultGesture" to conflictResult.isDefaultGesture,
                "similarity" to conflictResult.similarity,
                "reason" to conflictResult.reason
            )
        )
    }

    private fun ensurePreviewCamera(owner: LifecycleOwner) {
        if (previewCameraManager == null) {
            previewCameraManager = GestureCameraManager(
                context = context,
                lifecycleOwner = owner,
                onActionTriggered = { _, _ -> /* Never execute actions in preview mode */ },
                onStateUpdated = { _, _, _ -> }
            )
        }
    }

    private fun stopPreviewCamera() {
        previewCameraManager?.stop()
        previewCameraManager?.release()
        previewCameraManager = null
    }

    // --- EventChannel Streaming ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    fun sendGestureEvent(gesture: HandGesture, isHandPresent: Boolean, actionExecuted: String? = null) {
        sendGestureEvent(gesture.displayName, isHandPresent, actionExecuted)
    }

    fun sendGestureEvent(gestureName: String, isHandPresent: Boolean, actionExecuted: String? = null) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "type" to "gesture_event",
                    "displayName" to gestureName,
                    "isHandPresent" to isHandPresent,
                    "actionExecuted" to actionExecuted
                )
            )
        }
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (hasCameraPermission()) {
            result.success(true)
            return
        }

        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Cannot request camera permission: Activity is null", null)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            act,
            arrayOf(Manifest.permission.CAMERA),
            PERMISSION_REQUEST_CAMERA
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CAMERA) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    private fun isFrontCameraAvailable(): Boolean {
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
                ?: return false
            val cameraIds = cameraManager.cameraIdList
            cameraIds.any { id ->
                val chars = cameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                facing == CameraCharacteristics.LENS_FACING_FRONT
            }
        } catch (_: Exception) {
            false
        }
    }
}
