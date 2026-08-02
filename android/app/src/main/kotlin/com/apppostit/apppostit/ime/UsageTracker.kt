package com.apppostit.apppostit.ime

import android.content.Context

private const val INSERT_COUNT_KEY = "flutter.insert_count"

/**
 * Tracks how many times a saved post has actually been inserted into
 * another app via the keyboard -- this is what counts against the free
 * tier, not how many posts are saved. Stored in the same
 * SharedPreferences file the Flutter app reads, under the "flutter."
 * prefix its shared_preferences plugin expects when it later reads this
 * key back via SharedPreferencesAsync.
 */
class UsageTracker(context: Context) {
    private val prefs =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun getInsertCount(): Int = prefs.getInt(INSERT_COUNT_KEY, 0)

    fun recordInsert() {
        prefs.edit().putInt(INSERT_COUNT_KEY, getInsertCount() + 1).apply()
    }
}
