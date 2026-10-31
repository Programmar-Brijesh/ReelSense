package `in`.developerbrijesh.reelsense.gestures

import android.util.Log
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class CustomGestureTrainer(
    private val targetSampleCount: Int = 25,
    private val maxAllowedVariance: Float = 0.35f,
    private val onProgressUpdate: (sampleCount: Int, targetCount: Int, isHandPresent: Boolean, isComplete: Boolean, templateJson: String?, error: String?) -> Unit
) {
    companion object {
        private const val TAG = "ReelSenseTrainer"
    }

    private val samples = ArrayList<List<Point3D>>()
    private var isRecording = false
    private var lastSample: List<Point3D>? = null

    fun start() {
        reset()
        isRecording = true
        Log.i(TAG, "Custom gesture training started. Target samples: $targetSampleCount")
    }

    fun stop() {
        isRecording = false
        Log.i(TAG, "Custom gesture training stopped.")
    }

    fun reset() {
        samples.clear()
        lastSample = null
    }

    @Synchronized
    fun processFrame(rawLandmarks: List<NormalizedLandmark>?) {
        if (!isRecording) return

        if (rawLandmarks == null || rawLandmarks.size < 21) {
            onProgressUpdate(samples.size, targetSampleCount, false, false, null, null)
            return
        }

        val normalized = HandLandmarkNormalizer.normalize(rawLandmarks)
        if (normalized == null) {
            onProgressUpdate(samples.size, targetSampleCount, false, false, null, "Hand too far or unclear")
            return
        }

        // Stability Check: compare with previous sample
        val previous = lastSample
        if (previous != null) {
            var diff = 0f
            for (i in 0 until 21) {
                diff += previous[i].distanceTo(normalized[i])
            }
            val avgDiff = diff / 21f

            if (avgDiff > maxAllowedVariance) {
                // Hand was moved; update lastSample to new pose so user can stabilize hand
                lastSample = normalized
                onProgressUpdate(
                    samples.size,
                    targetSampleCount,
                    true,
                    false,
                    null,
                    "Hold pose steady..."
                )
                return
            }
        }

        samples.add(normalized)
        lastSample = normalized

        if (samples.size >= targetSampleCount) {
            // Training complete! Compute mean golden template
            val averagedTemplate = computeAveragedTemplate(samples)
            val json = CustomGestureTemplate.landmarksToJson(averagedTemplate)
            isRecording = false
            Log.i(TAG, "Training complete with ${samples.size} stable frames.")
            onProgressUpdate(samples.size, targetSampleCount, true, true, json, null)
        } else {
            onProgressUpdate(samples.size, targetSampleCount, true, false, null, null)
        }
    }

    private fun computeAveragedTemplate(allSamples: List<List<Point3D>>): List<Point3D> {
        val count = allSamples.size.toFloat()
        val averaged = ArrayList<Point3D>(21)

        for (i in 0 until 21) {
            var sumX = 0f
            var sumY = 0f
            var sumZ = 0f

            for (sample in allSamples) {
                sumX += sample[i].x
                sumY += sample[i].y
                sumZ += sample[i].z
            }

            averaged.add(Point3D(sumX / count, sumY / count, sumZ / count))
        }

        return averaged
    }
}
