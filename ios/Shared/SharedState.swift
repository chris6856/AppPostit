import Foundation

private let appGroupId = "group.com.apppostit.apppostit"
private let sharedStateFileName = "shared_state.json"

/// Cross-process key/value storage for the main app and the keyboard
/// extension, backed by a plain JSON file in the shared App Group
/// container rather than UserDefaults(suiteName:).
///
/// UserDefaults turned out to be unreliable here even after several
/// targeted fixes (synchronize() after every write, recreating the
/// instance on every access instead of reusing one) -- a value the
/// keyboard extension had just written was still sometimes invisible to
/// the main app moments later. Direct file I/O has none of UserDefaults'
/// internal caching/propagation behavior, and it's the same mechanism the
/// SQLite database already uses reliably across this exact process
/// boundary (see SqliteReader.swift / database.dart), so it's a known
/// quantity rather than another guess.
///
/// Included in both the Runner and AppPostItKeyboard targets (see
/// ios/scripts/add_keyboard_extension.rb) -- small enough that
/// duplicating the compiled file into both targets is simpler than
/// factoring out a shared framework for it.
enum SharedState {
    /// TEMPORARY: last read/write outcome, surfaced by both the main
    /// app's and the keyboard's debug labels. try? was silently
    /// swallowing any I/O error, making a real failure indistinguishable
    /// from "key not set yet". Kept as two separate fields -- a shared
    /// single field previously let a read (e.g. the debug label's own
    /// lookup, which runs right after a write when refreshing) silently
    /// clobber the write's result before it could ever be seen. Remove
    /// all of this once confirmed working.
    static var debugLastRead = "no read yet"
    static var debugLastWrite = "no write yet"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(sharedStateFileName)
    }

    private static func read() -> [String: Any] {
        guard let url = fileURL else {
            debugLastRead = "read: containerURL is NIL"
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                debugLastRead = "read: parsed but not a dict"
                return [:]
            }
            debugLastRead = "read ok: \(json)"
            return json
        } catch {
            debugLastRead = "read THREW: \(error) at \(url.path)"
            return [:]
        }
    }

    private static func write(_ dict: [String: Any]) {
        guard let url = fileURL else {
            debugLastWrite = "write: containerURL is NIL"
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            try data.write(to: url, options: .atomic)
            debugLastWrite = "write ok: \(dict) to \(url.path)"
        } catch {
            debugLastWrite = "write THREW: \(error) at \(url.path)"
        }
    }

    static func getInt(_ key: String) -> Int? {
        read()[key] as? Int
    }

    static func getBool(_ key: String) -> Bool? {
        read()[key] as? Bool
    }

    static func setInt(_ key: String, _ value: Int) {
        var dict = read()
        dict[key] = value
        write(dict)
    }

    static func setBool(_ key: String, _ value: Bool) {
        var dict = read()
        dict[key] = value
        write(dict)
    }
}
