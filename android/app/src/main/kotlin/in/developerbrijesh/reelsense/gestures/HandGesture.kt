package `in`.developerbrijesh.reelsense.gestures

enum class HandGesture(val displayName: String, val action: String?) {
    OPEN_PALM("Open Palm", "PAUSE_PLAY"),
    THUMBS_UP("Thumbs Up", "LIKE_REEL"),
    INDEX_FINGER("Only Index Finger", "NEXT_REEL"),
    INDEX_AND_MIDDLE("Index + Middle", "PREVIOUS_REEL"),
    UNKNOWN("Neutral", null);

    companion object {
        fun fromAction(action: String): HandGesture? {
            return entries.firstOrNull { it.action.equals(action, ignoreCase = true) }
        }
    }
}
