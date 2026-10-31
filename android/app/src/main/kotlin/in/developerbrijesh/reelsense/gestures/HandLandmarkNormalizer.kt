package `in`.developerbrijesh.reelsense.gestures

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

object HandLandmarkNormalizer {

    private const val WRIST = 0
    private const val INDEX_MCP = 5
    private const val MIDDLE_MCP = 9
    private const val PINKY_MCP = 17

    /**
     * Normalizes 21 MediaPipe hand landmarks to make them:
     * 1. Translation invariant (Wrist at 0,0,0)
     * 2. Scale invariant (Normalized by wrist-to-middle-MCP palm size)
     * 3. Rotation invariant (Aligned along canonical vertical axis)
     * 4. Handedness invariant (Left/right hands mirrored to canonical orientation)
     */
    fun normalize(landmarks: List<NormalizedLandmark>): List<Point3D>? {
        if (landmarks.size < 21) return null

        val wrist = landmarks[WRIST]
        val middleMcp = landmarks[MIDDLE_MCP]

        val dx9 = middleMcp.x() - wrist.x()
        val dy9 = middleMcp.y() - wrist.y()
        val dz9 = (middleMcp.z() - wrist.z()) * 0.5f

        val palmSize = sqrt((dx9 * dx9) + (dy9 * dy9) + (dz9 * dz9))
        if (palmSize < 0.04f) {
            // Hand is too far away or detection unreliable
            return null
        }

        // In-plane rotation angle to align longitudinal palm axis (wrist -> middle MCP) to vertical
        // In image coordinates, Y points downwards, so canonical up is (0, -1)
        val theta = atan2(dx9, -dy9)
        val cosTheta = cos(-theta)
        val sinTheta = sin(-theta)

        // Translate, scale, and rotate
        val aligned = ArrayList<Point3D>(21)
        for (i in 0 until 21) {
            val lm = landmarks[i]
            val tx = (lm.x() - wrist.x()) / palmSize
            val ty = (lm.y() - wrist.y()) / palmSize
            val tz = (lm.z() - wrist.z()) / palmSize

            val rx = (tx * cosTheta) - (ty * sinTheta)
            val ry = (tx * sinTheta) + (ty * cosTheta)

            aligned.add(Point3D(rx, ry, tz))
        }

        // Handedness normalization: mirror across Y axis if index MCP is to the left of pinky MCP
        val indexMcpX = aligned[INDEX_MCP].x
        val pinkyMcpX = aligned[PINKY_MCP].x
        val shouldMirror = indexMcpX < pinkyMcpX

        return if (shouldMirror) {
            aligned.map { Point3D(-it.x, it.y, it.z) }
        } else {
            aligned
        }
    }
}
