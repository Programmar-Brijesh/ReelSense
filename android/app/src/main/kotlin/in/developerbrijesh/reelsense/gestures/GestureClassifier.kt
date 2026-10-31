package `in`.developerbrijesh.reelsense.gestures

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.sqrt

class GestureClassifier {

    companion object {
        private const val WRIST = 0
        private const val THUMB_CMC = 1
        private const val THUMB_MCP = 2
        private const val THUMB_IP = 3
        private const val THUMB_TIP = 4

        private const val INDEX_MCP = 5
        private const val INDEX_PIP = 6
        private const val INDEX_DIP = 7
        private const val INDEX_TIP = 8

        private const val MIDDLE_MCP = 9
        private const val MIDDLE_PIP = 10
        private const val MIDDLE_DIP = 11
        private const val MIDDLE_TIP = 12

        private const val RING_MCP = 13
        private const val RING_PIP = 14
        private const val RING_DIP = 15
        private const val RING_TIP = 16

        private const val PINKY_MCP = 17
        private const val PINKY_PIP = 18
        private const val PINKY_DIP = 19
        private const val PINKY_TIP = 20
    }

    data class FingerStates(
        val isThumbExtended: Boolean,
        val isThumbPointingUp: Boolean,
        val isIndexExtended: Boolean,
        val isMiddleExtended: Boolean,
        val isRingExtended: Boolean,
        val isPinkyExtended: Boolean
    )

    fun classify(landmarks: List<NormalizedLandmark>): HandGesture {
        if (landmarks.size < 21) return HandGesture.UNKNOWN

        val wrist = landmarks[WRIST]
        val middleMcp = landmarks[MIDDLE_MCP]
        val palmSize = dist(wrist, middleMcp)

        // Hand too small or landmark detection unreliable
        if (palmSize < 0.04f) return HandGesture.UNKNOWN

        // Longitudal palm vector from wrist to middle MCP
        val palmDx = (middleMcp.x() - wrist.x()) / palmSize
        val palmDy = (middleMcp.y() - wrist.y()) / palmSize

        val states = evaluateFingerStates(landmarks, wrist, palmSize, palmDx, palmDy)

        val extendedCount = (if (states.isIndexExtended) 1 else 0) +
                (if (states.isMiddleExtended) 1 else 0) +
                (if (states.isRingExtended) 1 else 0) +
                (if (states.isPinkyExtended) 1 else 0)

        // 1. OPEN_PALM: All 5 fingers extended
        if (states.isIndexExtended && states.isMiddleExtended && states.isRingExtended &&
            states.isPinkyExtended && states.isThumbExtended) {
            return HandGesture.OPEN_PALM
        }

        // 2. THUMBS_UP: Thumb extended upwards, other 4 fingers strictly folded
        if (states.isThumbPointingUp && extendedCount == 0) {
            return HandGesture.THUMBS_UP
        }

        // 3. ONLY INDEX FINGER: Index extended, Middle/Ring/Pinky/Thumb folded
        if (states.isIndexExtended && !states.isMiddleExtended && !states.isRingExtended &&
            !states.isPinkyExtended && !states.isThumbPointingUp) {
            return HandGesture.INDEX_FINGER
        }

        // 4. INDEX + MIDDLE: Index and Middle extended together, Ring/Pinky/Thumb folded
        if (states.isIndexExtended && states.isMiddleExtended && !states.isRingExtended &&
            !states.isPinkyExtended && !states.isThumbPointingUp) {
            // Verify index and middle are roughly parallel/together
            val indexTip = landmarks[INDEX_TIP]
            val middleTip = landmarks[MIDDLE_TIP]
            val tipsSeparation = dist(indexTip, middleTip)
            if (tipsSeparation < palmSize * 0.75f) {
                return HandGesture.INDEX_AND_MIDDLE
            }
        }

        return HandGesture.UNKNOWN
    }

