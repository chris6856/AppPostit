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

  static Future<String?> getContainerPath() {
    return _channel.invokeMethod<String>('getContainerPath');
  }
}
