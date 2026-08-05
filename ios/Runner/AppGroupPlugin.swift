import Flutter
import Foundation

/// Bundle ID prefix shared by the main app and the keyboard extension --
/// keep in sync with the App Group ID configured in both targets'
/// entitlements (see ios/scripts/add_keyboard_extension.rb and the Runner
/// entitlements file).
private let appGroupId = "group.com.apppostit.apppostit"

/// Backs two channels the Dart side calls into:
///   - "com.apppostit.apppostit/app_group": getContainerPath, so drift can
///     open the sqlite file inside the shared App Group container instead
///     of this app's own (extension-invisible) documents directory.
///   - "com.apppostit.apppostit/shared_storage": getBool/setBool/getInt,
///     reading and writing UserDefaults(suiteName: appGroupId) directly --
///     the same suite KeyboardViewController.swift's UsageTracker and
///     PurchaseStatusReader equivalents read/write, since the
///     shared_preferences plugin has no supported way to target an
///     App-Group-scoped UserDefaults suite on iOS.
final class AppGroupPlugin: NSObject {
    // Computed, not stored, so a fresh UserDefaults instance backs every
    // access rather than one held for the plugin's whole lifetime -- cheap
    // insurance against stale in-memory state, though it turned out the
    // real bug was on the write side: see UsageTracker.recordInsert()'s
    // comment for why the keyboard extension specifically needs an
    // explicit synchronize() after writing.
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    // Takes a FlutterBinaryMessenger directly (pass
    // engineBridge.applicationRegistrar.messenger() from
    // AppDelegate.didInitializeImplicitFlutterEngine) rather than going
    // through FlutterPluginRegistry.registrar(forPlugin:).messenger() --
    // with this project's FlutterImplicitEngineDelegate-based setup, a
    // per-plugin registrar's messenger didn't connect to the same channel
    // the Dart-side MethodChannel binds to, silently breaking every call
    // with MissingPluginException despite registration appearing to
    // succeed.
    static func register(with messenger: FlutterBinaryMessenger) {
        let instance = AppGroupPlugin()

        let pathChannel = FlutterMethodChannel(
            name: "com.apppostit.apppostit/app_group",
            binaryMessenger: messenger
        )
        pathChannel.setMethodCallHandler(instance.handle)

        let storageChannel = FlutterMethodChannel(
            name: "com.apppostit.apppostit/shared_storage",
            binaryMessenger: messenger
        )
        storageChannel.setMethodCallHandler(instance.handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getContainerPath":
            let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
            )
            result(url?.path)

        case "getBool":
            guard let key = (call.arguments as? [String: Any])?["key"] as? String else {
                result(FlutterError(code: "bad_args", message: "missing key", details: nil))
                return
            }
            if defaults?.object(forKey: key) == nil {
                result(nil)
            } else {
                result(defaults?.bool(forKey: key) ?? false)
            }

        case "setBool":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String,
                  let value = args["value"] as? Bool else {
                result(FlutterError(code: "bad_args", message: "missing key/value", details: nil))
                return
            }
            defaults?.set(value, forKey: key)
            result(nil)

        case "getInt":
            guard let key = (call.arguments as? [String: Any])?["key"] as? String else {
                result(FlutterError(code: "bad_args", message: "missing key", details: nil))
                return
            }
            if defaults?.object(forKey: key) == nil {
                result(nil)
            } else {
                result(defaults?.integer(forKey: key) ?? 0)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
