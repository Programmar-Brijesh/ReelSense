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
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

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

    fun register(messenger: BinaryMessenger) {
        instance = this
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@GestureHandler)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@GestureHandler)
        }
    }

    fun unregister() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
        if (instance == this) {
            instance = null
        }
    }

    fun setActivity(act: Activity?) {
        this.activity = act
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
            else -> result.notImplemented()
        }
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