    private fun evaluateFingerStates(
        lm: List<NormalizedLandmark>,
        wrist: NormalizedLandmark,
        palmSize: Float,
        palmDx: Float,
        palmDy: Float
    ): FingerStates {
        val isIndexExtended = isFingerExtended(lm, INDEX_MCP, INDEX_PIP, INDEX_DIP, INDEX_TIP, wrist, palmSize, palmDx, palmDy)
        val isMiddleExtended = isFingerExtended(lm, MIDDLE_MCP, MIDDLE_PIP, MIDDLE_DIP, MIDDLE_TIP, wrist, palmSize, palmDx, palmDy)
        val isRingExtended = isFingerExtended(lm, RING_MCP, RING_PIP, RING_DIP, RING_TIP, wrist, palmSize, palmDx, palmDy)
        val isPinkyExtended = isFingerExtended(lm, PINKY_MCP, PINKY_PIP, PINKY_DIP, PINKY_TIP, wrist, palmSize, palmDx, palmDy)

        val thumbTip = lm[THUMB_TIP]
        val thumbIp = lm[THUMB_IP]
        val thumbMcp = lm[THUMB_MCP]
        val indexMcp = lm[INDEX_MCP]
        val pinkyMcp = lm[PINKY_MCP]

        // Thumb extension from palm
        val thumbDistFromIndex = dist(thumbTip, indexMcp)
        val thumbDistFromPinky = dist(thumbTip, pinkyMcp)
        val isThumbExtended = (thumbDistFromIndex > palmSize * 0.35f) && (thumbDistFromPinky > palmSize * 0.55f)

        // Thumb pointing upwards in image frame (smaller y is higher up on screen)
        val isPointingUpScreen = (thumbTip.y() < thumbIp.y()) && (thumbIp.y() < thumbMcp.y()) && (thumbTip.y() < indexMcp.y())

        // Thumb vector alignment against vertical or palm
        val thumbVy = thumbTip.y() - thumbMcp.y()
        val isStrongUpward = isPointingUpScreen && (thumbVy < -palmSize * 0.20f)

        val isThumbPointingUp = isThumbExtended && isStrongUpward

        return FingerStates(
            isThumbExtended = isThumbExtended,
            isThumbPointingUp = isThumbPointingUp,
            isIndexExtended = isIndexExtended,
            isMiddleExtended = isMiddleExtended,
            isRingExtended = isRingExtended,
            isPinkyExtended = isPinkyExtended
        )
    }

    private fun isFingerExtended(
        lm: List<NormalizedLandmark>,
        mcpIdx: Int,
        pipIdx: Int,
        dipIdx: Int,
        tipIdx: Int,
        wrist: NormalizedLandmark,
        palmSize: Float,
        palmDx: Float,
        palmDy: Float
    ): Boolean {
        val mcp = lm[mcpIdx]
        val pip = lm[pipIdx]
        val dip = lm[dipIdx]
        val tip = lm[tipIdx]

        val distTipWrist = dist(tip, wrist)
        val distPipWrist = dist(pip, wrist)
        val distDipWrist = dist(dip, wrist)

        // 1. Tip must be farther from wrist than PIP and DIP
        val isFarther = (distTipWrist > distPipWrist * 1.05f) && (distTipWrist > distDipWrist)

        // 2. Projection along finger direction (from MCP to PIP)
        val fingerDx = (tip.x() - mcp.x())
        val fingerDy = (tip.y() - mcp.y())
        val projectionOnPalm = (fingerDx * palmDx) + (fingerDy * palmDy)

        val isExtendedLength = projectionOnPalm > palmSize * 0.35f

        // 3. Tip must not be curled down towards palm
        val distTipMcp = dist(tip, mcp)
        val distPipMcp = dist(pip, mcp)
        val isNotCurled = distTipMcp > distPipMcp * 1.05f

        return isFarther && isExtendedLength && isNotCurled
    }

    private fun dist(a: NormalizedLandmark, b: NormalizedLandmark): Float {
        val dx = a.x() - b.x()
        val dy = a.y() - b.y()
        val dz = (a.z() - b.z()) * 0.5f // downscale z noise
        return sqrt((dx * dx) + (dy * dy) + (dz * dz))
    }
}
