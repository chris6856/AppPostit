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
/// Writing to the App Group container from the keyboard extension
/// requires "Allow Full Access" to be granted (RequestsOpenAccess in
/// AppPostItKeyboard/Info.plist) -- reads work without it, but a write
/// without it throws a permission error. KeyboardViewController checks
/// hasFullAccess before relying on any of this.
///
/// Included in both the Runner and AppPostItKeyboard targets (see
/// ios/scripts/add_keyboard_extension.rb) -- small enough that
/// duplicating the compiled file into both targets is simpler than
/// factoring out a shared framework for it.
enum SharedState {
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(sharedStateFileName)
    }

    private static func read() -> [String: Any] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return json
    }

    private static func write(_ dict: [String: Any]) {
        guard let url = fileURL,
              let data = try? JSONSerialization.data(withJSONObject: dict)
        else { return }
        try? data.write(to: url, options: .atomic)
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
