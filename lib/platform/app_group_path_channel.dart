import 'package:flutter/services.dart';

/// Dart side of AppGroupPlugin.swift. On iOS, the main app and the keyboard
/// extension run as genuinely separate processes/sandboxes -- unlike
/// Android where the keyboard shares the app's own private storage -- so
/// they can only share files through an explicit App Group container.
/// [getContainerPath] asks the native side (which has App Group
/// entitlements) for that shared directory's path.
class AppGroupPathChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.apppostit.apppostit/app_group',
  );

  /// TEMPORARY: last container path seen, surfaced by the debug banner in
  /// main.dart -- compare directly against KeyboardViewController's own
  /// logged container path to check for a signing/team mismatch between
  /// the two targets. Remove once confirmed working.
  static String? debugLastPath;

  static Future<String?> getContainerPath() async {
    final path = await _channel.invokeMethod<String>('getContainerPath');
    debugLastPath = path;
    return path;
  }
}
