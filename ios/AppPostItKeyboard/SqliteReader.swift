import Foundation
import SQLite3

/// Reads the same SQLite file the main Flutter app (drift) writes to, out
/// of the shared App Group container (see AppGroupPlugin.swift /
/// lib/data/database.dart -- the extension can't see the app's own
/// documents directory at all, only the App Group container).
/// Table/column names are kept in sync with lib/data/tables.dart by hand --
/// explicit column lists here so a future Dart schema change fails loudly
/// rather than silently misreading, matching SqliteReader.kt on Android.
private let appGroupId = "group.com.apppostit.apppostit"
private let databaseFileName = "apppostit.sqlite"

struct CategoryRow {
    let id: Int64
    let name: String
    let sortOrder: Int64
}

struct PostRow {
    let id: Int64
    let categoryId: Int64
    let label: String?
    let body: String
    let sortOrder: Int64
}

final class SqliteReader {
    private var dbPath: String? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else { return nil }
        return container.appendingPathComponent(databaseFileName).path
    }

    func getCategories() -> [CategoryRow] {
        return withDb { db in
            var rows: [CategoryRow] = []
            var stmt: OpaquePointer?
            let sql = "SELECT id, name, sort_order FROM categories ORDER BY sort_order"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(
                    CategoryRow(
                        id: sqlite3_column_int64(stmt, 0),
                        name: String(cString: sqlite3_column_text(stmt, 1)),
                        sortOrder: sqlite3_column_int64(stmt, 2)
                    )
                )
            }
            return rows
        } ?? []
    }

    func getPosts(categoryId: Int64) -> [PostRow] {
        return withDb { db in
            var rows: [PostRow] = []
            var stmt: OpaquePointer?
            let sql = """
                SELECT id, category_id, label, body, sort_order FROM posts \
                WHERE category_id = ? ORDER BY sort_order
                """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, categoryId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let label = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                rows.append(
                    PostRow(
                        id: sqlite3_column_int64(stmt, 0),
                        categoryId: sqlite3_column_int64(stmt, 1),
                        label: label,
                        body: String(cString: sqlite3_column_text(stmt, 3)),
                        sortOrder: sqlite3_column_int64(stmt, 4)
                    )
                )
            }
            return rows
        } ?? []
    }

    private func withDb<T>(_ block: (OpaquePointer) -> T) -> T? {
        guard let path = dbPath, FileManager.default.fileExists(atPath: path) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }
        return block(db)
    }
}
