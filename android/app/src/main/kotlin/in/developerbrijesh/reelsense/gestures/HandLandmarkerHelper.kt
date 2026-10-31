package `in`.developerbrijesh.reelsense.gestures

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

class HandLandmarkerHelper(
    private val context: Context,
    private val minConfidence: Float = 0.5f
) {

    companion object {
        private const val TAG = "HandLandmarkerHelper"
        private const val MODEL_NAME = "hand_landmarker.task"
    }

    private var handLandmarker: HandLandmarker? = null

    init {
        setupHandLandmarker()
    }

    private fun setupHandLandmarker() {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(MODEL_NAME)
                .build()

            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setMinHandDetectionConfidence(minConfidence)
                .setMinHandPresenceConfidence(minConfidence)
                .setMinTrackingConfidence(minConfidence)
                .setNumHands(1)
                .setRunningMode(RunningMode.IMAGE)
                .build()

            handLandmarker = HandLandmarker.createFromOptions(context, options)
            Log.d(TAG, "MediaPipe HandLandmarker initialized successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize MediaPipe HandLandmarker: ${e.message}", e)
            handLandmarker = null
        }
    }

    fun isInitialized(): Boolean = handLandmarker != null

    @Synchronized
    fun detect(bitmap: Bitmap): HandLandmarkerResult? {
        val landmarker = handLandmarker ?: return null
        return try {
            val mpImage = BitmapImageBuilder(bitmap).build()
            landmarker.detect(mpImage)
        } catch (e: Exception) {
            Log.w(TAG, "Hand landmark detection failed: ${e.message}")
            null
        }
    }

    @Synchronized
    fun close() {
        try {
            handLandmarker?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing HandLandmarker: ${e.message}")
        } finally {
            handLandmarker = null
        }
    }
}
