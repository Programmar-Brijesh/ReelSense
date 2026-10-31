package `in`.developerbrijesh.reelsense.gestures

import android.content.Context
import android.util.Log
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import org.json.JSONArray
import kotlin.math.max

class CustomGestureClassifier(context: Context? = null) {

    companion object {
        private const val TAG = "ReelSenseCustomClf"
        private const val PREFS_NAME = "reelsense_custom_gestures"
        private const val KEY_GESTURES_JSON = "custom_gestures_json"
        const val CONFLICT_SIMILARITY_THRESHOLD = 0.82f

        val sharedTemplates = ArrayList<CustomGestureTemplate>()

        fun loadFromPrefs(context: Context): List<CustomGestureTemplate> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(KEY_GESTURES_JSON, null) ?: return emptyList()
            return parseTemplatesFromJson(jsonStr)
        }

        fun saveToPrefs(context: Context, jsonStr: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_GESTURES_JSON, jsonStr).apply()
        }

        fun parseTemplatesFromJson(jsonStr: String): List<CustomGestureTemplate> {
            return try {
                val array = JSONArray(jsonStr)
                val list = ArrayList<CustomGestureTemplate>()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val id = obj.getString("id")
                    val name = obj.getString("name")
                    val action = obj.getString("action")
                    val templateJson = obj.getString("templateJson")
                    val threshold = obj.optDouble("confidenceThreshold", 0.82).toFloat()
                    val isEnabled = obj.optBoolean("isEnabled", true)
                    val t = CustomGestureTemplate.fromJson(templateJson, id, name, action, threshold, isEnabled)
                    if (t != null) list.add(t)
                }
                list
            } catch (e: Exception) {
                Log.w(TAG, "Error parsing templates JSON: ${e.message}")
                emptyList()
            }
        }
    }

    private val templates = ArrayList<CustomGestureTemplate>()

    init {
        if (context != null) {
            val cached = loadFromPrefs(context)
            if (cached.isNotEmpty()) {
                updateTemplates(cached)
            }
        } else if (sharedTemplates.isNotEmpty()) {
            updateTemplates(sharedTemplates)
        }
    }

    data class MatchResult(
        val template: CustomGestureTemplate,
        val similarity: Float
    )

    data class ConflictResult(
        val hasConflict: Boolean,
        val conflictingGestureName: String? = null,
        val isDefaultGesture: Boolean = false,
        val similarity: Float = 0f,
        val reason: String? = null
    )

    fun reloadTemplatesFromPrefs(ctx: Context) {
        val cached = loadFromPrefs(ctx)
        updateTemplates(cached)
        Log.i(TAG, "Reloaded ${cached.size} templates from SharedPreferences.")
    }

    @Synchronized
    fun updateTemplates(newTemplates: List<CustomGestureTemplate>) {
        templates.clear()
        templates.addAll(newTemplates)
        synchronized(sharedTemplates) {
            sharedTemplates.clear()
            sharedTemplates.addAll(newTemplates)
        }
        Log.i(TAG, "Updated custom gesture templates: count=${templates.size}")
    }

    @Synchronized
    fun getTemplates(): List<CustomGestureTemplate> = ArrayList(templates)

    /**
     * Classifies normalized landmarks against all enabled custom gestures.
     * Returns the best match exceeding the gesture's confidence threshold.
     */
    @Synchronized
    fun classify(normalizedLandmarks: List<Point3D>): MatchResult? {
        if (normalizedLandmarks.size < 21) {
            Log.d(TAG, "Classification rejected: Insufficient landmarks (${normalizedLandmarks.size} < 21).")
            return null
        }

        val currentTemplates = if (templates.isNotEmpty()) templates else sharedTemplates
        if (currentTemplates.isEmpty()) {
            Log.d(TAG, "Classification rejected: No custom gesture templates loaded.")
            return null
        }

        var bestMatch: CustomGestureTemplate? = null
        var highestSimilarity = 0f
        var bestCandidateName: String? = null
        var rejectionReason: String? = null

        for (template in currentTemplates) {
            if (!template.isEnabled) {
                Log.d(TAG, "Template '${template.name}' (id=${template.id}) is disabled. Skipping.")
                continue
            }

            val similarity = computeSimilarity(normalizedLandmarks, template.landmarks)
            val passes = similarity >= template.confidenceThreshold

            Log.d(TAG, "Candidate '${template.name}' (id=${template.id}): " +
                    "enabled=${template.isEnabled}, " +
                    "landmarks=${template.landmarks.size}, " +
                    "similarity=${String.format("%.3f", similarity)}, " +
                    "threshold=${template.confidenceThreshold}, " +
                    "status=${if (passes) "PASSED" else "REJECTED_BELOW_THRESHOLD"}")

            if (passes && similarity > highestSimilarity) {
                highestSimilarity = similarity
                bestMatch = template
                bestCandidateName = template.name
            } else if (similarity > highestSimilarity) {
                highestSimilarity = similarity
                bestCandidateName = template.name
                rejectionReason = "Similarity (${String.format("%.3f", similarity)}) < required threshold (${template.confidenceThreshold})"
            }
        }

        return if (bestMatch != null) {
            Log.i(TAG, "Classification MATCH! Best gesture='${bestMatch.name}' (id=${bestMatch.id}), " +
                    "similarity=${String.format("%.3f", highestSimilarity)} >= threshold=${bestMatch.confidenceThreshold}, " +
                    "action=${bestMatch.action}")
            MatchResult(bestMatch, highestSimilarity)
        } else {
            Log.d(TAG, "Classification REJECTED. Best candidate='${bestCandidateName ?: "None"}', " +
                    "reason: ${rejectionReason ?: "no enabled templates"}")
            null
        }
    }

    /**
     * Validates whether a candidate template conflicts with:
     * 1. Any default gesture (Open Palm, Thumbs Up, Only Index, Index + Middle)
     * 2. Any already registered custom gesture
     */
    @Synchronized
    fun validateConflict(
        candidateTemplate: List<Point3D>,
        defaultClassifier: GestureClassifier,
        rawLandmarks: List<NormalizedLandmark>?,
        excludeGestureId: String? = null
    ): ConflictResult {
        // 1. Check against default gestures if raw landmarks available
        if (rawLandmarks != null && rawLandmarks.size >= 21) {
            val defaultMatch = defaultClassifier.classify(rawLandmarks)
            if (defaultMatch != HandGesture.UNKNOWN) {
                return ConflictResult(
                    hasConflict = true,
                    conflictingGestureName = defaultMatch.displayName,
                    isDefaultGesture = true,
                    similarity = 0.95f,
                    reason = "This hand pose conflicts with default gesture: '${defaultMatch.displayName}'"
                )
            }
        }

        val currentTemplates = if (templates.isNotEmpty()) templates else sharedTemplates

        // 2. Check against all existing custom gestures
        for (existing in currentTemplates) {
            if (excludeGestureId != null && existing.id == excludeGestureId) continue

            val similarity = computeSimilarity(candidateTemplate, existing.landmarks)
            if (similarity >= CONFLICT_SIMILARITY_THRESHOLD) {
                val percentage = (similarity * 100).toInt()
                return ConflictResult(
                    hasConflict = true,
                    conflictingGestureName = existing.name,
                    isDefaultGesture = false,
                    similarity = similarity,
                    reason = "This hand pose is too similar to existing custom gesture '${existing.name}' ($percentage% match)"
                )
            }
        }

        return ConflictResult(hasConflict = false)
    }

    /**
     * Computes similarity between two normalized 21-landmark poses.
     * Scale: 0.0 (completely dissimilar) to 1.0 (identical pose).
     * In HandLandmarkNormalizer, wrist-to-MCP9 (palmSize) is normalized to 1.0f.
     * 1.0f represents the canonical unit distance scale of the hand.
     */
    fun computeSimilarity(pointsA: List<Point3D>, pointsB: List<Point3D>): Float {
        if (pointsA.size < 21 || pointsB.size < 21) return 0f

        var totalDist = 0f
        var maxDist = 0f

        for (i in 0 until 21) {
            val dist = pointsA[i].distanceTo(pointsB[i])
            totalDist += dist
            if (dist > maxDist) {
                maxDist = dist
            }
        }

        val meanDist = totalDist / 21f
        // Weighted distance combining average point error (70%) and max point error (30%)
        val weightedDist = (meanDist * 0.70f) + (maxDist * 0.30f)

        // palmSize (wrist to MCP9) is normalized to 1.0f; 1.0f is the canonical unit scale of the hand
        val score = 1.0f - (weightedDist / 1.0f)
        return max(0f, score)
    }
}
