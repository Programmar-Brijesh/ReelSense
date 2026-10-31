package `in`.developerbrijesh.reelsense.gestures

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class GestureCameraManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val onActionTriggered: (gestureName: String, action: String) -> Unit,
    private val onStateUpdated: (gestureName: String?, isHandPresent: Boolean, action: String?) -> Unit
) {

    companion object {
        private const val TAG = "ReelSenseGesture"
    }

    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var cameraExecutor: ExecutorService? = null

    val classifier = GestureClassifier()
    private val landmarkerHelper = HandLandmarkerHelper(context)

    private val stateMachine = GestureStateMachine(
        requiredConsecutiveFrames = 4,
        actionCooldownMs = 1200L,
        requiredNeutralFrames = 3,
        onActionTriggered = { gestureName, action ->
            onActionTriggered(gestureName, action)
        }
    )

    private var isAnalyzing = false

    init {
        stateMachine.onGestureStateChanged = { gestureName, isHandPresent, action ->
            onStateUpdated(gestureName, isHandPresent, action)
        }
    }

    fun start() {
        if (isAnalyzing) {
            Log.i(TAG, "Gesture camera analysis already active.")
            return
        }

        if (!landmarkerHelper.isInitialized()) {
            Log.e(TAG, "MediaPipe HandLandmarkerHelper is not initialized.")
            return
        }

        cameraExecutor = Executors.newSingleThreadExecutor()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()

                // Front camera selector
                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                    .build()

                // Resolution: 640x480 for fast on-device inference
                imageAnalysis = ImageAnalysis.Builder()
                    .setTargetResolution(Size(640, 480))
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                    .also { analysis ->
                        analysis.setAnalyzer(cameraExecutor!!) { imageProxy ->
                            processImageProxy(imageProxy)
                        }
                    }

                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    imageAnalysis
                )

                isAnalyzing = true
                Log.i(TAG, "CameraX front camera bound and analyzing frames.")
            } catch (e: Exception) {
                Log.e(TAG, "Use case binding failed: ${e.message}", e)
                isAnalyzing = false
            }
        }, ContextCompat.getMainExecutor(context))
    }

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun processImageProxy(imageProxy: ImageProxy) {
        try {
            val bitmap = imageProxy.toBitmap()
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees

            val processedBitmap = if (rotationDegrees != 0) {
                val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
                Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            } else {
                bitmap
            }

            val detectionResult = landmarkerHelper.detect(processedBitmap)

            if (detectionResult != null && detectionResult.landmarks().isNotEmpty()) {
                val handLandmarks = detectionResult.landmarks()[0]

                // Live Gesture Control Mode (Instagram Active)
                val defaultGesture = classifier.classify(handLandmarks)
                if (defaultGesture != HandGesture.UNKNOWN) {
                    Log.i(TAG, "Hand detected! Classified default gesture: ${defaultGesture.displayName}")
                    stateMachine.processFrame(defaultGesture, isHandPresent = true)
                } else {
                    stateMachine.processCandidate(null, isHandPresent = true)
                }
            } else {
                stateMachine.processCandidate(null, isHandPresent = false)
            }

            // Cleanup bitmaps
            if (processedBitmap != bitmap) {
                processedBitmap.recycle()
            }
            bitmap.recycle()
        } catch (e: Exception) {
            Log.w(TAG, "Frame analysis exception: ${e.message}")
        } finally {
            imageProxy.close()
        }
    }

    fun stop() {
        Log.i(TAG, "Stopping CameraX gesture analysis...")
        isAnalyzing = false
        stateMachine.reset()

        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.w(TAG, "Error unbinding camera use cases: ${e.message}")
        }

        try {
            cameraExecutor?.shutdown()
            cameraExecutor = null
        } catch (_: Exception) {}
    }

    fun release() {
        stop()
        landmarkerHelper.close()
    }
}
