package `in`.developerbrijesh.reelsense.overlay

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

enum class OverlayState {
    CONNECTING,
    LISTENING,
    SPEECH_DETECTED,
    PROCESSING,
    COMMAND_MATCHED,
    ACTION_EXECUTED,
    NO_MATCH,
    RESTARTING,
    ERROR,
    PAUSED
}

class ReelSenseOverlayManager(
    private val context: Context,
    private val onPauseRequested: () -> Unit,
    private val onResumeRequested: () -> Unit,
    private val onStopRequested: () -> Unit
) {

    companion object {
        private const val TAG = "ReelSenseOverlay"
    }

    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var rootView: FrameLayout? = null
    private var statusTextView: TextView? = null
    private var transcriptTextView: TextView? = null
    private var iconIndicator: ImageView? = null
    private var pauseResumeBtn: TextView? = null
    private var pulseAnimator: ObjectAnimator? = null

    private var isVisible = false
    private var currentState: OverlayState = OverlayState.CONNECTING
    private var currentMode = "voice"
    private var autoResetRunnable: Runnable? = null

    fun show(mode: String = "voice") {
        mainHandler.post {
            if (!Settings.canDrawOverlays(context)) {
                Log.w(TAG, "Cannot show overlay: SYSTEM_ALERT_WINDOW permission missing.")
                return@post
            }

            currentMode = mode

            if (isVisible && rootView != null) {
                Log.d(TAG, "Overlay already created and visible. Refreshing mode to $mode.")
                updateModeUi()
                updateState(OverlayState.LISTENING)
                return@post
            }

            try {
                val view = createOverlayView()
                val params = createLayoutParams()
                windowManager.addView(view, params)
                rootView = view
                isVisible = true
                Log.d(TAG, "Overlay created. Mode: $mode")
                updateState(OverlayState.CONNECTING)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create overlay: ${e.message}")
            }
        }
    }

    fun hide(reason: String = "unspecified") {
        mainHandler.post {
            cancelAutoReset()
            if (!isVisible || rootView == null) {
                Log.d(TAG, "hide called but overlay was not visible (reason=$reason)")
                return@post
            }
            try {
                stopPulseAnimation()
                windowManager.removeView(rootView)
                Log.d(TAG, "Overlay removed: reason=$reason")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to remove overlay ($reason): ${e.message}")
            } finally {
                rootView = null
                isVisible = false
            }
        }
    }

    fun updateState(
        state: OverlayState,
        heardText: String? = null,
        matchedCommand: String? = null,
        actionName: String? = null,
        errorMessage: String? = null
    ) {
        mainHandler.post {
            if (!isVisible || rootView == null) return@post
            currentState = state
            Log.d(TAG, "Overlay updated: state=$state, heard='$heardText', matched='$matchedCommand', action='$actionName', error='$errorMessage'")

            cancelAutoReset()

            when (state) {
                OverlayState.CONNECTING -> {
                    statusTextView?.text = "Connecting..."
                    statusTextView?.setTextColor(Color.parseColor("#FFFFFF"))
                    transcriptTextView?.text = "Initializing speech engine..."
                    transcriptTextView?.setTextColor(Color.parseColor("#A5A5B5"))
                    startPulseAnimation()
                }

                OverlayState.LISTENING -> {
                    statusTextView?.text = if (currentMode == "voice") "Listening..." else "Tracking gestures..."
                    statusTextView?.setTextColor(Color.parseColor("#FFFFFF"))
                    transcriptTextView?.text = if (currentMode == "voice") {
                        "Say 'next', 'previous', 'like', 'pause'..."
                    } else {
                        "Ready for hand gesture commands..."
                    }
                    transcriptTextView?.setTextColor(Color.parseColor("#A5A5B5"))
                    pauseResumeBtn?.text = "⏸ Pause"
                    pauseResumeBtn?.setTextColor(Color.parseColor("#A5A5B5"))
                    startPulseAnimation()
                }

                OverlayState.SPEECH_DETECTED -> {
                    statusTextView?.text = "Hearing speech..."
                    statusTextView?.setTextColor(Color.parseColor("#35D6E8"))
                    if (!heardText.isNullOrBlank()) {
                        transcriptTextView?.text = "Heard: \"$heardText\""
                        transcriptTextView?.setTextColor(Color.parseColor("#FFFFFF"))
                    }
                    startPulseAnimation()
                }

                OverlayState.PROCESSING -> {
                    statusTextView?.text = "Processing..."
                    statusTextView?.setTextColor(Color.parseColor("#35D6E8"))
                    if (!heardText.isNullOrBlank()) {
                        transcriptTextView?.text = "Heard: \"$heardText\""
                        transcriptTextView?.setTextColor(Color.parseColor("#FFFFFF"))
                    }
                    stopPulseAnimation()
                }

                OverlayState.COMMAND_MATCHED -> {
                    val cmd = matchedCommand ?: "Command"
                    statusTextView?.text = "Matched: $cmd"
                    statusTextView?.setTextColor(Color.parseColor("#35D6E8"))
                    if (!heardText.isNullOrBlank()) {
                        transcriptTextView?.text = "Heard: \"$heardText\""
                        transcriptTextView?.setTextColor(Color.parseColor("#E0F7FA"))
                    }
                    stopPulseAnimation()
                    scheduleAutoResetToListening(1600)
                }

                OverlayState.ACTION_EXECUTED -> {
                    val actionLabel = actionName?.let { formatActionName(it) } ?: "Action"
                    statusTextView?.text = "Action: $actionLabel executed ✓"
                    statusTextView?.setTextColor(Color.parseColor("#35D6E8"))
                    if (!matchedCommand.isNullOrBlank()) {
                        transcriptTextView?.text = "Matched: $matchedCommand"
                    } else if (!heardText.isNullOrBlank()) {
                        transcriptTextView?.text = "Heard: \"$heardText\""
                    }
                    transcriptTextView?.setTextColor(Color.parseColor("#E0F7FA"))
                    stopPulseAnimation()
                    scheduleAutoResetToListening(1600)
                }

                OverlayState.NO_MATCH -> {
                    statusTextView?.text = "No matching command"
                    statusTextView?.setTextColor(Color.parseColor("#FFA726"))
                    if (!heardText.isNullOrBlank()) {
                        transcriptTextView?.text = "Heard: \"$heardText\""
                    } else {
                        transcriptTextView?.text = "Try 'next', 'previous', 'like', 'pause'"
                    }
                    transcriptTextView?.setTextColor(Color.parseColor("#FFCC80"))
                    stopPulseAnimation()
                    scheduleAutoResetToListening(1800)
                }

                OverlayState.RESTARTING -> {
                    statusTextView?.text = "Restarting..."
                    statusTextView?.setTextColor(Color.parseColor("#A5A5B5"))
                    transcriptTextView?.text = "Preparing speech recognizer..."
                    transcriptTextView?.setTextColor(Color.parseColor("#78788C"))
                    stopPulseAnimation()
                }

                OverlayState.ERROR -> {
                    val msg = errorMessage ?: "Recognition temporary pause"
                    statusTextView?.text = "Status: $msg"
                    statusTextView?.setTextColor(Color.parseColor("#FF5252"))
                    transcriptTextView?.text = "Retrying automatically..."
                    transcriptTextView?.setTextColor(Color.parseColor("#FFA5A5"))
                    stopPulseAnimation()
                    scheduleAutoResetToListening(2000)
                }

                OverlayState.PAUSED -> {
                    stopPulseAnimation()
                    statusTextView?.text = "Controller Paused"
                    statusTextView?.setTextColor(Color.parseColor("#FFA726"))
                    transcriptTextView?.text = "Tap Resume to continue hands-free control"
                    transcriptTextView?.setTextColor(Color.parseColor("#A5A5B5"))
                    pauseResumeBtn?.text = "▶ Resume"
                    pauseResumeBtn?.setTextColor(Color.parseColor("#35D6E8"))
                }
            }
        }
    }

    // Helper wrappers
    fun updateListeningStatus(isListening: Boolean, statusText: String? = null) {
        if (currentState == OverlayState.PAUSED) return
        if (isListening) {
            updateState(OverlayState.LISTENING)
        } else if (statusText != null) {
            mainHandler.post {
                if (!isVisible) return@post
                statusTextView?.text = statusText
            }
        }
    }

    fun updateTranscript(speechText: String, isPartial: Boolean = false) {
        if (currentState == OverlayState.PAUSED) return
        if (isPartial) {
            updateState(OverlayState.SPEECH_DETECTED, heardText = speechText)
        } else {
            updateState(OverlayState.PROCESSING, heardText = speechText)
        }
    }

    fun showActionResult(phrase: String, action: String) {
        if (currentState == OverlayState.PAUSED) return
        updateState(
            state = OverlayState.ACTION_EXECUTED,
            heardText = phrase,
            matchedCommand = phrase,
            actionName = action
        )
    }

    fun showNoMatch(heardText: String) {
        if (currentState == OverlayState.PAUSED) return
        updateState(
            state = OverlayState.NO_MATCH,
            heardText = heardText
        )
    }

    fun showError(errorMessage: String) {
        if (currentState == OverlayState.PAUSED) return
        updateState(
            state = OverlayState.ERROR,
            errorMessage = errorMessage
        )
    }

    fun setPaused(paused: Boolean) {
        if (paused) {
            updateState(OverlayState.PAUSED)
        } else {
            updateState(OverlayState.LISTENING)
        }
    }

    private fun scheduleAutoResetToListening(delayMs: Long) {
        cancelAutoReset()
        autoResetRunnable = Runnable {
            if (isVisible && currentState != OverlayState.PAUSED) {
                updateState(OverlayState.LISTENING)
            }
        }
        mainHandler.postDelayed(autoResetRunnable!!, delayMs)
    }

    private fun cancelAutoReset() {
        autoResetRunnable?.let { mainHandler.removeCallbacks(it) }
        autoResetRunnable = null
    }

    @SuppressLint("SetTextI18n")
    private fun createOverlayView(): FrameLayout {
        val root = FrameLayout(context).apply {
            clipChildren = false
            clipToPadding = false
        }

        // Card Container: Horizontal Layout
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))

            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#F00E0F18")) // 94% OLED dark card
                cornerRadius = dp(16).toFloat()
                val borderColor = if (currentMode == "voice") "#4035D6E8" else "#407657F5"
                setStroke(dp(1), Color.parseColor(borderColor))
            }
            background = bg
            elevation = dp(8).toFloat()
        }

        // Left Icon (Microphone or Gesture)
        val iconView = ImageView(context).apply {
            val iconRes = if (currentMode == "voice") {
                android.R.drawable.ic_btn_speak_now
            } else {
                android.R.drawable.ic_menu_camera
            }
            setImageResource(iconRes)
            val iconTint = if (currentMode == "voice") "#35D6E8" else "#7657F5"
            setColorFilter(Color.parseColor(iconTint))
            layoutParams = LinearLayout.LayoutParams(dp(28), dp(28)).apply {
                marginEnd = dp(10)
            }
        }
        iconIndicator = iconView
        card.addView(iconView)

        // Middle Text Info (State + Transcript / Heard / Result)
        val textContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        }

        val statusView = TextView(context).apply {
            text = if (currentMode == "voice") "Listening..." else "Gesture Mode Active"
            textSize = 12.5f
            setTextColor(Color.parseColor("#FFFFFF"))
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        statusTextView = statusView
        textContainer.addView(statusView)

        val transcriptView = TextView(context).apply {
            text = if (currentMode == "voice") {
                "Say 'next', 'previous', 'like', 'pause'..."
            } else {
                "Swipe hand up / down to scroll"
            }
            textSize = 11f
            setTextColor(Color.parseColor("#A5A5B5"))
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, dp(1), 0, 0)
        }
        transcriptTextView = transcriptView
        textContainer.addView(transcriptView)

        card.addView(textContainer)

        // Right Action Buttons
        val actionsContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = dp(8)
            }
        }

        // Pause / Resume Toggle
        val pauseBtn = TextView(context).apply {
            text = "⏸ Pause"
            textSize = 11f
            setTextColor(Color.parseColor("#A5A5B5"))
            setPadding(dp(8), dp(4), dp(8), dp(4))
            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#20FFFFFF"))
                cornerRadius = dp(8).toFloat()
            }
            background = btnBg
            setOnClickListener {
                if (currentState == OverlayState.PAUSED) {
                    onResumeRequested()
                } else {
                    onPauseRequested()
                }
            }
        }
        pauseResumeBtn = pauseBtn
        actionsContainer.addView(pauseBtn)

        // Stop Button ('✕')
        val stopBtn = TextView(context).apply {
            text = "✕"
            textSize = 14f
            setTextColor(Color.parseColor("#FF5252"))
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(dp(10), dp(4), dp(10), dp(4))
            val stopBg = GradientDrawable().apply {
                setColor(Color.parseColor("#30FF5252"))
                cornerRadius = dp(8).toFloat()
            }
            background = stopBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = dp(6)
            }
            setOnClickListener {
                onStopRequested()
            }
        }
        actionsContainer.addView(stopBtn)

        card.addView(actionsContainer)

        // Wrap card in root
        val cardParams = FrameLayout.LayoutParams(
            dp(310),
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }
        root.addView(card, cardParams)

        return root
    }

    private fun createLayoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(85) // Positioned safely above Instagram bottom nav
        }
    }

    private fun updateModeUi() {
        val iconRes = if (currentMode == "voice") {
            android.R.drawable.ic_btn_speak_now
        } else {
            android.R.drawable.ic_menu_camera
        }
        iconIndicator?.setImageResource(iconRes)
        val iconTint = if (currentMode == "voice") "#35D6E8" else "#7657F5"
        iconIndicator?.setColorFilter(Color.parseColor(iconTint))
    }

    private fun startPulseAnimation() {
        stopPulseAnimation()
        iconIndicator?.let { icon ->
            pulseAnimator = ObjectAnimator.ofFloat(icon, "alpha", 1.0f, 0.35f, 1.0f).apply {
                duration = 1100
                repeatCount = ValueAnimator.INFINITE
                start()
            }
        }
    }

    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        iconIndicator?.alpha = 1.0f
    }

    private fun formatActionName(action: String): String {
        return when (action.uppercase()) {
            "NEXT_REEL" -> "Next Reel"
            "PREVIOUS_REEL" -> "Previous Reel"
            "LIKE_REEL" -> "Like Reel"
            "PAUSE_PLAY" -> "Pause / Play"
            "REPLAY_REEL" -> "Replay Reel"
            else -> action.replace("_", " ").lowercase().replaceFirstChar { it.uppercase() }
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics
        ).toInt()
    }
}
