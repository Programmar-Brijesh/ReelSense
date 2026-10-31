package `in`.developerbrijesh.reelsense.gestures

import android.os.SystemClock
import android.util.Log

data class GestureCandidate(
    val key: String,
    val displayName: String,
    val action: String?
)

class GestureStateMachine(
    private var requiredConsecutiveFrames: Int = 4,
    private var actionCooldownMs: Long = 1200L,
    private var requiredNeutralFrames: Int = 3,
    private val onActionTriggered: (gestureDisplayName: String, action: String) -> Unit
) {

    companion object {
        private const val TAG = "ReelSenseGestureState"
    }

    private var candidate: GestureCandidate? = null
    private var candidateStreak: Int = 0

    private var neutralStreak: Int = 0
    private var isAwaitingNeutralReset: Boolean = false
    private var lastActionTimestamp: Long = 0L

    var onGestureStateChanged: ((gestureDisplayName: String?, isHandPresent: Boolean, action: String?) -> Unit)? = null

    @Synchronized
    fun processFrame(detectedGesture: HandGesture, isHandPresent: Boolean) {
        if (!isHandPresent || detectedGesture == HandGesture.UNKNOWN) {
            processCandidate(null, isHandPresent)
        } else {
            val cand = GestureCandidate(
                key = detectedGesture.name,
                displayName = detectedGesture.displayName,
                action = detectedGesture.action
            )
            processCandidate(cand, true)
        }
    }

    @Synchronized
    fun processCustomFrame(template: CustomGestureTemplate, isHandPresent: Boolean) {
        val cand = GestureCandidate(
            key = "custom_${template.id}",
            displayName = template.name,
            action = template.action
        )
        processCandidate(cand, isHandPresent)
    }

    @Synchronized
    fun processCandidate(detectedCandidate: GestureCandidate?, isHandPresent: Boolean) {
        val now = SystemClock.uptimeMillis()

        onGestureStateChanged?.invoke(
            detectedCandidate?.displayName,
            isHandPresent,
            detectedCandidate?.action
        )

        // 1. If no hand is in frame or no valid candidate, increment neutral streak
        if (!isHandPresent || detectedCandidate == null) {
            neutralStreak++
            candidate = null
            candidateStreak = 0

            // If we were awaiting neutral reset after an action, verify neutral condition satisfied
            if (isAwaitingNeutralReset && neutralStreak >= requiredNeutralFrames) {
                isAwaitingNeutralReset = false
                Log.i(TAG, "Neutral reset satisfied ($neutralStreak frames). Ready for next gesture.")
            }
            return
        }

        // 2. Hand with a recognized candidate gesture is present
        neutralStreak = 0

        // If currently in cooldown or waiting for neutral reset, ignore ongoing gesture
        if (isAwaitingNeutralReset) {
            return
        }

        if (now - lastActionTimestamp < actionCooldownMs) {
            return
        }

        // 3. Track consecutive frame stability
        if (detectedCandidate.key == candidate?.key) {
            candidateStreak++
        } else {
            candidate = detectedCandidate
            candidateStreak = 1
        }

        // 4. Once stability threshold is reached, trigger action once
        if (candidateStreak >= requiredConsecutiveFrames && candidate != null) {
            val targetCandidate = candidate!!
            val action = targetCandidate.action
            if (!action.isNullOrBlank()) {
                Log.i(TAG, "Gesture confirmed: ${targetCandidate.displayName} -> Action: $action")
                lastActionTimestamp = now
                isAwaitingNeutralReset = true // Must see neutral before another action can ever fire
                val confirmedDisplayName = targetCandidate.displayName
                candidateStreak = 0
                candidate = null

                onActionTriggered(confirmedDisplayName, action)
            }
        }
    }

    @Synchronized
    fun reset() {
        candidate = null
        candidateStreak = 0
        neutralStreak = 0
        isAwaitingNeutralReset = false
        lastActionTimestamp = 0L
    }
}
