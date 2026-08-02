package com.apppostit.apppostit.ime

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

private const val TAG = "AppPostItIME"

/**
 * Reads the same SQLite file the main Flutter app (drift) writes to.
 * Table/column names are kept in sync with lib/data/tables.dart by hand --
 * explicit column lists here so a future Dart schema change fails loudly
 * rather than silently misreading.
 */
private const val DATABASE_FILE_NAME = "apppostit.sqlite"

data class CategoryRow(val id: Long, val name: String, val sortOrder: Long)

data class PostRow(
    val id: Long,
    val categoryId: Long,
    val label: String?,
    val body: String,
    val sortOrder: Long,
)

class SqliteReader(private val context: Context) {
    // path_provider's getApplicationDocumentsDirectory() resolves to
    // <app data dir>/app_flutter on Android -- a sibling of filesDir, not
    // nested inside it -- confirmed by inspecting the installed app's
    // private storage on device via `adb shell run-as ... ls`.
    private val dbFile: File =
        File(File(context.filesDir.parentFile, "app_flutter"), DATABASE_FILE_NAME)

    fun getCategories(): List<CategoryRow> {
        return withDb { db ->
            db.rawQuery(
                "SELECT id, name, sort_order FROM categories ORDER BY sort_order",
                null,
            ).use { cursor ->
                val result = mutableListOf<CategoryRow>()
                while (cursor.moveToNext()) {
                    result.add(
                        CategoryRow(
                            id = cursor.getLong(0),
                            name = cursor.getString(1),
                            sortOrder = cursor.getLong(2),
                        )
                    )
                }
                result
            }
        } ?: emptyList()
    }

    fun getPosts(categoryId: Long): List<PostRow> {
        return withDb { db ->
            db.rawQuery(
                "SELECT id, category_id, label, body, sort_order FROM posts " +
                    "WHERE category_id = ? ORDER BY sort_order",
                arrayOf(categoryId.toString()),
            ).use { cursor ->
                val result = mutableListOf<PostRow>()
                while (cursor.moveToNext()) {
                    result.add(
                        PostRow(
                            id = cursor.getLong(0),
                            categoryId = cursor.getLong(1),
                            label = if (cursor.isNull(2)) null else cursor.getString(2),
                            body = cursor.getString(3),
                            sortOrder = cursor.getLong(4),
                        )
                    )
                }
                result
            }
        } ?: emptyList()
    }

    private fun <T> withDb(block: (SQLiteDatabase) -> T): T? {
        if (!dbFile.exists()) return null
        val db = try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
        } catch (e: Exception) {
            Log.e(TAG, "failed to open db", e)
            return null
        }
        return try {
            block(db)
        } catch (e: Exception) {
            Log.e(TAG, "query failed", e)
            null
        } finally {
            db.close()
        }
    }
}
