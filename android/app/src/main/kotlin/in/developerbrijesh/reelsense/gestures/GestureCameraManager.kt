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
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import org.json.JSONArray
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
    val customClassifier = CustomGestureClassifier(context)
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

    // Registration and testing flags
    @Volatile var isRegistrationMode = false
        private set
    @Volatile var isTestMode = false
        private set

    private var trainer: CustomGestureTrainer? = null
    private var onRegistrationProgress: ((sampleCount: Int, targetCount: Int, isHandPresent: Boolean, isComplete: Boolean, templateJson: String?, error: String?) -> Unit)? = null
    private var onTestResult: ((gestureName: String?, similarity: Float, action: String?, isHandPresent: Boolean) -> Unit)? = null

    // Cached raw landmarks for conflict verification during registration
    @Volatile var lastDetectedRawLandmarks: List<NormalizedLandmark>? = null
        private set

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
            Log.e(TAG, "Cannot start camera: HandLandmarker model not initialized.")
            return
        }

        Log.i(TAG, "Starting CameraX gesture analysis...")
        cameraExecutor = Executors.newSingleThreadExecutor()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases()
                isAnalyzing = true
                Log.i(TAG, "CameraX front camera bound and analyzing frames.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize CameraX: ${e.message}", e)
                stop()
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: return
        val executor = cameraExecutor ?: return

        provider.unbindAll()

        // Prefer front camera for selfie/hand gesture control
        val cameraSelector = if (provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            Log.w(TAG, "Front camera not found, falling back to default back camera.")
            CameraSelector.DEFAULT_BACK_CAMERA
        }

        imageAnalysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(480, 640))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { analysis ->
                analysis.setAnalyzer(executor) { imageProxy ->
                    processImageProxy(imageProxy)
                }
            }

        try {
            provider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                imageAnalysis
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error binding CameraX use case to lifecycle: ${e.message}", e)
        }
    }

    private fun processImageProxy(imageProxy: ImageProxy) {
        if (!isAnalyzing) {
            imageProxy.close()
            return
        }

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
                lastDetectedRawLandmarks = handLandmarks

                // Case 1: Custom Gesture Registration Mode
                if (isRegistrationMode) {
                    trainer?.processFrame(handLandmarks)
                    return
                }

                // Case 2: Custom Gesture Test Mode (No action dispatch)
                if (isTestMode) {
                    // Check default classifier first
                    val defaultGesture = classifier.classify(handLandmarks)
                    if (defaultGesture != HandGesture.UNKNOWN) {
                        onTestResult?.invoke(defaultGesture.displayName, 1.0f, defaultGesture.action, true)
                        return
                    }

                    // Then evaluate custom gesture classifier
                    val normalized = HandLandmarkNormalizer.normalize(handLandmarks)
                    val customMatch = if (normalized != null) customClassifier.classify(normalized) else null
                    if (customMatch != null) {
                        onTestResult?.invoke(customMatch.template.name, customMatch.similarity, customMatch.template.action, true)
                    } else {
                        onTestResult?.invoke(null, 0f, null, true)
                    }
                    return
                }

                // Case 3: Live Gesture Control Mode (Instagram Active)
                val defaultGesture = classifier.classify(handLandmarks)
                if (defaultGesture != HandGesture.UNKNOWN) {
                    Log.i(TAG, "Hand detected! Classified default gesture: ${defaultGesture.displayName}")
                    stateMachine.processFrame(defaultGesture, isHandPresent = true)
                } else {
                    // Check registered custom gestures
                    val normalized = HandLandmarkNormalizer.normalize(handLandmarks)
                    val customMatch = if (normalized != null) customClassifier.classify(normalized) else null
                    if (customMatch != null) {
                        Log.i(TAG, "Hand detected! Classified custom gesture: ${customMatch.template.name} (${(customMatch.similarity * 100).toInt()}%) -> Action: ${customMatch.template.action}")
                        stateMachine.processCustomFrame(customMatch.template, isHandPresent = true)
                    } else {
                        stateMachine.processCandidate(null, isHandPresent = true)
                    }
                }
            } else {
                lastDetectedRawLandmarks = null
                if (isRegistrationMode) {
                    trainer?.processFrame(null)
                } else if (isTestMode) {
                    onTestResult?.invoke(null, 0f, null, false)
                } else {
                    stateMachine.processCandidate(null, isHandPresent = false)
                }
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

    // --- Custom Gesture Training Session ---

    fun startRegistration(onProgress: (sampleCount: Int, targetCount: Int, isHandPresent: Boolean, isComplete: Boolean, templateJson: String?, error: String?) -> Unit) {
        isTestMode = false
        isRegistrationMode = true
        onRegistrationProgress = onProgress

        val newTrainer = CustomGestureTrainer(
            targetSampleCount = 25,
            maxAllowedVariance = 0.35f,
            onProgressUpdate = { sampleCount, targetCount, isHandPresent, isComplete, templateJson, error ->
                onRegistrationProgress?.invoke(sampleCount, targetCount, isHandPresent, isComplete, templateJson, error)
            }
        )
        trainer = newTrainer
        newTrainer.start()
        start()
    }

    fun stopRegistration() {
        isRegistrationMode = false
        trainer?.stop()
        trainer = null
        onRegistrationProgress = null
        stop()
    }

    // --- Custom Gesture Testing Session ---

    fun startTest(onResult: (gestureName: String?, similarity: Float, action: String?, isHandPresent: Boolean) -> Unit) {
        isRegistrationMode = false
        isTestMode = true
        onTestResult = onResult
        start()
    }

    fun stopTest() {
        isTestMode = false
        onTestResult = null
        stop()
    }

    // --- Custom Gesture Templates Synchronization ---

    fun updateCustomTemplates(templates: List<CustomGestureTemplate>) {
        customClassifier.updateTemplates(templates)
    }

    // --- Conflict Validation ---

    fun validateConflict(templateJson: String, excludeGestureId: String? = null): CustomGestureClassifier.ConflictResult {
        return try {
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
            customClassifier.validateConflict(
                candidateTemplate = points,
                defaultClassifier = classifier,
                rawLandmarks = lastDetectedRawLandmarks,
                excludeGestureId = excludeGestureId
            )
        } catch (e: Exception) {
            CustomGestureClassifier.ConflictResult(
                hasConflict = true,
                reason = "Invalid gesture template data: ${e.message}"
            )
        }
    }

    fun stop() {
        Log.i(TAG, "Stopping CameraX gesture analysis...")
        isAnalyzing = false
        isRegistrationMode = false
        isTestMode = false
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
