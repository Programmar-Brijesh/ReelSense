package `in`.developerbrijesh.reelsense.commands

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.util.Locale

class NativeCommandMatcher(private val context: Context) {

    companion object {
        private const val TAG = "NativeCommandMatcher"
        private const val DB_NAME = "reelsense_voice_commands.db"
    }

    data class MatchedCommand(
        val phrase: String,
        val normalizedPhrase: String,
        val action: String
    )

    private var cachedCommands: List<MatchedCommand> = emptyList()

    init {
        reloadCommands()
    }

    fun reloadCommands() {
        val list = mutableListOf<MatchedCommand>()
        try {
            val dbPath = context.getDatabasePath(DB_NAME)
            if (dbPath != null && dbPath.exists()) {
                val db = SQLiteDatabase.openDatabase(dbPath.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                db.rawQuery(
                    "SELECT phrase, normalized_phrase, action FROM voice_commands WHERE is_enabled = 1",
                    null
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        val phrase = cursor.getString(0) ?: ""
                        val normalized = cursor.getString(1) ?: normalize(phrase)
                        val action = cursor.getString(2) ?: ""
                        if (normalized.isNotBlank() && action.isNotBlank()) {
                            list.add(MatchedCommand(phrase, normalized, action))
                        }
                    }
                }
                db.close()
                Log.d(TAG, "Loaded ${list.size} enabled commands from $DB_NAME")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load commands from SQLite: ${e.message}")
        }

        // Fallback default commands if database is empty or not yet generated
        if (list.isEmpty()) {
            list.addAll(
                listOf(
                    MatchedCommand("next", "next", "NEXT_REEL"),
                    MatchedCommand("next reel", "next reel", "NEXT_REEL"),
                    MatchedCommand("scroll down", "scroll down", "NEXT_REEL"),
                    MatchedCommand("previous", "previous", "PREVIOUS_REEL"),
                    MatchedCommand("previous reel", "previous reel", "PREVIOUS_REEL"),
                    MatchedCommand("back", "back", "PREVIOUS_REEL"),
                    MatchedCommand("scroll up", "scroll up", "PREVIOUS_REEL"),
                    MatchedCommand("like", "like", "LIKE_REEL"),
                    MatchedCommand("like reel", "like reel", "LIKE_REEL"),
                    MatchedCommand("heart", "heart", "LIKE_REEL"),
                    MatchedCommand("pause", "pause", "PAUSE_PLAY"),
                    MatchedCommand("play", "play", "PAUSE_PLAY"),
                    MatchedCommand("replay", "replay", "REPLAY_REEL"),
                    MatchedCommand("replay reel", "replay reel", "REPLAY_REEL")
                )
            )
            Log.d(TAG, "Using default command set (${list.size} commands).")
        }

        // Sort by length descending so longer matching phrases take precedence (e.g. 'next reel' before 'next')
        cachedCommands = list.sortedByDescending { it.normalizedPhrase.length }
    }

    fun match(speechText: String): MatchedCommand? {
        val normalized = normalize(speechText)
        if (normalized.isBlank()) return null

        // 1. Exact match
        for (cmd in cachedCommands) {
            if (cmd.normalizedPhrase == normalized) {
                return cmd
            }
        }

        // 2. Word boundary or subphrase match
        val words = normalized.split(" ")
        for (cmd in cachedCommands) {
            val cmdWords = cmd.normalizedPhrase.split(" ")
            if (cmdWords.size == 1) {
                if (words.contains(cmd.normalizedPhrase)) {
                    return cmd
                }
            } else {
                if (normalized.contains(cmd.normalizedPhrase)) {
                    return cmd
                }
            }
        }

        return null
    }

    private fun normalize(text: String): String {
        return text.trim()
            .lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9\\s]"), "")
            .replace(Regex("\\s+"), " ")
    }
}
