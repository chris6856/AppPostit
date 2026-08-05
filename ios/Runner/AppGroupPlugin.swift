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
///     backed by SharedState.swift (a plain JSON file in the App Group
///     container) rather than UserDefaults -- see that file's comment for
///     why.
final class AppGroupPlugin: NSObject {
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
            result(SharedState.getBool(key))

        case "setBool":
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String,
                  let value = args["value"] as? Bool else {
                result(FlutterError(code: "bad_args", message: "missing key/value", details: nil))
                return
            }
            SharedState.setBool(key, value)
            result(nil)

        case "getInt":
            guard let key = (call.arguments as? [String: Any])?["key"] as? String else {
                result(FlutterError(code: "bad_args", message: "missing key", details: nil))
                return
            }
            result(SharedState.getInt(key))

        // TEMPORARY: surfaces SharedState's last read/write outcome
        // (including any I/O error) in the app's debug banner.
        case "debugLastAction":
            result(SharedState.debugLastAction)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
