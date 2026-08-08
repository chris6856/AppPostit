package com.apppostit.apppostit.ime

import android.content.Context

/** Insertions beyond this many (a saved post actually typed into another
 *  app via the keyboard -- not how many posts are saved) require the
 *  unlock purchase. Keep in sync with the Flutter side's copy of this
 *  limit (lib/providers/providers.dart's kFreeInsertLimit), since both
 *  enforce the same gate independently. */
const val FREE_INSERT_LIMIT = 8

/**
 * Reads the "is_premium" flag the Flutter app writes via shared_preferences.
 * The IME runs in the same app package/UID as the Flutter app, so it can
 * open the same SharedPreferences file directly through the standard
 * Android API -- shared_preferences' Android implementation always uses
 * "FlutterSharedPreferences" as the file name and prefixes every key with
 * "flutter.".
 */
class PurchaseStatusReader(private val context: Context) {
    fun isPremium(): Boolean {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        return prefs.getBoolean("flutter.is_premium", false)
    }
}
